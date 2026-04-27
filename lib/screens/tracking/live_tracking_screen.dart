import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

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
    // 🛡️ Prevents accidental exit via back button/gestures
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Request is active. Use the Home icon to exit.")),
        );
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Tracking Rescuer"),
          automaticallyImplyLeading: false, // Removes the back arrow
          actions: [
            IconButton(
              icon: const Icon(Icons.home_rounded, color: AppTheme.accent),
              tooltip: "Go to Home",
              onPressed: () {
                // Navigate back to the very first screen (Home)
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
          ],
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('requests').doc(requestId).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: CircularProgressIndicator());
            }

            final reqData = snapshot.data!.data() as Map<String, dynamic>;
            final String status = reqData['status'] ?? 'requested';
            final String? providerId = reqData['providerId'];

            // Handle cancelled state if it happens elsewhere
            if (status == 'cancelled') {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              });
            }

            return Column(
              children: [
                // 🗺️ LIVE MAP
                Expanded(
                  flex: 3,
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: providerId != null
                        ? FirebaseFirestore.instance.collection('providers').doc(providerId).snapshots()
                        : null,
                    builder: (context, pSnap) {
                      Set<Marker> markers = {
                        Marker(
                          markerId: const MarkerId("user"),
                          position: LatLng(reqData['lat'] ?? 0, reqData['lng'] ?? 0),
                          infoWindow: const InfoWindow(title: "My Breakdown Spot"),
                        ),
                      };

                      if (pSnap.hasData && pSnap.data!.exists) {
                        var pData = pSnap.data!.data() as Map<String, dynamic>;
                        markers.add(Marker(
                          markerId: const MarkerId("driver"),
                          position: LatLng(pData['currentLat'], pData['currentLng']),
                          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                          infoWindow: InfoWindow(title: reqData['providerName'] ?? "Rescuer"),
                        ));
                      }

                      return GoogleMap(
                        initialCameraPosition: CameraPosition(
                            target: LatLng(reqData['lat'] ?? 0, reqData['lng'] ?? 0),
                            zoom: 16 // High zoom to see the streets clearly
                        ),
                        markers: markers,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
                      );
                    },
                  ),
                ),

                // 📄 STATUS & INFO
                Expanded(
                  flex: 4,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      GlassCard(
                        child: Column(
                          children: [
                            Text(status.toUpperCase(),
                                style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                            const SizedBox(height: 10),
                            if (providerId != null)
                              Text("Rescuer: ${reqData['providerName']}",
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            LinearProgressIndicator(
                              value: status == 'completed' ? 1.0 : (providerId != null ? 0.7 : 0.3),
                              backgroundColor: AppTheme.stroke,
                              color: AppTheme.accent,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      _StatusItem(active: _isAtLeast(status, 'requested'), title: "Finding Help", sub: "Searching for providers in Dambulla"),
                      _StatusItem(active: _isAtLeast(status, 'accepted'), title: "Rescuer Assigned", sub: "Help is on the way"),
                      _StatusItem(active: _isAtLeast(status, 'en route'), title: "Moving", sub: "Rescuer is driving to your spot"),
                      _StatusItem(active: _isAtLeast(status, 'completed'), title: "Finished", sub: "Service successful"),

                      const SizedBox(height: 30),

                      // ❌ CANCEL BUTTON
                      if (status == 'requested')
                        Center(
                          child: TextButton.icon(
                            onPressed: () => _showCancelDialog(context),
                            icon: const Icon(Icons.close, color: Colors.redAccent, size: 18),
                            label: const Text("Cancel My Request", style: TextStyle(color: Colors.redAccent)),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showCancelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: const Text("Cancel Request?"),
        content: const Text("Are you sure? This will notify nearby rescuers to stop searching."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("No, Keep it")),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('requests').doc(requestId).update({'status': 'cancelled'});
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            child: const Text("Yes, Cancel", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
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
          Icon(active ? Icons.check_circle : Icons.radio_button_unchecked,
              color: active ? AppTheme.accent : AppTheme.textDim),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: active ? Colors.white : AppTheme.textDim)),
              Text(sub, style: const TextStyle(fontSize: 12, color: AppTheme.textDim)),
            ],
          ),
        ],
      ),
    );
  }
}