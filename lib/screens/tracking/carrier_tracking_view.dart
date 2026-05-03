import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

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
  bool _destinationSubmitted = false;
  bool _dialogShown = false;

  // Status order for towing
  final _towingOrder = const [
    'requested', 'accepted', 'en_route', 'arrived', 'towing', 'completed'
  ];

  // Status order for fuel delivery
  final _fuelOrder = const [
    'requested', 'accepted', 'en_route', 'arrived', 'completed'
  ];

  bool _isAtLeast(String current, String target, List<String> order) {
    final c = current.toLowerCase();
    final t = target.toLowerCase();
    return order.indexOf(c) >= order.indexOf(t);
  }

  double _getProgressValue(String status, bool isTowing) {
    final order = isTowing ? _towingOrder : _fuelOrder;
    final idx = order.indexOf(status.toLowerCase());
    if (idx < 0) return 0.1;
    return (idx + 1) / order.length;
  }

  void _recenterUser(LatLng userLoc) async {
    final controller = await _controller.future;
    setState(() => _isAutoCameraEnabled = true);
    controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: userLoc, zoom: 16),
    ));
  }

  void _updateCamera(LatLng userLoc, LatLng driverLoc) async {
    if (!_isAutoCameraEnabled) return;
    final controller = await _controller.future;
    LatLngBounds bounds;
    if (userLoc.latitude > driverLoc.latitude) {
      bounds = LatLngBounds(southwest: driverLoc, northeast: userLoc);
    } else {
      bounds = LatLngBounds(southwest: userLoc, northeast: driverLoc);
    }
    controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 70));
  }

  void _showDestinationDialog() {
    if (_dialogShown || _destinationSubmitted) return;
    _dialogShown = true;

    final destController = TextEditingController();
    String? errorText;
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.bg,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.location_on, color: AppTheme.accent),
                  SizedBox(width: 8),
                  Text("Enter Destination",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Where should the carrier deliver your vehicle?",
                    style: TextStyle(color: AppTheme.textDim, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: destController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "e.g. Nelundeniya",
                      hintStyle: const TextStyle(color: AppTheme.textDim),
                      errorText: errorText,
                      filled: true,
                      fillColor: AppTheme.stroke,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.accent),
                      ),
                      prefixIcon:
                      const Icon(Icons.search, color: AppTheme.textDim),
                    ),
                  ),
                ],
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: isLoading
                        ? null
                        : () async {
                      final input = destController.text.trim();
                      if (input.isEmpty) {
                        setDialogState(() =>
                        errorText = "Please enter a destination");
                        return;
                      }
                      setDialogState(() {
                        isLoading = true;
                        errorText = null;
                      });
                      try {
                        List<Location> locations =
                        await locationFromAddress(input);
                        if (locations.isEmpty) throw Exception("Not found");
                        final dest = locations.first;
                        await FirebaseFirestore.instance
                            .collection('requests')
                            .doc(widget.requestId)
                            .update({
                          'destinationName': input,
                          'destinationLat': dest.latitude,
                          'destinationLng': dest.longitude,
                          'destinationSetAt':
                          FieldValue.serverTimestamp(),
                        });
                        setState(() => _destinationSubmitted = true);
                        if (mounted) Navigator.of(context).pop();
                      } catch (e) {
                        setDialogState(() {
                          isLoading = false;
                          errorText =
                          "Location not found. Try a more specific name.";
                        });
                      }
                    },
                    child: isLoading
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.black, strokeWidth: 2),
                    )
                        : const Text("CONFIRM DESTINATION",
                        style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Tracking Carrier",
              style: TextStyle(fontWeight: FontWeight.w900)),
          automaticallyImplyLeading: false,
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

            final reqData = snapshot.data!.data() as Map<String, dynamic>;
            final String status = reqData['status'] ?? 'requested';
            final String? providerId = reqData['providerId'];
            final bool isTowing = reqData['serviceType'] == 'towing';
            final bool isFuel = reqData['serviceType'] == 'fuel';
            final userLoc =
            LatLng(reqData['lat'] ?? 0.0, reqData['lng'] ?? 0.0);
            final order = isTowing ? _towingOrder : _fuelOrder;

            // Completed → rating screen
            if (status.toLowerCase() == 'completed') {
              return _buildRatingView(reqData);
            }

            // Show destination dialog for towing when status = towing
            if (isTowing &&
                status.toLowerCase() == 'towing' &&
                !_destinationSubmitted &&
                reqData['destinationLat'] == null) {
              WidgetsBinding.instance
                  .addPostFrameCallback((_) => _showDestinationDialog());
            }

            if (reqData['destinationLat'] != null && !_destinationSubmitted) {
              _destinationSubmitted = true;
            }

            return Column(
              children: [
                Expanded(
                  flex: 3,
                  child: Stack(
                    children: [
                      StreamBuilder<DocumentSnapshot>(
                        stream: providerId != null
                            ? FirebaseFirestore.instance
                            .collection('providers')
                            .doc(providerId)
                            .snapshots()
                            : null,
                        builder: (context, pSnap) {
                          Set<Marker> markers = {
                            Marker(
                              markerId: const MarkerId("user"),
                              position: userLoc,
                              infoWindow: const InfoWindow(
                                  title: "Your Location"),
                            ),
                          };

                          if (reqData['destinationLat'] != null) {
                            markers.add(Marker(
                              markerId: const MarkerId("destination"),
                              position: LatLng(reqData['destinationLat'],
                                  reqData['destinationLng']),
                              icon: BitmapDescriptor.defaultMarkerWithHue(
                                  BitmapDescriptor.hueGreen),
                              infoWindow: InfoWindow(
                                  title: reqData['destinationName'] ??
                                      "Destination"),
                            ));
                          }

                          if (pSnap.hasData && pSnap.data!.exists) {
                            var pData =
                            pSnap.data!.data() as Map<String, dynamic>;
                            var driverLoc = LatLng(
                                pData['currentLat'] ?? 0.0,
                                pData['currentLng'] ?? 0.0);
                            markers.add(Marker(
                              markerId: const MarkerId("driver"),
                              position: driverLoc,
                              icon: BitmapDescriptor.defaultMarkerWithHue(
                                  BitmapDescriptor.hueAzure),
                              infoWindow: InfoWindow(
                                  title: reqData['providerName'] ?? "Carrier"),
                            ));
                            _updateCamera(userLoc, driverLoc);
                          }

                          return GoogleMap(
                            initialCameraPosition:
                            CameraPosition(target: userLoc, zoom: 15),
                            markers: markers,
                            onMapCreated: (c) => _controller.complete(c),
                            myLocationButtonEnabled: false,
                            zoomControlsEnabled: false,
                            onCameraMoveStarted: () {
                              if (_isAutoCameraEnabled) {
                                setState(() => _isAutoCameraEnabled = false);
                              }
                            },
                          );
                        },
                      ),
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: FloatingActionButton.small(
                          backgroundColor: AppTheme.bg.withOpacity(0.9),
                          onPressed: () => _recenterUser(userLoc),
                          child: Icon(Icons.my_location_rounded,
                              color: _isAutoCameraEnabled
                                  ? AppTheme.accent
                                  : Colors.white),
                        ),
                      ),
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
                            // Status badge
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
                            const SizedBox(height: 12),

                            // Provider info
                            if (providerId != null)
                              Row(
                                children: [
                                  const CircleAvatar(
                                    backgroundColor: AppTheme.accent,
                                    child:
                                    Icon(Icons.person, color: Colors.black),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            reqData['providerName'] ?? "Carrier",
                                            style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold)),
                                        Text(
                                          isFuel
                                              ? "Fuel delivery in progress"
                                              : "Carrier is active",
                                          style: const TextStyle(
                                              color: AppTheme.textDim,
                                              fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton.filled(
                                    onPressed: () => launchUrl(Uri.parse(
                                        "tel:${reqData['providerPhone']}")),
                                    icon: const Icon(Icons.phone,
                                        color: Colors.black),
                                    style: IconButton.styleFrom(
                                        backgroundColor: AppTheme.accent),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 16),

                            // Progress bar
                            LinearProgressIndicator(
                              value: _getProgressValue(status, isTowing),
                              backgroundColor: AppTheme.stroke,
                              color: AppTheme.accent,
                            ),

                            // Fuel details chip
                            if (isFuel) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: Colors.orange.withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.local_gas_station,
                                        color: Colors.orange, size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      "${reqData['fuelType'] ?? 'Fuel'} — ${reqData['fuelQuantity'] ?? '?'} Liters",
                                      style: const TextStyle(
                                          color: Colors.orange,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // Destination chip (towing)
                            if (isTowing &&
                                _destinationSubmitted &&
                                reqData['destinationName'] != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: Colors.green.withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.location_on,
                                        color: Colors.green, size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        "Delivering to: ${reqData['destinationName']}",
                                        style: const TextStyle(
                                            color: Colors.green,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Status timeline — different for towing vs fuel
                      if (isTowing) ...[
                        _StatusItem(
                            active: _isAtLeast(status, 'requested', order),
                            title: "Finding Help",
                            sub: "Connecting to ResQHub network"),
                        _StatusItem(
                            active: _isAtLeast(status, 'accepted', order),
                            title: "Carrier Assigned",
                            sub: "A carrier has accepted your request"),
                        _StatusItem(
                            active: _isAtLeast(status, 'en_route', order),
                            title: "En Route",
                            sub: "Carrier is navigating to you"),
                        _StatusItem(
                            active: _isAtLeast(status, 'arrived', order),
                            title: "Arrived",
                            sub: "Carrier is at your location"),
                        _StatusItem(
                            active: _isAtLeast(status, 'towing', order),
                            title: "Towing Trip",
                            sub: "Vehicle is being towed to destination"),
                        _StatusItem(
                            active: _isAtLeast(status, 'completed', order),
                            title: "Delivered",
                            sub: "Vehicle has reached the destination",
                            isLast: true),
                      ] else ...[
                        _StatusItem(
                            active: _isAtLeast(status, 'requested', order),
                            title: "Finding Help",
                            sub: "Connecting to ResQHub network"),
                        _StatusItem(
                            active: _isAtLeast(status, 'accepted', order),
                            title: "Carrier Assigned",
                            sub: "A carrier has accepted your request"),
                        _StatusItem(
                            active: _isAtLeast(status, 'en_route', order),
                            title: "En Route",
                            sub: "Carrier is on the way with your fuel"),
                        _StatusItem(
                            active: _isAtLeast(status, 'arrived', order),
                            title: "Fuel Delivered",
                            sub: "Carrier has arrived and delivered fuel"),
                        _StatusItem(
                            active: _isAtLeast(status, 'completed', order),
                            title: "Complete",
                            sub: "Safe travels!",
                            isLast: true),
                      ],
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

  Widget _buildRatingView(Map<String, dynamic> reqData) {
    final bool isFuel = reqData['serviceType'] == 'fuel';
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
              Text(
                isFuel ? "Fuel Delivered!" : "Job Completed!",
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              if (reqData['price'] != null) ...[
                const SizedBox(height: 8),
                Text(
                  "LKR ${(reqData['price'] as num).toStringAsFixed(0)}",
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.accent),
                ),
              ],
              const Divider(height: 40, color: Colors.white10),
              CircleAvatar(
                radius: 40,
                backgroundColor: AppTheme.accent.withOpacity(0.2),
                child:
                const Icon(Icons.person, color: AppTheme.accent, size: 40),
              ),
              const SizedBox(height: 12),
              Text(reqData['providerName'] ?? "Your Carrier",
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const Text("Service Provider",
                  style: TextStyle(color: AppTheme.textDim, fontSize: 14)),
              const SizedBox(height: 30),
              const Text("How was your experience?",
                  style: TextStyle(color: Colors.white70, fontSize: 15)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < _userRating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: AppTheme.accent,
                      size: 38,
                    ),
                    onPressed: () => setState(() => _userRating = index + 1),
                  );
                }),
              ),
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
                  onPressed: () async {
                    if (_userRating == 0) return;
                    await FirebaseFirestore.instance
                        .collection('requests')
                        .doc(widget.requestId)
                        .update({
                      'rating': _userRating.toDouble(),
                      'ratingStatus': 'submitted',
                    });
                    if (mounted) {
                      Navigator.of(context)
                          .popUntil((route) => route.isFirst);
                    }
                  },
                  child: const Text("SUBMIT & CONTINUE",
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
}

class _StatusItem extends StatelessWidget {
  final bool active, isLast;
  final String title, sub;
  const _StatusItem(
      {required this.active,
        required this.title,
        required this.sub,
        this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        children: [
          Column(children: [
            Icon(active ? Icons.check_circle : Icons.circle_outlined,
                color: active ? AppTheme.accent : AppTheme.textDim, size: 24),
            if (!isLast)
              Expanded(
                  child: Container(
                      width: 2,
                      color: active ? AppTheme.accent : AppTheme.stroke)),
          ]),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: active ? Colors.white : AppTheme.textDim,
                          fontSize: 15)),
                  Text(sub,
                      style: TextStyle(
                          fontSize: 13,
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