// lib/main.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'env.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  runApp(const VGNetApp());
}

class VGNetApp extends StatelessWidget {
  const VGNetApp({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'VGnet',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFFC21F4C),
      ),
      home: session == null ? const LoginScreen() : const DashboardScreen(),
    );
  }
}
