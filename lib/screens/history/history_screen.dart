import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../tracking/live_tracking_dispatcher.dart';
import 'service_detail_screen.dart';

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
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = AppTheme.getTextPrimary(isDark);
    final dimColor = AppTheme.getTextDim(isDark);

    return Scaffold(
      appBar: AppBar(title: Text(loc.tr('history'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24))),
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
                return Row(children: [
                  _TopStat(label: loc.tr('totalJobs'), value: docs.length.toString(), isDark: isDark),
                  const SizedBox(width: 12),
                  _TopStat(label: loc.tr('completed'), value: completed.toString(), isDark: isDark),
                ]);
              },
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [loc.tr('all'), loc.tr('requested'), loc.tr('completed'), loc.tr('cancelled')].map((s) {
                final filterKey = s == loc.tr('all') ? 'All' : s == loc.tr('requested') ? 'Requested' : s == loc.tr('completed') ? 'Completed' : 'Cancelled';
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(s),
                    selected: filter == filterKey,
                    onSelected: (_) => setState(() => filter = filterKey),
                    selectedColor: AppTheme.accent,
                    backgroundColor: AppTheme.getCard(isDark),
                    labelStyle: TextStyle(color: filter == filterKey ? Colors.white : dimColor, fontSize: 13, fontWeight: FontWeight.bold),
                    shape: StadiumBorder(side: BorderSide(color: filter == filterKey ? AppTheme.accent : Colors.transparent)),
                    showCheckmark: false,
                  ),
                );
              }).toList(),
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
                if (docs.isEmpty) return Center(child: Text("No records found", style: TextStyle(color: dimColor)));

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
                        color: AppTheme.getCard(isDark).withValues(alpha: isDark ? 0.5 : 1.0),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.getStroke(isDark).withValues(alpha: 0.5)),
                      ),
                      child: ListTile(
                        onTap: () {
                          if (status == 'completed' || status == 'cancelled') {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => ServiceDetailScreen(jobData: data, requestId: docs[i].id)));
                          } else {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => TrackingDispatcher(requestId: docs[i].id)));
                          }
                        },
                        contentPadding: const EdgeInsets.all(16),
                        title: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text(data['serviceType']?.toUpperCase() ?? "SERVICE", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5, color: textColor)),
                          Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                        ]),
                        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const SizedBox(height: 8),
                          Text("${data['vehicle']?['name']} • ${data['vehicle']?['plate']}", style: TextStyle(color: textColor.withValues(alpha: 0.7))),
                          if (status == 'completed' && data['rating'] != null && data['rating'] > 0)
                            Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
                              ...List.generate(5, (index) => Icon(Icons.star_rounded, size: 14, color: index < (data['rating'] as num).toInt() ? Colors.amber : (isDark ? Colors.white24 : Colors.grey.shade300))),
                              const SizedBox(width: 6),
                              Text("${data['rating']}", style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
                            ])),
                          const SizedBox(height: 4),
                          Row(children: [
                            Icon(Icons.location_on, size: 14, color: dimColor), const SizedBox(width: 4),
                            Expanded(child: Text(data['locationText'] ?? "", style: TextStyle(color: dimColor, fontSize: 12), overflow: TextOverflow.ellipsis)),
                          ]),
                          if (data['createdAt'] != null && data['createdAt'] is Timestamp) ...[
                            const SizedBox(height: 4),
                            Row(children: [
                              Icon(Icons.access_time_rounded, size: 14, color: dimColor), const SizedBox(width: 4),
                              Text(() {
                                final dt = (data['createdAt'] as Timestamp).toDate();
                                return '${dt.day}/${dt.month}/${dt.year} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                              }(), style: TextStyle(color: dimColor, fontSize: 12)),
                            ]),
                          ],
                        ]),
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
  final bool isDark;
  const _TopStat({required this.label, required this.value, required this.isDark});
  @override
  Widget build(BuildContext context) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.getCard(isDark), borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.accent)),
        Text(label, style: TextStyle(color: AppTheme.getTextDim(isDark), fontSize: 12, fontWeight: FontWeight.bold)),
      ]),
    ));
  }
}