import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/primary_button.dart';

class LiveTrackingScreen extends StatelessWidget {
  final String requestId;
  final String serviceName;
  final String vehicleName;
  final String location;

  const LiveTrackingScreen({
    super.key,
    required this.requestId,
    required this.serviceName,
    required this.vehicleName,
    required this.location,
  });

  bool _isAtLeast(String current, String target) {
    const order = ['requested', 'accepted', 'en route', 'arrived', 'completed'];
    return order.indexOf(current) >= order.indexOf(target);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Live Tracking", style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.redAccent)),
          )
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('requests').doc(requestId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final String status = data['status'] ?? 'requested';
          final String providerName = data['providerName'] ?? "Searching...";
          final bool accepted = _isAtLeast(status, 'accepted');

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GlassCard(
                child: Column(
                  children: [
                    const Text("Map View", style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 12),
                    Container(
                      height: 150,
                      color: const Color(0xFF111A2E),
                      child: const Center(child: Icon(Icons.location_on, color: AppTheme.accent, size: 40)),
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: _isAtLeast(status, 'completed') ? 1.0 : (accepted ? 0.7 : 0.25),
                      color: AppTheme.accent,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (accepted)
                GlassCard(
                  child: Column(
                    children: [
                      Text(providerName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      const Text("Professional Mechanic", style: TextStyle(color: AppTheme.textDim)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: PrimaryButton(text: "Call", onPressed: () {}, filled: false)),
                          const SizedBox(width: 8),
                          Expanded(child: PrimaryButton(text: "Message", onPressed: () {}, filled: false)),
                        ],
                      )
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("STATUS", style: TextStyle(fontWeight: FontWeight.bold)),
                    _StatusItem(active: _isAtLeast(status, 'requested'), title: "Searching", sub: "Finding providers..."),
                    _StatusItem(active: _isAtLeast(status, 'accepted'), title: "Accepted", sub: "Request accepted"),
                    _StatusItem(active: _isAtLeast(status, 'en route'), title: "En Route", sub: "On the way"),
                    _StatusItem(active: _isAtLeast(status, 'arrived'), title: "Arrived", sub: "At your location"),
                    _StatusItem(active: _isAtLeast(status, 'completed'), title: "Completed", sub: "Job finished"),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusItem extends StatelessWidget {
  final bool active;
  final String title;
  final String sub;
  const _StatusItem({required this.active, required this.title, required this.sub});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(active ? Icons.check_circle : Icons.radio_button_unchecked, color: active ? AppTheme.accent : Colors.grey),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), Text(sub, style: const TextStyle(fontSize: 12))]),
        ],
      ),
    );
  }
}