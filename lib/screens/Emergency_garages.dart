import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

class EmergencyGarages extends StatelessWidget {
  const EmergencyGarages({super.key});

  Future<void> _makeCall(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) return;
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    try { await launchUrl(launchUri, mode: LaunchMode.externalApplication); } catch (e) { debugPrint("Error: $e"); }
  }

  Future<void> _openMap(String? address) async {
    if (address == null || address.isEmpty) return;
    final String query = Uri.encodeComponent(address);
    final Uri googleMapsUri = Uri.parse("https://www.google.com/maps/search/?api=1&query=$query");
    try { await launchUrl(googleMapsUri, mode: LaunchMode.externalApplication); } catch (e) { debugPrint("Could not open maps: $e"); }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = AppTheme.getTextPrimary(isDark);
    final dimColor = AppTheme.getTextDim(isDark);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.tr('emergencyContacts'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('providers').where('role', isEqualTo: 'garage').where('isOnline', isEqualTo: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppTheme.accent));
          final garages = snapshot.data?.docs ?? [];

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: garages.length,
            itemBuilder: (context, index) {
              final data = garages[index].data() as Map<String, dynamic>;
              final String name = data['garageName'] ?? data['name'] ?? "Garage Service";
              final String address = data['garageAddress'] ?? "Location Unavailable";
              final String phoneNumber = data['phone'] ?? "";

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.getCard(isDark).withValues(alpha: isDark ? 0.5 : 1.0),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.getStroke(isDark).withValues(alpha: 0.5)),
                ),
                child: Row(children: [
                  Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.build_circle_outlined, color: AppTheme.accent, size: 20)),
                  const SizedBox(width: 15),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                    Text(address, style: TextStyle(color: dimColor, fontSize: 11), maxLines: 1),
                  ])),
                  Row(children: [
                    IconButton(icon: const Icon(Icons.map_outlined, color: AppTheme.accent), onPressed: () => _openMap(address)),
                    IconButton(icon: const Icon(Icons.phone_in_talk, color: Colors.greenAccent), onPressed: () => _makeCall(phoneNumber)),
                  ]),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}