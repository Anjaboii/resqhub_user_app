import 'package:flutter/material.dart';
import 'screens/shell.dart';

void main() {
  runApp(const ResQHubUserApp());
}

class ResQHubUserApp extends StatelessWidget {
  const ResQHubUserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ResQHub',
      theme: ThemeData.dark(useMaterial3: true),
      home: const AppShell(),
    );
  }
}
