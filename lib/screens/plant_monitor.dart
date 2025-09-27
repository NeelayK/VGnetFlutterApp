import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

import '../theme.dart';

class PlantMonitorScreen extends StatefulWidget {
  const PlantMonitorScreen({super.key});

  @override
  State<PlantMonitorScreen> createState() => _PlantMonitorScreenState();
}

class _PlantMonitorScreenState extends State<PlantMonitorScreen> {
  final supabase = Supabase.instance.client;

  String? orchestratorIp;
  bool isFetchingIp = false;

  Map<String, dynamic> plantData = {};
  bool useSupabase = false;

  static const int defaultMin = 40;
  static const int defaultMax = 70;

  final Map<String, Map<String, dynamic>> plantConfigs = {
    "A": {"optimalMin": 35, "optimalMax": 60},
    "B": {"optimalMin": 50, "optimalMax": 80},
    "C": {"optimalMin": 40, "optimalMax": 65},
  };

Timer? refreshTimer;
Timer? heartbeatTimer;
bool isSubscribed = false;



  @override
  void initState() {
    super.initState();
    _initMonitor();
  }
  



Future<void> _initMonitor() async {
  await _loadOrchestratorIp();
  if (orchestratorIp == null) return;

  await _fetchData();
  await _subscribeToUpdates();
  _startHeartbeat();
}

void _startHeartbeat() {
  heartbeatTimer?.cancel();
  heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
    if (orchestratorIp == null) return;

    final heartbeatUrl = "http://$orchestratorIp:8001/heartbeat/plant-monitor";
    try {
      await http.get(Uri.parse(heartbeatUrl)).timeout(const Duration(seconds: 5));
          } catch (e) {
      debugPrint("Heartbeat failed: $e");
    }
  });
}


Future<void> _subscribeToUpdates() async {
  if (orchestratorIp == null) return;

  final url = "http://$orchestratorIp:8001/subscribe/plant-monitor";
  try {
    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 2));
    if (response.statusCode == 200) {
      isSubscribed = true;
    } else {
      throw Exception("Subscription failed: ${response.statusCode}");
    }
  } catch (e) {
    isSubscribed = false;
    setState(() => useSupabase = true);
    await _fetchPlantDataFromSupabase();
  }
}



@override
void dispose() {
  refreshTimer?.cancel();
  heartbeatTimer?.cancel();
  super.dispose();
}









  Future<void> _loadOrchestratorIp() async {
    if (isFetchingIp) return;
    setState(() => isFetchingIp = true);

    try {
      final row = await supabase
          .from('ip_config')
          .select('ip')
          .eq('id', 'orchestrator')
          .maybeSingle();

      if (row != null && row['ip'] != null && (row['ip'] as String).isNotEmpty) {
        orchestratorIp = row['ip'] as String;
        debugPrint("✅ Orchestrator IP loaded: $orchestratorIp");
      } else {
        orchestratorIp = null;
        debugPrint("⚠️ No orchestrator IP found in Supabase");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('⚠️ Orchestrator IP not found in Supabase')),
          );
        }
      }
    } catch (e) {
      debugPrint("❌ Failed to fetch orchestrator IP: $e");
      orchestratorIp = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error fetching orchestrator IP: $e')),
        );
      }
    }

    setState(() => isFetchingIp = false);
  }







Future<void> _fetchData() async {
  if (orchestratorIp == null || orchestratorIp!.isEmpty) {
    debugPrint("⚠️ No orchestrator IP available, skipping fetch");
    return;
  }

  final plantMonitorUrl = "http://$orchestratorIp:8001/plant-monitor";

  try {
    await _fetchPlantMonitorData(plantMonitorUrl);
    setState(() => useSupabase = false);
  } catch (e) {
    debugPrint("⚠️ Orchestrator unreachable, switching to Supabase: $e");
    setState(() => useSupabase = true);
    await _fetchPlantDataFromSupabase();
  }
}

