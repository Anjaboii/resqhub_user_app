import 'package:flutter/material.dart';
import 'screens/shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
      home: const AppShell(),
    );
  }
}
