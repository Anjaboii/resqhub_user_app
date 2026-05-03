import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../payment/payment_screen.dart';

class GarageNavigationView extends StatefulWidget {
  final Map<String, dynamic> reqData;
  final String requestId;

  const GarageNavigationView({
    super.key,
    required this.reqData,
    required this.requestId,
  });

  @override
  State<GarageNavigationView> createState() => _GarageNavigationViewState();
}

class _GarageNavigationViewState extends State<GarageNavigationView> {
  final Completer<GoogleMapController> _controller = Completer();

  bool _isAtLeast(String current, String target) {
    const order = ['requested', 'accepted', 'arrived', 'in_progress', 'completed'];
    final ci = order.indexOf(current.toLowerCase());
    final ti = order.indexOf(target.toLowerCase());
    if (ci < 0 || ti < 0) return false;
    return ci >= ti;
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.white10),
        ),
        title: const Text("Cancel Request?",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
            "Are you sure you want to cancel this garage request?",
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("NO, WAIT")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('requests')
                  .doc(widget.requestId)
                  .update({'status': 'cancelled'});
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            child: const Text("YES, CANCEL",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingView(Map<String, dynamic> data) {
    final String garageName = data['garageName'] ?? 'Your Garage';
    final num? price = data['price'] as num?;

    return Container(
      color: AppTheme.bg,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: GlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Colors.green, size: 60),
              const SizedBox(height: 12),
              const Text("Job Completed!",
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              if (price != null) ...[
                const SizedBox(height: 8),
                Text("LKR ${price.toStringAsFixed(0)}",
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.accent)),
              ],
              const Divider(height: 40, color: Colors.white10),
              CircleAvatar(
                radius: 40,
                backgroundColor: AppTheme.accent.withOpacity(0.2),
                child: const Icon(Icons.store_rounded,
                    color: AppTheme.accent, size: 40),
              ),
              const SizedBox(height: 12),
              Text(garageName,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const Text("Service Provider",
                  style: TextStyle(color: AppTheme.textDim, fontSize: 14)),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                  child: const Text("DONE",
                      style: TextStyle(
                          color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text("Navigate to Garage",
            style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: AppTheme.bg,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.home_rounded, color: AppTheme.accent),
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('requests')
            .doc(widget.requestId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final String status =
          (data['status'] ?? '').toString().toLowerCase();
          final String garageName = data['garageName'] ?? '';
          final String garageAddress = data['garageAddress'] ?? '';
          final String? providerId = data['providerId'] as String?;

          if (status == 'cancelled') {
            WidgetsBinding.instance.addPostFrameCallback((_) =>
                Navigator.of(context).popUntil((route) => route.isFirst));
            return const Center(child: CircularProgressIndicator());
          }

          // ✅ Payment first, then rating
          if (status == 'completed') {
            if (data['paymentStatus'] != 'paid') {
              return PaymentScreen(
                requestId: widget.requestId,
                reqData: data,
                onPaymentComplete: () => setState(() {}),
              );
            }
            return _buildRatingView(data);
          }

          // No provider assigned yet — still searching
          if (providerId == null || providerId.isEmpty) {
            return _buildWaitingView(status);
          }

          // Fetch garage's static lat/lng from providers collection
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('providers')
                .doc(providerId)
                .get(),
            builder: (context, provSnap) {
              if (!provSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!provSnap.data!.exists) {
                return const Center(
                  child: Text("Garage info unavailable",
                      style: TextStyle(color: Colors.white54)),
                );
              }

              final provData =
              provSnap.data!.data() as Map<String, dynamic>;
              final double garageLat =
                  (provData['lat'] as num?)?.toDouble() ?? 0.0;
              final double garageLng =
                  (provData['lng'] as num?)?.toDouble() ?? 0.0;
              final LatLng garageLoc = LatLng(garageLat, garageLng);

              return Column(
                children: [
                  Expanded(
                    flex: 3,
                    child: GoogleMap(
                      initialCameraPosition:
                      CameraPosition(target: garageLoc, zoom: 15),
                      markers: {
                        Marker(
                          markerId: const MarkerId("garage_pin"),
                          position: garageLoc,
                          infoWindow: InfoWindow(
                              title: garageName, snippet: garageAddress),
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueRed),
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
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accent.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    status.toUpperCase().replaceAll('_', ' '),
                                    style: const TextStyle(
                                        color: AppTheme.accent,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12),
                                  ),
                                ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  const CircleAvatar(
                                    backgroundColor: AppTheme.accent,
                                    child: Icon(Icons.store_rounded,
                                        color: Colors.black),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text(garageName,
                                            style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold)),
                                        Text(garageAddress,
                                            style: const TextStyle(
                                                color: AppTheme.textDim,
                                                fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  IconButton.filled(
                                    onPressed: () async {
                                      final url =
                                          'https://www.google.com/maps/dir/?api=1&destination=$garageLat,$garageLng&travelmode=driving';
                                      if (await canLaunchUrl(Uri.parse(url))) {
                                        await launchUrl(Uri.parse(url),
                                            mode: LaunchMode.externalApplication);
                                      }
                                    },
                                    icon: const Icon(Icons.navigation_rounded,
                                        color: Colors.black),
                                    style: IconButton.styleFrom(
                                        backgroundColor: AppTheme.accent),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _StatusStep(
                          active: _isAtLeast(status, 'requested'),
                          title: "Finding Garage",
                          sub: "Locating the nearest available partner",
                        ),
                        _StatusStep(
                          active: _isAtLeast(status, 'accepted'),
                          title: "Garage Ready",
                          sub: garageName.isNotEmpty
                              ? "$garageName is expecting you."
                              : "The garage is expecting you.",
                        ),
                        _StatusStep(
                          active: _isAtLeast(status, 'arrived'),
                          title: "Arrived",
                          sub: "You have arrived at the garage",
                        ),
                        _StatusStep(
                          active: _isAtLeast(status, 'in_progress'),
                          title: "At Workshop",
                          sub: "Your vehicle is currently being repaired",
                        ),
                        _StatusStep(
                          active: _isAtLeast(status, 'completed'),
                          title: "Job Finished",
                          sub: "Service complete. Drive safe!",
                          isLast: true,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildWaitingView(String status) {
    return Column(
      children: [
        Expanded(
          flex: 3,
          child: Container(
            color: AppTheme.card,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppTheme.accent),
                  SizedBox(height: 16),
                  Text("Finding a garage...",
                      style: TextStyle(color: Colors.white54)),
                ],
              ),
            ),
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status.toUpperCase().replaceAll('_', ' '),
                        style: const TextStyle(
                            color: AppTheme.accent,
                            fontWeight: FontWeight.w900,
                            fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppTheme.accent.withOpacity(0.2),
                          child: const Icon(Icons.store_rounded,
                              color: AppTheme.accent),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Searching...",
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              Text("A garage will be assigned shortly",
                                  style: TextStyle(
                                      color: AppTheme.textDim, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const _StatusStep(
                  active: true,
                  title: "Finding Garage",
                  sub: "Locating the nearest available partner"),
              const _StatusStep(
                  active: false,
                  title: "Garage Ready",
                  sub: "A garage will be assigned shortly"),
              const _StatusStep(
                  active: false,
                  title: "Arrived",
                  sub: "You have arrived at the garage"),
              const _StatusStep(
                  active: false,
                  title: "At Workshop",
                  sub: "Your vehicle is currently being repaired"),
              const _StatusStep(
                  active: false,
                  title: "Job Finished",
                  sub: "Service complete. Drive safe!",
                  isLast: true),
              if (status == 'requested')
                Padding(
                  padding: const EdgeInsets.only(top: 32, bottom: 16),
                  child: Center(
                    child: TextButton.icon(
                      onPressed: _showCancelDialog,
                      icon: const Icon(Icons.cancel_outlined,
                          color: Colors.redAccent),
                      label: const Text(
                        "CANCEL REQUEST",
                        style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
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
    this.isLast = false,
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
                size: 22,
              ),
              if (!isLast)
                Expanded(
                    child: Container(
                        width: 2,
                        color: active ? AppTheme.accent : AppTheme.card)),
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
                          color: active ? Colors.white : AppTheme.textDim)),
                  Text(sub,
                      style: TextStyle(
                          fontSize: 12,
                          color: active
                              ? Colors.white70
                              : AppTheme.textDim.withOpacity(0.5))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}