import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../tracking/live_tracking_screen.dart';
import 'service_detail_screen.dart'; // 🎯 Ensure this import points to your new file

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String filter = "All";

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Scaffold(body: Center(child: Text("Login Required")));

    return Scaffold(
      appBar: AppBar(title: const Text("History", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24))),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('requests').where('userId', isEqualTo: uid).snapshots(),
              builder: (context, snap) {
                final docs = snap.data?.docs ?? [];
                final completed = docs.where((d) => d['status'] == 'completed').length;
                return Row(
                  children: [
                    _TopStat(label: "Total Jobs", value: docs.length.toString()),
                    const SizedBox(width: 12),
                    _TopStat(label: "Completed", value: completed.toString()),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: ["All", "Requested", "Completed", "Cancelled"].map((s) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(s),
                  selected: filter == s,
                  onSelected: (_) => setState(() => filter = s),
                  selectedColor: AppTheme.accent,
                  backgroundColor: AppTheme.card,
                  labelStyle: TextStyle(color: filter == s ? Colors.white : AppTheme.textDim, fontSize: 13, fontWeight: FontWeight.bold),
                  shape: StadiumBorder(side: BorderSide(color: filter == s ? AppTheme.accent : Colors.transparent)),
                  showCheckmark: false,
                ),
              )).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('requests')
                  .where('userId', isEqualTo: uid)
                  .orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snap.data!.docs.where((d) => filter == "All" || d['status'] == filter.toLowerCase()).toList();
                if (docs.isEmpty) return const Center(child: Text("No records found", style: TextStyle(color: AppTheme.textDim)));

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final data = docs[i].data();
                    final status = data['status'] ?? 'requested';
                    Color statusColor = status == 'completed' ? Colors.greenAccent : (status == 'cancelled' ? Colors.redAccent : Colors.orangeAccent);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.card.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.stroke.withOpacity(0.5)),
                      ),
                      child: ListTile(
                        // 🎯 UPDATED NAVIGATION LOGIC
                        onTap: () {
                          if (status == 'completed' || status == 'cancelled') {
                            // Go to static summary for past trips
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ServiceDetailScreen(jobData: data),
                              ),
                            );
                          } else {
                            // Go to live tracking for active trips
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LiveTrackingScreen(
                                  requestId: docs[i].id,
                                  serviceName: data['serviceType'] ?? "",
                                  vehicleName: data['vehicle']?['name'] ?? "",
                                  location: data['locationText'] ?? "",
                                ),
                              ),
                            );
                          }
                        },
                        contentPadding: const EdgeInsets.all(16),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(data['serviceType']?.toUpperCase() ?? "SERVICE", style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                            Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Text("${data['vehicle']?['name']} • ${data['vehicle']?['plate']}", style: const TextStyle(color: Colors.white70)),
                            const SizedBox(height: 4),
                            Row(children: [
                              const Icon(Icons.location_on, size: 14, color: AppTheme.textDim),
                              const SizedBox(width: 4),
                              Expanded(child: Text(data['locationText'] ?? "", style: const TextStyle(color: AppTheme.textDim, fontSize: 12), overflow: TextOverflow.ellipsis)),
                            ]),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TopStat extends StatelessWidget {
  final String label, value;
  const _TopStat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.accent)),
            Text(label, style: const TextStyle(color: AppTheme.textDim, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}