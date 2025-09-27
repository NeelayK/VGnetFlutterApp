// lib/screens/dashboard_screen.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/api.dart';
import '../theme.dart';
import 'air_quality_screen.dart';
import 'command_menu.dart';
import 'content_area.dart';
import 'history_screen.dart';
import 'notification_dropdown.dart';
import 'plant_monitor.dart';
import 'qr_scan_screen.dart';
import 'unknown_visitor_logs.dart';
import 'work_hours.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  String? role;
  String? name;
  bool loading = true;
  String activeCommand = 'doors';

  String? scanningMode;
  String visitorName = '';

  bool piLoading = true;

  late final List<Map<String, dynamic>> notifications = [];
  bool showDropdown = false;

  late RealtimeChannel _channel;

  final commands = const [
    {'key': 'doors', 'label': 'Scan Doors', 'icon': Icons.qr_code},
    {'key': 'unknown_visitor_logs', 'label': 'Unknown Visitors', 'icon': Icons.person},
    {'key': 'logs', 'label': 'Student Logs', 'icon': Icons.article},
    {'key': 'work', 'label': 'Work Hours', 'icon': Icons.access_time},
    {'key': 'plant', 'label': 'Plant Monitor', 'icon': Icons.eco},
    {'key': 'air_quality', 'label': 'Air Quality', 'icon': Icons.air},
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadPiIps();
    _loadExistingNotifications();
    _subscribeAlerts();
    
  }


  Future<void> _markAsRead(Map<String, dynamic> notif) async {
    try {
      await supabase.from('notification').delete().match({
        'description': notif['description'],
        'timestamp': notif['timestamp'],
        'name': notif['name'],
      });

      setState(() {
        notifications.remove(notif);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to remove notification")),
      );
    }
  }

  Future<void> _loadProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const Placeholder()),
        (_) => false,
      );
      return;
    }

    try {
      final data = await supabase
          .from('profiles')
          .select('name, role')
          .eq('id', user.id)
          .maybeSingle();

      setState(() {
        role = data?['role'] as String?;
        name = data?['name'] as String?;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error loading profile')),
      );
    }
  }

  Future<void> _loadPiIps() async {
    try {
      await loadPiIps();
      setState(() => piLoading = false);
    } catch (e) {
      setState(() => piLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load Raspberry Pis')),
      );
    }
  }

  /// ✅ Initial load of alerts from Supabase
  Future<void> _loadExistingNotifications() async {
    try {
      final data = await supabase
          .from('notification')
          .select('description, timestamp, name')
          .order('timestamp', ascending: false);

      setState(() {
        notifications.clear();
        notifications.addAll((data as List).cast<Map<String, dynamic>>());
      });
    } catch (e) {
      debugPrint("Error loading : $e");
    }
  }

  void _subscribeAlerts() {
_channel = supabase
    .channel('notification')
    .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'notification',
      callback: (payload) {
        if (payload.eventType == 'INSERT') {
          setState(() {
            notifications.insert(0, {
              'id': payload.newRecord['id'],
              'description': payload.newRecord['message'],
              'timestamp': payload.newRecord['created_at'],
            });
          });
        } else if (payload.eventType == 'UPDATE') {
          setState(() {
            final index = notifications.indexWhere((n) => n['id'] == payload.newRecord['id']);
            if (index != -1) {
              notifications[index] = {
                'id': payload.newRecord['id'],
                'description': payload.newRecord['message'],
                'timestamp': payload.newRecord['created_at'],
              };
            }
          });
        } else if (payload.eventType == 'DELETE') {
          setState(() {
            notifications.removeWhere((n) => n['id'] == payload.oldRecord['id']);
          });
        }
      },
    )
    .subscribe();

  }

  Future<void> _logout() async {
    await supabase.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const _LoginRedirect()),
      (_) => false,
    );
  }

  @override
  void dispose() {
    supabase.removeChannel(_channel);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: AppColors.light,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.light,
      appBar: AppBar(
        backgroundColor: AppColors.light,
        elevation: 0,
        title: Text(
          'Hey, ${name ?? ''}',
          style: const TextStyle(
              color: AppColors.dark, fontWeight: FontWeight.w700),
        ),
        actions: [
          // Notifications button
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications, color: AppColors.dark),
                onPressed: () => setState(() => showDropdown = !showDropdown),
              ),
              if (notifications.isNotEmpty)
                Positioned(
                  right: 6,
                  top: 6,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${notifications.length}',
                      style: const TextStyle(
                          color: AppColors.fill,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
          // Logout button
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary, width: 2),
                foregroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _logout,
              child: const Text('Logout',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
      Column(
        children: [
          CommandMenu(
            commands: commands,
            activeCommand: activeCommand,
            onCommandSelected: (cmdKey) {
              setState(() {
                activeCommand = cmdKey;
              });
            },
          ),
          const SizedBox(height: 8),
          // Content area
          ContentArea(
            activeCommand: activeCommand,
            doorsScreen: _buildDoors(),
            unknownVisitorLogsScreen: const UnknownVisitorLogsScreen(),
            logsScreen: const HistoryScreen(),
            workScreen: const WorkHoursScreen(),
            plantMonitorScreen: const PlantMonitorScreen(),
            airQualityScreen: const AirQualityScreen(),
          ),
        ],
      ),
NotificationsDropdown(
  showDropdown: showDropdown,
  notifications: notifications,
  onMarkAsRead: _markAsRead,
),
    ],
  ),
);
  }

  // ---------- Doors ----------
Widget _buildDoors() {
  return Column(
    children: [
      if (scanningMode != null)
        Padding(
          padding: const EdgeInsets.all(10),
          child: SizedBox(
            height: 420,
            child: QRScanScreen(
              scanMode: scanningMode!,
              visitorName: visitorName,
              onDone: () => setState(() => scanningMode = null),
            ),
          ),
        )
      else
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('Scan Doors'),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => setState(() => scanningMode = 'user'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text('Scan as User'),
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Visitor Name',
                  filled: true,
                  fillColor: AppColors.fill,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (v) => setState(() => visitorName = v),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: visitorName.trim().isEmpty
                    ? null
                    : () => setState(() => scanningMode = 'visitor'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text('Scan for Visitor'),
              ),
              const SizedBox(height: 20),

              // ✅ Show admin-only door controls
              if (role == 'admin') ...[
                const SizedBox(height: 16),
                const Text(
                  "Admin Controls",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.dark,
                  ),
                ),
                const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => _sendDoorCommand('temporary_open'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                      child: const Text(
                        "Temporary Open",
                        style: TextStyle(
                          color: AppColors.light,
                        ),
                      ),
                    ),
              ],

              const SizedBox(height: 20),

              // ✅ Auto Pi assignment info
              piLoading
                  ? const CircularProgressIndicator()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: piIpMap.entries.map((entry) {
                        return Text(
                          "✔ ${entry.key} → ${entry.value}",
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      }).toList(),
                    ),
            ],
          ),
        ),
    ],
  );
}

Future<void> _sendDoorCommand(String action) async {
  try {
    await sendCommand(
      device: 'main_door',
      action: action,
      context: context,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Command "$action" sent successfully!')),
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to send command: $e')),
    );
  }
}


  Widget _card({required Widget child}) {
    return Container(
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.fill,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.dark.withAlpha(5),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: child,
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      );
}

// Redirect after logout
class _LoginRedirect extends StatelessWidget {
  const _LoginRedirect();

  @override
  Widget build(BuildContext context) => const SizedBox();
}