import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../l10n/app_localizations.dart';
import '../../services/notification_service.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'accepted': return Icons.check_circle_outline;
      case 'en_route': return Icons.local_shipping_rounded;
      case 'arrived': return Icons.location_on_rounded;
      case 'towing': return Icons.rv_hookup_rounded;
      case 'in_progress': return Icons.build_rounded;
      case 'completed': return Icons.verified_rounded;
      default: return Icons.notifications_active;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'accepted': return Colors.blue;
      case 'en_route': return Colors.orange;
      case 'arrived': return Colors.green;
      case 'towing': return Colors.purple;
      case 'in_progress': return Colors.amber;
      case 'completed': return Colors.teal;
      default: return AppTheme.accent;
    }
  }

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return '';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = AppTheme.getTextPrimary(isDark);
    final dimColor = AppTheme.getTextDim(isDark);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.tr('notifications'), style: const TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            onPressed: () async {
              if (uid == null) return;
              final batch = FirebaseFirestore.instance.batch();
              final snap = await FirebaseFirestore.instance.collection('users').doc(uid).collection('notifications').get();
              for (var doc in snap.docs) { batch.delete(doc.reference); }
              await batch.commit();
            },
            icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
            tooltip: 'Clear All Notifications',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users').doc(uid).collection('notifications')
            .orderBy('timestamp', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.notifications_off_outlined, size: 60, color: dimColor),
              const SizedBox(height: 16),
              Text(loc.tr('noNotifications'), style: TextStyle(color: dimColor)),
            ]));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final isRead = data['read'] == true;
              final status = data['status'] as String?;
              final statusColor = _getStatusColor(status);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassCard(
                  onTap: () {
                    if (!isRead && uid != null) NotificationService.markAsRead(uid, docs[i].id);
                  },
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                      child: Icon(_getStatusIcon(status), color: statusColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(data['title'] ?? "Update", style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 14))),
                        if (!isRead) Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle)),
                      ]),
                      const SizedBox(height: 4),
                      Text(data['body'] ?? "", style: TextStyle(color: dimColor, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(_timeAgo(data['timestamp'] as Timestamp?), style: TextStyle(color: dimColor.withValues(alpha: 0.6), fontSize: 11)),
                    ])),
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}