Future<void> _fetchPlantMonitorData(String url) async {
  try {
    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 3));

    if (response.statusCode == 200) {
      List<dynamic> decoded = jsonDecode(response.body);
      _updatePlantData(decoded);
    } else {
      throw Exception("Failed to fetch plant data: ${response.statusCode}");
    }
  } on TimeoutException {
    throw Exception("Request to orchestrator timed out after 3s");
  }
}



  Future<void> _fetchPlantDataFromSupabase() async {
    final monitorResponse = await supabase
        .from('plant_monitor')
        .select('moisture, created_at, plant_id')
        .order('created_at', ascending: false);

    final plantInfoResponse = await supabase.from('plant_info').select();

    Map<String, Map<String, dynamic>> plantInfo = {};
    for (var row in plantInfoResponse) {
      plantInfo[row['name']] = {
        'optimalMin': row['optimal_min'],
        'optimalMax': row['optimal_max'],
      };
    }

    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var row in monitorResponse) {
      String plantName = row['plant_id'] ?? 'Unknown';
      grouped.putIfAbsent(plantName, () => []);
      grouped[plantName]!.add(row);
    }

    Map<String, dynamic> computedData = {};
    DateTime now = DateTime.now();

    for (var entry in grouped.entries) {
      List<Map<String, dynamic>> readings = entry.value;
      computedData[entry.key] = {
        "current": (readings.first['moisture'] as num).toInt(),
        "1h": _averageWithin(readings, now.subtract(const Duration(hours: 1))),
        "3h": _averageWithin(readings, now.subtract(const Duration(hours: 3))),
        "6h": _averageWithin(readings, now.subtract(const Duration(hours: 6))),
        "12h": _averageWithin(readings, now.subtract(const Duration(hours: 12))),
        "24h": _averageWithin(readings, now.subtract(const Duration(hours: 24))),
        "optimalMin": (plantInfo[entry.key]?['optimalMin'] ?? defaultMin) as int,
        "optimalMax": (plantInfo[entry.key]?['optimalMax'] ?? defaultMax) as int,
      };
    }

    setState(() {
      plantData = computedData;
    });
  }

  int _averageWithin(List<Map<String, dynamic>> readings, DateTime cutoff) {
    final filtered = readings
        .where((r) => DateTime.parse(r['created_at']).isAfter(cutoff))
        .map((r) => (r['moisture'] as num).toInt())
        .toList();

    if (filtered.isEmpty) return 0;
    return filtered.reduce((a, b) => a + b) ~/ filtered.length;
  }





  void _updatePlantData(List<dynamic> latestData) {
    Map<String, dynamic> computedData = {};
    for (var row in latestData) {
      String plantId = row['plant_id'] ?? "Unknown";
      computedData[plantId] = {
        "current": (row['moisture'] as num).toInt(),
        "1h": (row['moisture'] as num).toInt(),
        "3h": (row['moisture'] as num).toInt(),
        "6h": (row['moisture'] as num).toInt(),
        "12h": (row['moisture'] as num).toInt(),
        "24h": (row['moisture'] as num).toInt(),
        "optimalMin": (plantConfigs[plantId]?['optimalMin'] ?? defaultMin) as int,
        "optimalMax": (plantConfigs[plantId]?['optimalMax'] ?? defaultMax) as int,
      };
    }
    setState(() {
      plantData = computedData;
    });
  }

  





  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: orchestratorIp == null
          ? const Center(child: Text("⚠️ No Orchestrator IP found"))
          : plantData.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: plantData.entries.map((entry) {
                    String plant = entry.key;
                    var data = entry.value;

                    int optimalMin = data['optimalMin'];
                    int optimalMax = data['optimalMax'];

                    return Card(
                      color: AppColors.fill,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              plant,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),

                            // Moisture Gauge
                            SizedBox(
                              height: 180,
                              child: SfRadialGauge(
                                axes: <RadialAxis>[
                                  RadialAxis(
                                    minimum: 0,
                                    maximum: 100,
                                    pointers: <GaugePointer>[
                                      NeedlePointer(
                                        value: (data['current'] ?? 0).toDouble(),
                                        enableAnimation: true,
                                      ),
                                    ],
                                    ranges: <GaugeRange>[
                                      GaugeRange(startValue: 0, endValue: optimalMin.toDouble(), color: AppColors.fill),
                                      GaugeRange(startValue: optimalMin.toDouble(), endValue: optimalMax.toDouble(), color: AppColors.primary),
                                      GaugeRange(startValue: optimalMax.toDouble(), endValue: 100, color: AppColors.fill),
                                    ],
                                    annotations: <GaugeAnnotation>[
                                      GaugeAnnotation(
                                        widget: Text(
                                          "${data['current'] ?? 0}%",
                                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                        ),
                                        positionFactor: 0.8,
                                        angle: 90,
                                      )
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 10),

                            // Time Interval Moisture Levels
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _timeBox("1h", data['1h']),
                                _timeBox("3h", data['3h']),
                                _timeBox("6h", data['6h']),
                                _timeBox("12h", data['12h']),
                                _timeBox("24h", data['24h']),
                              ],
                            ),

                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
    );
  }

  Widget _timeBox(String label, int value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text("$value%"),
      ],
    );
  }
}
