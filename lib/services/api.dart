import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;
Map<String, String> piIpMap = {};
Future<void> loadPiIps() async {
  final rows = await supabase.from('ip_config').select('id, ip');
  piIpMap = {
    for (var row in rows) row['id'] as String: row['ip'] as String,
  };
  debugPrint('Loaded Pi IPs: $piIpMap');
}
Future<void> sendCommand({
  required String device,
  required String action,
  String? visitorName,
  BuildContext? context,
}) 

async {
  final ip = piIpMap[device];
  if (ip == null || ip.isEmpty) {
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⚠️ No IP found for $device')),
      );
    }
    return;
  }

  final piBaseUrl = 'http://$ip';

  try {
    final user = supabase.auth.currentUser;
    var displayName = 'Unknown User';

    if (user != null) {
      final prof = await supabase
          .from('profiles')
          .select('name')
          .eq('id', user.id)
          .maybeSingle();

      if (prof != null && (prof['name'] as String?)?.isNotEmpty == true) {
        displayName = prof['name'] as String;
      } else if (user.email != null) {
        displayName = user.email!;
      }
    }

    // Send request to Pi (always)
    final res = await http
        .post(
          Uri.parse('$piBaseUrl/$device'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'action': action,
            'visitor_name': visitorName,
            'user_name': displayName,
          }),
        )
        .timeout(const Duration(seconds: 5));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Pi responded with ${res.statusCode}: ${res.body}');
    }


    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Command sent: $device → $action')),
      );
    }
  } catch (e) {
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error sending command: $e')),
      );
    }
    rethrow;
  }
}

Future<String?> getOrchestratorIp() async {
  try {
    final row = await supabase
        .from('ip_config')
        .select('ip')
        .eq('id', 'orchestrator')
        .maybeSingle();

    if (row != null) {
      return row['ip'] as String?;
    }
    return null;
  } catch (e) {
    debugPrint("❌ Failed to fetch orchestrator IP: $e");
    return null;
  }
}
