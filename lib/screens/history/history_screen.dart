import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

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

    Query baseQuery = FirebaseFirestore.instance
        .collection('requests')
        .where('userId', isEqualTo: uid);

    if (filter != "All") {
      // our status values are strings like "requested", "completed", "cancelled"
      baseQuery = baseQuery.where('status', isEqualTo: filter.toLowerCase());
    }

    final query = baseQuery.orderBy('createdAt', descending: true);

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Service History", style: TextStyle(fontWeight: FontWeight.w900)),
          actions: [
            IconButton(
              onPressed: () {
                // Optional: later open a real filter sheet
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Use chips to filter for now 🙂")),
                );
              },
              icon: const Icon(Icons.filter_alt_outlined, color: AppTheme.accent),
            )
          ],
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: query.snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snap.data?.docs ?? [];

            // Stats (simple ones for now)
            final completedCount = docs.where((d) {
              final data = d.data() as Map<String, dynamic>;
              return (data['status'] ?? '') == 'completed';
            }).length;

            // Total spent + rating not in DB yet, show placeholders
            final totalSpent = "—";
            final avgRating = "—";

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                GlassCard(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _Stat(title: completedCount.toString(), sub: "Completed"),
                      _Stat(title: totalSpent, sub: "Total Spent"),
                      _Stat(title: avgRating, sub: "Avg Rating"),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    _Chip(
                      "All",
                      selected: filter == "All",
                      onTap: () => setState(() => filter = "All"),
                    ),
                    const SizedBox(width: 8),
                    _Chip(
                      "Requested",
                      selected: filter == "Requested",
                      onTap: () => setState(() => filter = "Requested"),
                    ),
                    const SizedBox(width: 8),
                    _Chip(
                      "Completed",
                      selected: filter == "Completed",
                      onTap: () => setState(() => filter = "Completed"),
                    ),
                    const SizedBox(width: 8),
                    _Chip(
                      "Cancelled",
                      selected: filter == "Cancelled",
                      onTap: () => setState(() => filter = "Cancelled"),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                if (docs.isEmpty)
                  GlassCard(
                    child: const Padding(
                      padding: EdgeInsets.all(14),
                      child: Text(
                        "No requests yet.\nMake a request and it will appear here.",
                        style: TextStyle(color: AppTheme.textDim),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  for (final d in docs) ...[
                    _HistoryCard.fromDoc(d),
                    const SizedBox(height: 12),
                  ],
              ],
            );
          },
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

  factory _HistoryCard.fromDoc(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final serviceType = (data['serviceType'] ?? 'unknown').toString();
    final status = (data['status'] ?? 'requested').toString();
    final locationText = (data['locationText'] ?? '').toString();
    final createdAt = data['createdAt'];

    final vehicleMap = (data['vehicle'] is Map) ? (data['vehicle'] as Map) : {};
    final vName = (vehicleMap['name'] ?? '').toString();
    final vPlate = (vehicleMap['plate'] ?? '').toString();

    String niceService(String s) {
      // Convert enum-like names to nicer titles
      // battery -> Battery, flatTire -> Flat Tire, outOfFuel -> Out Of Fuel
      if (s.isEmpty) return "Service";
      final withSpaces = s.replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => "${m[1]} ${m[2]}");
      return withSpaces[0].toUpperCase() + withSpaces.substring(1);
    }

    String niceStatus(String s) {
      if (s.isEmpty) return "Requested";
      final t = s[0].toUpperCase() + s.substring(1);
      return t;
    }

    String formatDate(dynamic ts) {
      if (ts is Timestamp) {
        final dt = ts.toDate();
        // simple formatting without intl package
        final y = dt.year;
        final m = dt.month.toString().padLeft(2, '0');
        final d = dt.day.toString().padLeft(2, '0');
        final hh = dt.hour.toString().padLeft(2, '0');
        final mm = dt.minute.toString().padLeft(2, '0');
        return "$y-$m-$d • $hh:$mm";
      }
      return "—";
    }

    // Not stored yet in DB:
    final provider = (data['providerName'] ?? "—").toString();
    final price = (data['priceText'] ?? "—").toString();
    final stars = (data['rating'] is int) ? (data['rating'] as int) : 0;

    return _HistoryCard(
      title: niceService(serviceType),
      provider: provider,
      badge: niceStatus(status),
      price: price,
      vehicle: [vName, vPlate].where((e) => e.isNotEmpty).join(" • "),
      date: formatDate(createdAt),
      location: locationText,
      stars: stars,
    );
  }

  Color _badgeBg() {
    switch (badge.toLowerCase()) {
      case 'completed':
        return const Color(0xFF0D2A1A);
      case 'cancelled':
        return const Color(0xFF2A0D0D);
      default:
        return const Color(0xFF1B1F2A);
    }
  }

  Color _badgeFg() {
    switch (badge.toLowerCase()) {
      case 'completed':
        return const Color(0xFF3CE06D);
      case 'cancelled':
        return const Color(0xFFFF6B6B);
      default:
        return AppTheme.textDim;
    }
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
                  color: _badgeBg(),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge,
                  style: TextStyle(color: _badgeFg(), fontWeight: FontWeight.w800, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(provider, style: const TextStyle(color: AppTheme.textDim)),
          const SizedBox(height: 12),
          Text(vehicle.isEmpty ? "Vehicle —" : vehicle, style: const TextStyle(color: AppTheme.textDim, fontSize: 12)),
          const SizedBox(height: 6),
          Text(date, style: const TextStyle(color: AppTheme.textDim, fontSize: 12)),
          const SizedBox(height: 6),
          Text(location.isEmpty ? "Location —" : location, style: const TextStyle(color: AppTheme.textDim, fontSize: 12)),
          const SizedBox(height: 10),
          Row(
            children: [
              for (int i = 0; i < 5; i++)
                Icon(i < stars ? Icons.star_rounded : Icons.star_border_rounded, size: 18, color: AppTheme.accent),
              const Spacer(),
              Text(price, style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }
}