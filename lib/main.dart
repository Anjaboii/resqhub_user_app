import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'auth/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const ResQHubUserApp());
}

class ResQHubUserApp extends StatelessWidget {
  const ResQHubUserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ResQHub',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF070A12),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF7A1A),
          secondary: Color(0xFFFF7A1A),
        ),
      ),
      home: const AuthGate(), // ✅ changed from AppShell()
    );
  }
}