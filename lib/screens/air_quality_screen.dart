import 'dart:async';
import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme.dart';

class AirQualityScreen extends StatefulWidget {
  const AirQualityScreen({super.key});

  @override
  State<AirQualityScreen> createState() => _AirQualityScreenState();
}

class _AirQualityScreenState extends State<AirQualityScreen> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> airQualityData = [];
  bool isLoading = true;
  String? orchestratorIp;
  bool useSupabase = false;

  Timer? heartbeatTimer;
  bool isSubscribed = false;

  @override
  void initState() {
    super.initState();
    _initMonitor();
  }

  @override
  void dispose() {
    _stopHeartbeat();
    _unsubscribeFromOrchestrator();
    super.dispose();
  }

  /// ✅ Initialize orchestrator connection and subscribe for live updates
  Future<void> _initMonitor() async {
    orchestratorIp = await _getOrchestratorIp();

    if (orchestratorIp == null || orchestratorIp!.isEmpty) {
      debugPrint("⚠️ No orchestrator IP found in Supabase.");
      setState(() => isLoading = false);
      return;
    }

    await _fetchAirQualityData();
    await _subscribeToUpdates();
    _startHeartbeat();
  }

  /// ✅ Fetch orchestrator IP from Supabase
  Future<String?> _getOrchestratorIp() async {
    if (orchestratorIp != null) return orchestratorIp;

    try {
      final row = await supabase
          .from('ip_config')
          .select('ip')
          .eq('id', 'orchestrator')
          .maybeSingle();

      return row?['ip'] as String?;
    } catch (e) {
      debugPrint("❌ Failed to fetch orchestrator IP: $e");
      return null;
    }
  }

  /// ✅ Fetch latest air quality data from FastAPI with Supabase fallback
  Future<void> _fetchAirQualityData() async {
    if (orchestratorIp == null || orchestratorIp!.isEmpty) {
      debugPrint("⚠️ Skipping fetch: no orchestrator IP.");
      return;
    }

    final url = Uri.parse("http://$orchestratorIp:8001/air-quality");

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        setState(() {
          airQualityData = List<Map<String, dynamic>>.from(data);
          useSupabase = false;
          isLoading = false;
        });
      } else {
        debugPrint("⚠️ API returned ${response.statusCode}, switching to Supabase");
        await _fetchAirQualityFromSupabase();
      }
    } catch (e) {
      debugPrint("❌ API fetch failed: $e — Falling back to Supabase");
      await _fetchAirQualityFromSupabase();
    }
  }

  /// ✅ Subscribe to orchestrator updates
  Future<void> _subscribeToUpdates() async {
    if (orchestratorIp == null) return;

    final url = Uri.parse("http://$orchestratorIp:8001/subscribe/air-quality");

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) {
        debugPrint("✅ Subscribed to orchestrator updates");
        isSubscribed = true;
      } else {
        throw Exception("Subscription failed: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("⚠️ Subscription failed: $e");
      isSubscribed = false;
      setState(() => useSupabase = true);
      await _fetchAirQualityFromSupabase();
    }
  }

  /// ✅ Unsubscribe from orchestrator when leaving the page
  Future<void> _unsubscribeFromOrchestrator() async {
    if (orchestratorIp == null || !isSubscribed) return;

    final url = Uri.parse("http://$orchestratorIp:8001/unsubscribe-air-quality");
    try {
      await http.get(url).timeout(const Duration(seconds: 3));
      debugPrint("🛑 Unsubscribed from orchestrator updates");
    } catch (e) {
      debugPrint("⚠️ Unsubscribe failed: $e");
    }
    isSubscribed = false;
  }

  /// ✅ Send heartbeat every 30 seconds to keep connection alive
  void _startHeartbeat() {
    _stopHeartbeat();
    heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (orchestratorIp == null) return;

      final heartbeatUrl = "http://$orchestratorIp:8001/heartbeat/air-quality";
      try {
        await http.get(Uri.parse(heartbeatUrl)).timeout(const Duration(seconds: 10));
        debugPrint("💓 Heartbeat sent to orchestrator");
      } catch (e) {
        debugPrint("⚠️ Heartbeat failed: $e");
      }
    });
  }

  void _stopHeartbeat() {
    heartbeatTimer?.cancel();
    heartbeatTimer = null;
  }

  /// ✅ Fetch air quality data from Supabase (fallback mode)
  Future<void> _fetchAirQualityFromSupabase() async {
    try {
      final data = await supabase
          .from('air_quality_data')
          .select()
          .order('created_at', ascending: false)
          .limit(50);

      if (data.isEmpty) {
        debugPrint("⚠️ No data found in Supabase.");
        setState(() {
          airQualityData = [];
          isLoading = false;
          useSupabase = true;
        });
        return;
      }

      setState(() {
        airQualityData = List<Map<String, dynamic>>.from(data);
        useSupabase = true;
        isLoading = false;
      });

      debugPrint("✅ Fetched ${airQualityData.length} rows from Supabase");
    } catch (e) {
      debugPrint("❌ Supabase fetch failed: $e");
      setState(() {
        airQualityData = [];
        isLoading = false;
      });
    }
  }

  /// ✅ Safe double parser for dynamic values
  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    return double.tryParse(value.toString()) ?? 0.0;
  }

  /// ✅ Info card widget (threshold-based color)
  Widget _buildInfoCard(String label, dynamic value, double mildThreshold, double criticalThreshold) {
    final double numericValue = _toDouble(value);

    Color backgroundColor = AppColors.fill;
    if (numericValue >= mildThreshold && numericValue < criticalThreshold) {
      backgroundColor = AppColors.primary.withOpacity(0.2);
    } else if (numericValue >= criticalThreshold) {
      backgroundColor = Colors.red.withOpacity(0.25);
    }

    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(6),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.dark.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.dark,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              numericValue.toStringAsFixed(1),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: numericValue >= criticalThreshold
                    ? Colors.red
                    : numericValue >= mildThreshold
                        ? AppColors.primary
                        : AppColors.dark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ Build sensor charts dynamically
  Widget _buildSensorChart(String label, String key, Color color) {
    final List<FlSpot> spots = [];
    final reversed = airQualityData.reversed.toList();

    for (int i = 0; i < reversed.length; i++) {
      spots.add(FlSpot(i.toDouble(), _toDouble(reversed[i][key])));
    }

    final double maxY = spots.isNotEmpty
        ? spots.map((e) => e.y).reduce((a, b) => a > b ? a : b)
        : 100;

    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.fill,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.dark.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.dark,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 150,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxY + (maxY * 0.2),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY > 0 ? maxY / 4 : 10,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: AppColors.dark.withOpacity(0.1),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        interval: (spots.length / 5).clamp(1, 5).toDouble(),
                        getTitlesWidget: (value, _) {
                          final formatted = value >= 1000
                              ? value.toStringAsFixed(0)
                              : value >= 1
                                  ? value.toStringAsFixed(1)
                                  : value.toStringAsFixed(3);
                          return Text(formatted, style: const TextStyle(fontSize: 8, color: AppColors.dark));
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: maxY > 0 ? maxY / 4 : 10,
                        getTitlesWidget: (value, _) {
                          final formatted = value >= 1000
                              ? value.toStringAsFixed(0)
                              : value >= 1
                                  ? value.toStringAsFixed(1)
                                  : value.toStringAsFixed(3);
                          return Text(formatted, style: const TextStyle(fontSize: 8, color: AppColors.dark));
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      barWidth: 2,
                      color: color,
                      belowBarData: BarAreaData(
                        show: true,
                        color: color.withOpacity(0.25),
                      ),
                      dotData: FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (airQualityData.isEmpty) {
      return const Center(
        child: Text(
          "No air quality data available",
          style: TextStyle(color: AppColors.dark, fontSize: 16),
        ),
      );
    }

    final latest = airQualityData.first;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                "Air Quality Overview",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.dark,
                ),
              ),
              if (useSupabase)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.cloud_off, color: Colors.red, size: 22),
                ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              _buildInfoCard("Alcohol", latest["alcohol_count"], 20, 60),
              _buildInfoCard("CO (PPM)", latest["co_count"], 20, 50),
              _buildInfoCard("CO₂ (PPM)", latest["co2_count"], 800, 1500),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              _buildInfoCard("Smoke", latest["smoke_count"], 50, 120),
              _buildInfoCard("Particles (PPM)", latest["particle_ppm"], 150, 300),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              _buildInfoCard("Humidity (%)", latest["hum"], 35, 80),
              _buildInfoCard("Temperature (°C)", latest["temp"], 30, 35),
            ],
          ),
          const SizedBox(height: 24),

          const Text(
            "Sensor Data Trends",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.dark,
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              _buildSensorChart("Particles (PPM)", "particle_ppm", AppColors.primary),
              _buildSensorChart("CO (PPM)", "co_count", AppColors.primary),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              _buildSensorChart("CO₂ (PPM)", "co2_count", AppColors.primary),
              _buildSensorChart("Alcohol (PPM)", "alcohol_count", AppColors.primary),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              _buildSensorChart("Temperature (°C)", "temp", AppColors.primary),
              _buildSensorChart("Humidity (%)", "hum", AppColors.primary),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              _buildSensorChart("Smoke", "smoke_count", AppColors.primary),
            ],
          ),
        ],
      ),
    );
  }
}
