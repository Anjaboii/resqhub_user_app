import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../tracking/live_tracking_screen.dart'; // ✅ Ensure this is imported

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String filter = "All"; // All | Requested | Completed | Cancelled

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const SafeArea(
        child: Scaffold(
          body: Center(child: Text("Please login to view history")),
        ),
      );
    }

    final uid = user.uid;

    // Query for LIST (filtered)
    Query<Map<String, dynamic>> listQuery = FirebaseFirestore.instance
        .collection('requests')
        .where('userId', isEqualTo: uid);

    if (filter != "All") {
      listQuery = listQuery.where('status', isEqualTo: filter.toLowerCase());
    }

    listQuery = listQuery.orderBy('createdAt', descending: true);

    // Query for STATS (always ALL requests)
    final statsQuery = FirebaseFirestore.instance
        .collection('requests')
        .where('userId', isEqualTo: uid);

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Service History", style: TextStyle(fontWeight: FontWeight.w900)),
        ),
        body: Column(
          children: [
            // ===== Stats Section =====
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: statsQuery.snapshots(),
                builder: (context, snap) {
                  final allDocs = snap.data?.docs ?? [];
                  final completedCount = allDocs.where((d) => (d.data()['status'] ?? '') == 'completed').length;

                  return GlassCard(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _Stat(title: completedCount.toString(), sub: "Completed"),
                        const _Stat(title: "—", sub: "Total Spent"),
                        const _Stat(title: "—", sub: "Avg Rating"),
                      ],
                    ),
                  );
                },
              ),
            ),

            // ===== Filter Chips =====
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _Chip("All", selected: filter == "All", onTap: () => setState(() => filter = "All")),
                  const SizedBox(width: 8),
                  _Chip("Requested", selected: filter == "Requested", onTap: () => setState(() => filter = "Requested")),
                  const SizedBox(width: 8),
                  _Chip("Completed", selected: filter == "Completed", onTap: () => setState(() => filter = "Completed")),
                  const SizedBox(width: 8),
                  _Chip("Cancelled", selected: filter == "Cancelled", onTap: () => setState(() => filter = "Cancelled")),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ===== List of Requests =====
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: listQuery.snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snap.hasError) {
                    return Center(child: Text("Error: ${snap.error}", style: const TextStyle(color: Colors.white)));
                  }

                  final docs = snap.data?.docs ?? [];

                  if (docs.isEmpty) {
                    return const Center(child: Text("No history found.", style: TextStyle(color: AppTheme.textDim)));
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final d = docs[i];
                      final data = d.data();

                      // ✅ FIXED: Pass the requestId and other data to the Tracking screen on tap
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LiveTrackingScreen(
                                  requestId: d.id, // 🔥 This fixes the Red Screen
                                  serviceName: (data['serviceType'] ?? "Service").toString(),
                                  vehicleName: (data['vehicle']?['name'] ?? "Vehicle").toString(),
                                  location: (data['locationText'] ?? "Location").toString(),
                                ),
                              ),
                            );
                          },
                          child: _HistoryCard.fromDoc(d),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String title;
  final String sub;
  const _Stat({required this.title, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(sub, style: const TextStyle(color: AppTheme.textDim, fontSize: 12)),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _Chip(this.label, {this.selected = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accent.withOpacity(0.2) : AppTheme.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? AppTheme.accent : AppTheme.stroke),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppTheme.accent : AppTheme.textDim,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final String title;
  final String provider;
  final String badge;
  final String price;
  final String vehicle;
  final String date;
  final String location;
  final int stars;

  const _HistoryCard({
    required this.title,
    required this.provider,
    required this.badge,
    required this.price,
    required this.vehicle,
    required this.date,
    required this.location,
    required this.stars,
  });

  factory _HistoryCard.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final serviceType = (data['serviceType'] ?? 'unknown').toString();
    final status = (data['status'] ?? 'requested').toString();
    final locationText = (data['locationText'] ?? '').toString();
    final createdAt = data['createdAt'];

    final vehicleMap = (data['vehicle'] is Map) ? (data['vehicle'] as Map) : {};
    final vName = (vehicleMap['name'] ?? '').toString();
    final vPlate = (vehicleMap['plate'] ?? '').toString();

    String niceService(String s) {
      if (s.isEmpty) return "Service";
      final withSpaces = s.replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => "${m[1]} ${m[2]}");
      return withSpaces[0].toUpperCase() + withSpaces.substring(1);
    }

    String formatDate(dynamic ts) {
      if (ts is Timestamp) {
        final dt = ts.toDate();
        return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} • ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
      }
      return "—";
    }

    return _HistoryCard(
      title: niceService(serviceType),
      provider: (data['providerName'] ?? "—").toString(),
      badge: status[0].toUpperCase() + status.substring(1),
      price: (data['priceText'] ?? "—").toString(),
      vehicle: [vName, vPlate].where((e) => e.isNotEmpty).join(" • "),
      date: formatDate(createdAt),
      location: locationText,
      stars: (data['rating'] is int) ? (data['rating'] as int) : 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badge.toLowerCase() == 'completed' ? const Color(0xFF0D2A1A) : const Color(0xFF1B1F2A),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(badge, style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(vehicle, style: const TextStyle(color: AppTheme.textDim, fontSize: 12)),
          Text(date, style: const TextStyle(color: AppTheme.textDim, fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on_rounded, size: 14, color: AppTheme.textDim),
              const SizedBox(width: 4),
              Expanded(child: Text(location, style: const TextStyle(color: AppTheme.textDim, fontSize: 12), overflow: TextOverflow.ellipsis)),
            ],
          ),
        ],
      ),
    );
  }
}