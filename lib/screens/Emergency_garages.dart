import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

class EmergencyGarages extends StatelessWidget {
  const EmergencyGarages({super.key});

  Future<void> _makeCall(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) return;
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      await launchUrl(launchUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  // 🛠️ NEW: Navigation Logic
  Future<void> _openMap(String? address) async {
    if (address == null || address.isEmpty) return;

    // Encodes the address (e.g., "64/1 Galigamuwa Town") for a URL
    final String query = Uri.encodeComponent(address);
    final Uri googleMapsUri = Uri.parse("https://www.google.com/maps/search/?api=1&query=$query");

    try {
      await launchUrl(googleMapsUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Could not open maps: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        elevation: 0,
        title: const Text("EMERGENCY CONTACTS",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('providers')
            .where('role', isEqualTo: 'garage')
            .where('isOnline', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.accent));
          }

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
                  color: AppTheme.card.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.stroke.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    // Icon logic
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: AppTheme.accent.withOpacity(0.1),
                          shape: BoxShape.circle
                      ),
                      child: const Icon(Icons.build_circle_outlined, color: AppTheme.accent, size: 20),
                    ),
                    const SizedBox(width: 15),

                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                          Text(address, style: const TextStyle(color: AppTheme.textDim, fontSize: 11), maxLines: 1),
                        ],
                      ),
                    ),

                    // 🛠️ Action Buttons
                    Row(
                      children: [
                        // Map Button
                        IconButton(
                          icon: const Icon(Icons.map_outlined, color: AppTheme.accent),
                          onPressed: () => _openMap(address),
                        ),
                        // Phone Button
                        IconButton(
                          icon: const Icon(Icons.phone_in_talk, color: Colors.greenAccent),
                          onPressed: () => _makeCall(phoneNumber),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}