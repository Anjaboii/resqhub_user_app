import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class GarageNavigationView extends StatefulWidget {
  final Map<String, dynamic> reqData;
  final String requestId;

  const GarageNavigationView({
    super.key,
    required this.reqData,
    required this.requestId
  });

  @override
  State<GarageNavigationView> createState() => _GarageNavigationViewState();
}

class _GarageNavigationViewState extends State<GarageNavigationView> {
  final Completer<GoogleMapController> _controller = Completer();

  bool _isAtLeast(String current, String target) {
    const order = ['requested', 'accepted', 'repairing', 'completed'];
    return order.indexOf(current.toLowerCase()) >= order.indexOf(target.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text("Navigate to Garage", style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: AppTheme.bg,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.home_rounded, color: AppTheme.accent),
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('requests').doc(widget.requestId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          final String status = data['status'] ?? '';
          final String garageName = data['garageName'] ?? '';
          final String garageAddress = data['garageAddress'] ?? '';

          final double lat = (data['lat'] as num?)?.toDouble() ?? 0.0;
          final double lng = (data['lng'] as num?)?.toDouble() ?? 0.0;
          final LatLng garageLoc = LatLng(lat, lng);

          return Column(
            children: [
              Expanded(
                flex: 3,
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(target: garageLoc, zoom: 15),
                  markers: {
                    Marker(
                      markerId: const MarkerId("garage_pin"),
                      position: garageLoc,
                      infoWindow: InfoWindow(title: garageName, snippet: garageAddress),
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                    ),
                  },
                  onMapCreated: (c) => _controller.complete(c),
                  zoomControlsEnabled: false,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                ),
              ),

              Expanded(
                flex: 4,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    GlassCard(
                      child: Column(
                        children: [
                          if (status.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                  color: AppTheme.accent.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20)
                              ),
                              child: Text(status.toUpperCase(),
                                  style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w900, fontSize: 12)),
                            ),
                          const SizedBox(height: 16),

                          Row(
                            children: [
                              const CircleAvatar(
                                  backgroundColor: AppTheme.accent,
                                  child: Icon(Icons.store_rounded, color: Colors.black)
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(garageName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                    Text(garageAddress, style: const TextStyle(color: AppTheme.textDim, fontSize: 12)),
                                  ],
                                ),
                              ),

                              IconButton.filled(
                                onPressed: () async {
                                  final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
                                  if (await canLaunchUrl(Uri.parse(url))) {
                                    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                                  }
                                },
                                icon: const Icon(Icons.navigation_rounded, color: Colors.black),
                                style: IconButton.styleFrom(backgroundColor: AppTheme.accent),
                              )
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    _StatusStep(
                        active: _isAtLeast(status, 'requested'),
                        title: "Finding Garage",
                        sub: "Locating the nearest available partner"
                    ),
                    _StatusStep(
                        active: _isAtLeast(status, 'accepted'),
                        title: "Garage Ready",
                        sub: garageName.isNotEmpty ? "$garageName is expecting you." : "The garage is expecting you."
                    ),
                    _StatusStep(
                        active: _isAtLeast(status, 'repairing'),
                        title: "At Workshop",
                        sub: "Your vehicle is currently being repaired"
                    ),
                    _StatusStep(
                        active: _isAtLeast(status, 'completed'),
                        title: "Job Finished",
                        sub: "Service complete. Drive safe!",
                        isLast: true
                    ),
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

class _StatusStep extends StatelessWidget {
  final bool active, isLast;
  final String title, sub;

  const _StatusStep({
    required this.active,
    required this.title,
    required this.sub,
    this.isLast = false
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        children: [
          Column(
            children: [
              Icon(
                  active ? Icons.check_circle : Icons.circle_outlined,
                  color: active ? AppTheme.accent : AppTheme.textDim,
                  size: 22
              ),
              if (!isLast)
                Expanded(
                    child: Container(
                        width: 2,
                        color: active ? AppTheme.accent : AppTheme.stroke
                    )
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: active ? Colors.white : AppTheme.textDim
                      )
                  ),
                  Text(sub,
                      style: TextStyle(
                          fontSize: 12,
                          color: active ? Colors.white70 : AppTheme.textDim.withOpacity(0.5)
                      )
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}