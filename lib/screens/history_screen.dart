// lib/screens/history_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final supabase = Supabase.instance.client;

  bool loading = true;
  String? role;
  String? name;

  List<Map<String, dynamic>> logs = [];

  @override
  void initState() {
    super.initState();
    _fetchProfileAndLogs();
  }

  /// Fetch the user's profile first, then fetch logs based on role
  Future<void> _fetchProfileAndLogs() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const Placeholder()),
          (_) => false,
        );
        return;
      }

      final data = await supabase
          .from('profiles')
          .select('name, role')
          .eq('id', user.id)
          .maybeSingle();

      setState(() {
        role = data?['role'] as String?;
        name = data?['name'] as String?;
      });

      await _fetchLogs();
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error loading profile')),
      );
    }
  }

  /// Fetch logs based on role — admins get all logs, users only see their own
  Future<void> _fetchLogs() async {
    try {
      var query = supabase
          .from('history')
          .select()
          .order('created_at', ascending: false)
          .limit(25);

      // If not admin, only fetch user's logs
      if (role != 'admin' && name != null) {
        query = supabase
            .from('history')
            .select()
            .eq('name', name!)
            .order('created_at', ascending: false)
            .limit(25);
      }

      final data = await query;

      setState(() {
        logs = (data as List).cast<Map<String, dynamic>>();
        loading = false;
      });
    } catch (_) {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Text(
              'Student Access Logs',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 20),

          // Show logs in a single-column list
          for (final item in logs)
            Container(
              margin: const EdgeInsets.only(bottom: 15),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: AppColors.fill,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Leading circular avatar (first letter of name)
                  CircleAvatar(
                    backgroundColor: Colors.blueAccent.withOpacity(0.15),
                    radius: 24,
                    child: Text(
                      (item['name'] ?? 'U')[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueAccent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),

                  // Main log info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // User name
                        Text(
                          item['name'] ?? 'Unknown User',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Request type (entry / exit)
                        Text(
                          item['request_name'] ?? 'Unknown Action',
                          style: const TextStyle(
                            color: AppColors.dark,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Timestamp
                        Text(
                          _formatTime(item['created_at']),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(dynamic ts) {
    if (ts == null) return '';
    final dt = DateTime.tryParse(ts.toString());
    if (dt == null) return ts.toString();
    return DateFormat.yMMMd().add_jm().format(dt.toLocal());
  }
}
