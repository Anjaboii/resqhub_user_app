import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

// Renamed to CarrierTrackingView to match your TrackingDispatcher
class CarrierTrackingView extends StatefulWidget {
  final String requestId, serviceName, vehicleName, location;

  const CarrierTrackingView({
    super.key,
    required this.requestId,
    required this.serviceName,
    required this.vehicleName,
    required this.location,
  });

  @override
  State<CarrierTrackingView> createState() => _CarrierTrackingViewState();
}

class _CarrierTrackingViewState extends State<CarrierTrackingView> {
  final Completer<GoogleMapController> _controller = Completer();
  bool _isAutoCameraEnabled = true;
  int _userRating = 0;

  bool _isAtLeast(String current, String target) {
    const order = ['requested', 'accepted', 'en route', 'arrived', 'in_progress', 'completed'];
    return order.indexOf(current) >= order.indexOf(target);
  }

  double _getProgressValue(String status) {
    switch (status.toLowerCase()) {
      case 'requested': return 0.15;
      case 'accepted': return 0.30;
      case 'en route': return 0.50;
      case 'arrived': return 0.65;
      case 'in_progress': return 0.85;
      case 'completed': return 1.0;
      default: return 0.1;
    }
  }

  void _recenterUser(LatLng userLoc) async {
    final GoogleMapController controller = await _controller.future;
    setState(() => _isAutoCameraEnabled = true);
    controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: userLoc, zoom: 16),
    ));
  }

  void _updateCamera(LatLng userLoc, LatLng driverLoc) async {
    if (!_isAutoCameraEnabled) return;
    final GoogleMapController controller = await _controller.future;
    LatLngBounds bounds;
    if (userLoc.latitude > driverLoc.latitude) {
      bounds = LatLngBounds(southwest: driverLoc, northeast: userLoc);
    } else {
      bounds = LatLngBounds(southwest: userLoc, northeast: driverLoc);
    }
    controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 70));
  }

  void _showCancelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white10)),
        title: const Text("Cancel Assistance?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text("Are you sure? This will remove your request from the provider's queue.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("NO, WAIT")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('requests').doc(widget.requestId).update({'status': 'cancelled'});
              if (context.mounted) Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text("YES, CANCEL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingView(Map<String, dynamic> reqData) {
    return Container(
      color: AppTheme.bg,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: GlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.green, size: 60),
              const SizedBox(height: 12),
              const Text("Job Completed!", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              const Divider(height: 40, color: Colors.white10),
              Column(
                children: [
                  CircleAvatar(radius: 40, backgroundColor: AppTheme.accent.withOpacity(0.2), child: const Icon(Icons.person, color: AppTheme.accent, size: 40)),
                  const SizedBox(height: 12),
                  Text(reqData['providerName'] ?? "Your Rescuer", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  const Text("Service Provider", style: TextStyle(color: AppTheme.textDim, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 30),
              const Text("How was your experience?", style: TextStyle(color: Colors.white70, fontSize: 15)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(index < _userRating ? Icons.star_rounded : Icons.star_outline_rounded, color: AppTheme.accent, size: 38),
                    onPressed: () => setState(() => _userRating = index + 1),
                  );
                }),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () async {
                    if (_userRating == 0) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a rating")));
                      return;
                    }
                    await FirebaseFirestore.instance.collection('requests').doc(widget.requestId).update({
                      'rating': _userRating.toDouble(),
                      'ratingStatus': 'submitted',
                    });
                    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: const Text("SUBMIT & CONTINUE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Tracking Carrier", style: TextStyle(fontWeight: FontWeight.w900)),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(icon: const Icon(Icons.home_rounded, color: AppTheme.accent), onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst)),
          ],
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('requests').doc(widget.requestId).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || !snapshot.data!.exists) return const Center(child: CircularProgressIndicator());
            final reqData = snapshot.data!.data() as Map<String, dynamic>;
            final String status = reqData['status'] ?? 'requested';
            final String? providerId = reqData['providerId'];
            final userLoc = LatLng(reqData['lat'] ?? 0, reqData['lng'] ?? 0);

            if (status == 'completed') return _buildRatingView(reqData);
            if (status == 'cancelled') WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.of(context).popUntil((route) => route.isFirst));

            return Column(
              children: [
                Expanded(
                  flex: 3,
                  child: Stack(
                    children: [
                      StreamBuilder<DocumentSnapshot>(
                        stream: providerId != null ? FirebaseFirestore.instance.collection('providers').doc(providerId).snapshots() : null,
                        builder: (context, pSnap) {
                          Set<Marker> markers = {
                            Marker(markerId: const MarkerId("user"), position: userLoc, infoWindow: const InfoWindow(title: "My Location")),
                          };
                          if (pSnap.hasData && pSnap.data!.exists) {
                            var pData = pSnap.data!.data() as Map<String, dynamic>;
                            if (pData['currentLat'] != null && pData['currentLng'] != null) {
                              var driverLoc = LatLng(pData['currentLat'], pData['currentLng']);
                              markers.add(Marker(
                                markerId: const MarkerId("driver"),
                                position: driverLoc,
                                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                                rotation: (pData['heading'] as num? ?? 0).toDouble(),
                                infoWindow: InfoWindow(title: reqData['providerName'] ?? "Rescuer"),
                              ));
                              _updateCamera(userLoc, driverLoc);
                            }
                          }
                          return GoogleMap(
                            initialCameraPosition: CameraPosition(target: userLoc, zoom: 15),
                            markers: markers,
                            onMapCreated: (c) => _controller.complete(c),
                            myLocationButtonEnabled: false,
                            zoomControlsEnabled: false,
                            onCameraMoveStarted: () { if (_isAutoCameraEnabled) setState(() => _isAutoCameraEnabled = false); },
                          );
                        },
                      ),
                      Positioned(bottom: 16, right: 16, child: FloatingActionButton.small(heroTag: "recenter", backgroundColor: AppTheme.bg.withOpacity(0.9), onPressed: () => _recenterUser(userLoc), child: Icon(Icons.my_location_rounded, color: _isAutoCameraEnabled ? AppTheme.accent : Colors.white))),
                    ],
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
                            Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: AppTheme.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Text(status.toUpperCase(), style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.2))),
                            const SizedBox(height: 12),
                            if (providerId != null) ...[
                              Row(
                                children: [
                                  const CircleAvatar(backgroundColor: AppTheme.accent, child: Icon(Icons.person, color: Colors.black)),
                                  const SizedBox(width: 12),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(reqData['providerName'] ?? "Rescuer Assigned", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const Text("Mechanic is on the way", style: TextStyle(color: AppTheme.textDim, fontSize: 12))])),
                                  IconButton.filled(
                                      onPressed: () async {
                                        final Uri launchUri = Uri(scheme: 'tel', path: reqData['providerPhone']);
                                        if (await canLaunchUrl(launchUri)) {
                                          await launchUrl(launchUri);
                                        }
                                      },
                                      icon: const Icon(Icons.phone, color: Colors.black),
                                      style: IconButton.styleFrom(backgroundColor: AppTheme.accent)
                                  )
                                ],
                              ),
                            ] else const Text("Searching for nearby help...", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white70)),
                            const SizedBox(height: 16),
                            ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: _getProgressValue(status), minHeight: 8, backgroundColor: AppTheme.stroke, color: AppTheme.accent)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _StatusItem(active: _isAtLeast(status, 'requested'), title: "Finding Help", sub: "Connecting to the ResQHub network", isPending: status == 'requested'),
                      _StatusItem(active: _isAtLeast(status, 'accepted'), title: "Rescuer Assigned", sub: "A provider has accepted your request", isPending: status == 'accepted'),
                      _StatusItem(active: _isAtLeast(status, 'en route'), title: "En Route", sub: "Provider is navigating to your location", isPending: status == 'en route'),
                      _StatusItem(active: _isAtLeast(status, 'in_progress'), title: reqData['serviceType'] == 'towing' ? "Towing Trip" : "Repairing", sub: "Work is currently in progress", isPending: status == 'in_progress'),
                      _StatusItem(active: _isAtLeast(status, 'completed'), title: "Service Complete", sub: "Your issue has been resolved", isLast: true),

                      if (status == 'requested')
                        Padding(
                          padding: const EdgeInsets.only(top: 40, bottom: 20),
                          child: Center(
                            child: TextButton.icon(
                              onPressed: () => _showCancelDialog(context),
                              icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
                              label: const Text(
                                  "CANCEL REQUEST",
                                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, letterSpacing: 1.1)
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 30),
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
}

class _StatusItem extends StatelessWidget {
  final bool active, isPending, isLast;
  final String title, sub;
  const _StatusItem({required this.active, required this.title, required this.sub, this.isPending = false, this.isLast = false});
  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        children: [
          Column(children: [Icon(active ? Icons.check_circle : Icons.circle_outlined, color: active ? AppTheme.accent : AppTheme.textDim, size: 24), if (!isLast) Expanded(child: Container(width: 2, color: active ? AppTheme.accent : AppTheme.stroke))]),
          const SizedBox(width: 16),
          Expanded(child: Padding(padding: const EdgeInsets.only(bottom: 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: active ? Colors.white : AppTheme.textDim, fontSize: 15)), Text(sub, style: TextStyle(fontSize: 13, color: active ? Colors.white70 : AppTheme.textDim.withOpacity(0.5))), if (isPending) const Padding(padding: EdgeInsets.only(top: 8), child: SizedBox(width: 20, height: 2, child: LinearProgressIndicator(color: AppTheme.accent, backgroundColor: Colors.transparent)))]))),
        ],
      ),
    );
  }
}