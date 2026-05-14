import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../l10n/app_localizations.dart';
import '../request/request_flow.dart';
import '../tracking/live_tracking_dispatcher.dart';
import '../history/service_detail_screen.dart';
import 'notification_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _getGreeting(AppLocalizations loc) {
    final hour = DateTime.now().hour;
    if (hour < 12) return loc.tr('goodMorning');
    if (hour < 17) return loc.tr('goodAfternoon');
    return loc.tr('goodEvening');
  }

  void _showEmergencySOS(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(color: AppTheme.getCard(isDark), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(10))),
          const SizedBox(height: 20),
          Text(loc.tr('emergencySOS'), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: AppTheme.getTextPrimary(isDark))),
          const SizedBox(height: 20),
          _EmergencyTile(icon: Icons.local_police_rounded, label: loc.tr('police'), number: "119", color: Colors.blue),
          _EmergencyTile(icon: Icons.local_hospital_rounded, label: loc.tr('ambulance'), number: "1990", color: Colors.red),
          _EmergencyTile(icon: Icons.local_fire_department_rounded, label: loc.tr('fire'), number: "110", color: Colors.orange),
          const SizedBox(height: 10),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = AppTheme.getTextPrimary(isDark);
    final dimColor = AppTheme.getTextDim(isDark);
    final userName = user?.displayName ?? "User";

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          children: [
            // ── Header with greeting ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("${_getGreeting(loc)} 👋", style: TextStyle(color: dimColor, fontSize: 14)),
                  Text(userName, style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.w900)),
                ])),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').doc(user?.uid)
                      .collection('notifications').where('read', isEqualTo: false).snapshots(),
                  builder: (context, snap) {
                    final count = snap.data?.docs.length ?? 0;
                    return Stack(alignment: Alignment.topRight, children: [
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: IconButton(icon: Icon(Icons.notifications_none_rounded, color: textColor, size: 26),
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen()))),
                      ),
                      if (count > 0) Positioned(top: 6, right: 6, child: Container(
                        padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                        child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      )),
                    ]);
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Active request banners (show ALL active requests) ──
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('requests')
                  .where('userId', isEqualTo: user?.uid)
                  .where('status', whereIn: ['requested', 'accepted', 'en_route', 'arrived', 'towing', 'in_progress']).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();
                final docs = snapshot.data!.docs;
                return Column(
                  children: docs.map((reqDoc) {
                    final reqData = reqDoc.data() as Map<String, dynamic>;
                    final status = (reqData['status'] ?? '').toString();
                    final serviceType = (reqData['serviceType'] ?? 'Service').toString();
                    final isCarrier = reqData['providerRole'] == 'carrier';

                    // Status-based color
                    Color statusColor;
                    IconData statusIcon;
                    if (['en_route', 'towing'].contains(status)) {
                      statusColor = Colors.blue;
                      statusIcon = Icons.local_shipping_rounded;
                    } else if (['arrived', 'in_progress'].contains(status)) {
                      statusColor = Colors.green;
                      statusIcon = Icons.build_circle_rounded;
                    } else {
                      statusColor = Colors.orangeAccent;
                      statusIcon = Icons.emergency_share;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: GlassCard(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TrackingDispatcher(requestId: reqDoc.id))),
                        child: Row(children: [
                          Container(padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                            child: Icon(statusIcon, color: statusColor, size: 22)),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text("${isCarrier ? '🚛' : '🔧'} ${serviceType.toUpperCase()}",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor, letterSpacing: 0.3)),
                            const SizedBox(height: 2),
                            Text("${status.toUpperCase().replaceAll('_', ' ')} — ${loc.tr('tapToTrack')}",
                                style: TextStyle(fontSize: 12, color: dimColor)),
                          ])),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: statusColor),
                          ),
                        ]),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            // ── Live Network Pulse ──
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('providers').limit(50).snapshots(),
              builder: (context, snapshot) {
                final count = snapshot.data?.docs.length ?? 0;
                final isActive = count > 0;
                return Center(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 40),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isActive ? Colors.green.withValues(alpha: 0.3) : Colors.orange.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(isActive ? Icons.radar : Icons.wifi_tethering_off, 
                             color: isActive ? Colors.green : Colors.orange, size: 16),
                        const SizedBox(width: 8),
                        Text(isActive ? "Network Active: $count Responders Available" : "Connecting to Rescue Network...", 
                             style: TextStyle(color: isActive ? Colors.green : Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
                );
              },
            ),

            // ── SOS Button ──
            Center(
              child: GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RequestFlowScreen())),
                onLongPress: () => _showEmergencySOS(context),
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) => Container(
                    width: 180, height: 180,
                    decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
                      BoxShadow(color: AppTheme.accent.withValues(alpha: 0.15 * (1 - _pulseController.value)),
                        blurRadius: 35, spreadRadius: 25 * _pulseController.value),
                    ]),
                    child: child,
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(shape: BoxShape.circle,
                      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: AppTheme.sosGradient)),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 45),
                      const SizedBox(height: 4),
                      Text(loc.tr('sos'), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 3)),
                    ]),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(child: Text(loc.tr('tapForHelp'), style: TextStyle(color: dimColor, fontSize: 11))),
            const SizedBox(height: 32),



            // ── Safe Driving Tip ──
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                Container(padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.wb_sunny_rounded, color: Colors.blue)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("Safe Driving Tip", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13)),
                  Text("Keep a safe distance. Roads might be slippery today.", style: TextStyle(color: dimColor, fontSize: 12)),
                ])),
              ]),
            ),
            const SizedBox(height: 28),

            const SizedBox(height: 20),

            // ── Recent Activity (tappable) ──
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('requests')
                  .where('userId', isEqualTo: user?.uid)
                  .orderBy('createdAt', descending: true).limit(3).snapshots(),
              builder: (context, snap) {
                if (!snap.hasData || snap.data!.docs.isEmpty) return const SizedBox.shrink();
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(loc.tr('recentActivity'), style: TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 12),
                  ...snap.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final status = data['status'] ?? '';
                    final statusColor = status == 'completed' ? Colors.green : status == 'cancelled' ? Colors.red : Colors.orange;
                    // Format date/time
                    String timeStr = '';
                    final ts = data['createdAt'];
                    if (ts != null && ts is Timestamp) {
                      final dt = ts.toDate();
                      final now = DateTime.now();
                      final diff = now.difference(dt);
                      if (diff.inMinutes < 60) {
                        timeStr = '${diff.inMinutes}m ago';
                      } else if (diff.inHours < 24) {
                        timeStr = '${diff.inHours}h ago';
                      } else {
                        timeStr = '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                      }
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GlassCard(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => ServiceDetailScreen(jobData: data, requestId: doc.id),
                          ));
                        },
                        child: Row(children: [
                          Container(padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                            child: Icon(status == 'completed' ? Icons.check_circle : status == 'cancelled' ? Icons.cancel : Icons.pending,
                              color: statusColor, size: 20)),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text((data['serviceType'] ?? 'Service').toString().toUpperCase(),
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor, letterSpacing: 0.5)),
                            Text("${data['vehicle']?['name'] ?? ''} • ${status.toUpperCase()}", style: TextStyle(color: dimColor, fontSize: 11)),
                            if (timeStr.isNotEmpty)
                              Text(timeStr, style: TextStyle(color: dimColor.withValues(alpha: 0.7), fontSize: 10)),
                          ])),
                          Icon(Icons.chevron_right_rounded, color: dimColor, size: 22),
                        ]),
                      ),
                    );
                  }),
                  const SizedBox(height: 20),
                ]);
              },
            ),
          ],
        ),
      ),
    );
  }
}


class _ServiceCard extends StatelessWidget {
  final IconData icon; final String title; final Color color;
  const _ServiceCard({required this.icon, required this.title, required this.color});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassCard(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RequestFlowScreen())),
      padding: const EdgeInsets.all(10),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 24)),
        const SizedBox(height: 8),
        Text(title, style: TextStyle(color: AppTheme.getTextPrimary(isDark), fontWeight: FontWeight.w600, fontSize: 12), textAlign: TextAlign.center),
      ]),
    );
  }
}

class _EmergencyTile extends StatelessWidget {
  final IconData icon; final String label, number; final Color color;
  const _EmergencyTile({required this.icon, required this.label, required this.number, required this.color});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.1), child: Icon(icon, color: color)),
      title: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.getTextPrimary(isDark))),
      subtitle: Text(number, style: TextStyle(color: AppTheme.getTextDim(isDark))),
      trailing: IconButton(icon: Icon(Icons.phone, color: color), onPressed: () => launchUrl(Uri(scheme: 'tel', path: number))),
    );
  }
}