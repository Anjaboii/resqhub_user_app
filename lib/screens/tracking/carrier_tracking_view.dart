import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../l10n/app_localizations.dart';
import '../../services/notification_service.dart';
import '../payment/payment_screen.dart';

class CarrierTrackingView extends StatefulWidget {
  final String requestId, serviceName, vehicleName, location;
  const CarrierTrackingView({super.key, required this.requestId, required this.serviceName, required this.vehicleName, required this.location});
  @override
  State<CarrierTrackingView> createState() => _CarrierTrackingViewState();
}

class _CarrierTrackingViewState extends State<CarrierTrackingView> {
  final Completer<GoogleMapController> _controller = Completer();
  bool _isAutoCameraEnabled = true;
  int _userRating = 0;
  bool _destinationSubmitted = false;
  bool _dialogShown = false;
  String? _previousStatus;
  BitmapDescriptor? _truckIcon;
  BitmapDescriptor? _destIcon;

  final _towingOrder = const ['requested', 'accepted', 'en_route', 'arrived', 'towing', 'completed'];
  final _fuelOrder = const ['requested', 'accepted', 'en_route', 'arrived', 'completed'];
  final _accidentOrder = const ['requested', 'accepted', 'en_route', 'arrived', 'in_progress', 'completed'];

  @override
  void initState() {
    super.initState();
    _loadCustomMarkers();
  }

  Future<void> _loadCustomMarkers() async {
    _truckIcon = await _buildMarkerIcon(
      emoji: '🚛', bgColor: const Color(0xFF1E3A5F), borderColor: const Color(0xFF3B82F6), size: 120);
    // Destination uses a distinctive green marker pin
    _destIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    if (mounted) setState(() {});
  }

  Future<BitmapDescriptor> _buildMarkerIcon({required String emoji, required Color bgColor, required Color borderColor, double size = 120}) async {
    final iconUrl = 'https://img.icons8.com/3d-fluency/94/truck.png'; // 3D Truck for driver
    
    try {
      final request = await HttpClient().getUrl(Uri.parse(iconUrl));
      final response = await request.close();
      final bytes = await consolidateHttpClientResponseBytes(response);
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 48); // Made much smaller to fit the road
      final frameInfo = await codec.getNextFrame();
      final ui.Image image = frameInfo.image;
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        return BitmapDescriptor.bytes(byteData.buffer.asUint8List());
      }
    } catch (e) {
      debugPrint("Failed to load 3d marker: $e");
    }
    
    // Fallback if network fails
    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
  }

  void _handleStatusChange(String newStatus, Map<String, dynamic> reqData) {
    if (_previousStatus != null && _previousStatus != newStatus) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        NotificationService.addTripNotification(uid: uid, status: newStatus,
          providerName: reqData['providerName'] ?? 'Provider',
          serviceType: reqData['serviceType'] ?? 'service', requestId: widget.requestId);
      }
    }
    _previousStatus = newStatus;
  }

  bool _isAtLeast(String current, String target, List<String> order) => order.indexOf(current.toLowerCase()) >= order.indexOf(target.toLowerCase());

  double _getProgressValue(String status, bool isTowing) {
    final order = isTowing ? _towingOrder : _fuelOrder;
    final idx = order.indexOf(status.toLowerCase());
    return idx < 0 ? 0.1 : (idx + 1) / order.length;
  }

  void _recenterUser(LatLng userLoc) async {
    final controller = await _controller.future;
    setState(() => _isAutoCameraEnabled = true);
    controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: userLoc, zoom: 16)));
  }

  void _updateCamera(LatLng userLoc, LatLng driverLoc) async {
    if (!_isAutoCameraEnabled) return;
    final controller = await _controller.future;
    final sw = LatLng(min(userLoc.latitude, driverLoc.latitude), min(userLoc.longitude, driverLoc.longitude));
    final ne = LatLng(max(userLoc.latitude, driverLoc.latitude), max(userLoc.longitude, driverLoc.longitude));
    controller.animateCamera(CameraUpdate.newLatLngBounds(LatLngBounds(southwest: sw, northeast: ne), 70));
  }

  void _showCancelDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(context: context, builder: (context) => AlertDialog(
      backgroundColor: AppTheme.getBg(isDark),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text("Cancel Request?", style: TextStyle(color: AppTheme.getTextPrimary(isDark), fontWeight: FontWeight.bold)),
      content: Text("Are you sure?", style: TextStyle(color: AppTheme.getTextPrimary(isDark).withValues(alpha: 0.7))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("NO, WAIT")),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
          onPressed: () async {
            await FirebaseFirestore.instance.collection('requests').doc(widget.requestId).update({'status': 'cancelled'});
            if (context.mounted) Navigator.of(context).popUntil((route) => route.isFirst);
          }, child: const Text("YES, CANCEL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
      ],
    ));
  }

  /// Map-based destination picker with search
  void _showDestinationPicker() {
    if (_dialogShown || _destinationSubmitted) return;
    _dialogShown = true;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    Navigator.push(context, MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _DestinationPickerScreen(
        isDark: isDark,
        loc: loc,
        onConfirm: (LatLng pos, String name) async {
          await FirebaseFirestore.instance.collection('requests').doc(widget.requestId).update({
            'destinationName': name, 'destinationLat': pos.latitude, 'destinationLng': pos.longitude,
            'destinationSetAt': FieldValue.serverTimestamp(),
          });
          setState(() => _destinationSubmitted = true);
        },
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = AppTheme.getTextPrimary(isDark);
    final dimColor = AppTheme.getTextDim(isDark);

    return PopScope(canPop: false, child: Scaffold(
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('requests').doc(widget.requestId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Scaffold(
              appBar: AppBar(title: const Text("Tracking", style: TextStyle(fontWeight: FontWeight.w900)),
                automaticallyImplyLeading: false),
              body: const Center(child: CircularProgressIndicator()),
            );
          }
          final reqData = snapshot.data!.data() as Map<String, dynamic>;
          final status = (reqData['status'] ?? 'requested').toString().toLowerCase();
          final providerId = reqData['providerId'] as String?;
          final isTowing = reqData['serviceType'] == 'towing';
          final isFuel = reqData['serviceType'] == 'fuel';
          final isAccident = reqData['serviceType'] == 'accident';
          final userLoc = LatLng((reqData['lat'] as num).toDouble(), (reqData['lng'] as num).toDouble());
          final order = isTowing ? _towingOrder : isAccident ? _accidentOrder : _fuelOrder;

          // Check if payment is pending (completed but not paid)
          final String paymentStatus = (reqData['paymentStatus'] ?? '').toString();
          final bool isPaymentPending = status == 'completed' && paymentStatus != 'paid';
          final bool isAwaitingProvider = status == 'completed' && paymentStatus == 'awaiting_provider';

          _handleStatusChange(status, reqData);

          if (status == 'completed') {
            if (isAwaitingProvider) {
              // User selected cash/card — waiting for provider to confirm receipt
              return Column(children: [
                AppBar(title: const Text("Awaiting Confirmation", style: TextStyle(fontWeight: FontWeight.w900)),
                  automaticallyImplyLeading: false),
                Expanded(child: _buildAwaitingProviderView(reqData, isDark, textColor, dimColor)),
              ]);
            }
            if (isPaymentPending) {
              // Payment pending — show payment screen WITHOUT home button
              return Column(children: [
                AppBar(title: const Text("Payment Required", style: TextStyle(fontWeight: FontWeight.w900)),
                  automaticallyImplyLeading: false),
                Expanded(child: PaymentScreen(requestId: widget.requestId, reqData: reqData, onPaymentComplete: () => setState(() {}))),
              ]);
            }
            // Payment done — show rating view (home allowed)
            return Column(children: [
              AppBar(title: const Text("Rate Service", style: TextStyle(fontWeight: FontWeight.w900)),
                automaticallyImplyLeading: false,
                actions: [IconButton(icon: const Icon(Icons.home_rounded, color: AppTheme.accent),
                  onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst))]),
              Expanded(child: _buildRatingView(reqData)),
            ]);
          }
          if (status == 'cancelled') {
            WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.of(context).popUntil((route) => route.isFirst));
            return const Center(child: CircularProgressIndicator());
          }

          // Trigger destination picker
          if (isTowing && status == 'towing' && !_destinationSubmitted && reqData['destinationLat'] == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _showDestinationPicker());
          }
          if (reqData['destinationLat'] != null) _destinationSubmitted = true;

          return Column(children: [
            // AppBar for active tracking — home allowed
            AppBar(title: const Text("Tracking", style: TextStyle(fontWeight: FontWeight.w900)),
              automaticallyImplyLeading: false,
              actions: [IconButton(icon: const Icon(Icons.home_rounded, color: AppTheme.accent),
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst))]),
            // Map
            Expanded(flex: 3, child: Stack(children: [
              StreamBuilder<DocumentSnapshot>(
                stream: providerId != null ? FirebaseFirestore.instance.collection('providers').doc(providerId).snapshots() : null,
                builder: (context, pSnap) {
                  Set<Marker> markers = {
                    Marker(markerId: const MarkerId("user"), position: userLoc,
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                      infoWindow: const InfoWindow(title: "Your Location")),
                  };
                  if (reqData['destinationLat'] != null) {
                    markers.add(Marker(markerId: const MarkerId("destination"),
                      position: LatLng(reqData['destinationLat'], reqData['destinationLng']),
                      icon: _destIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                      infoWindow: InfoWindow(title: reqData['destinationName'] ?? "Destination")));
                  }
                  if (pSnap.hasData && pSnap.data!.exists) {
                    final pData = pSnap.data!.data() as Map<String, dynamic>;
                    final driverLoc = LatLng((pData['currentLat'] as num).toDouble(), (pData['currentLng'] as num).toDouble());
                    markers.add(Marker(markerId: const MarkerId("driver"), position: driverLoc,
                      icon: _truckIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                      infoWindow: InfoWindow(title: reqData['providerName'] ?? "Carrier")));
                    _updateCamera(userLoc, driverLoc);
                  }
                  return GoogleMap(
                    initialCameraPosition: CameraPosition(target: userLoc, zoom: 15),
                    markers: markers, onMapCreated: (c) { if (!_controller.isCompleted) _controller.complete(c); },
                    myLocationButtonEnabled: false, zoomControlsEnabled: false,
                    onCameraMoveStarted: () { if (_isAutoCameraEnabled) setState(() => _isAutoCameraEnabled = false); });
                },
              ),
              Positioned(bottom: 16, right: 16, child: FloatingActionButton.small(
                backgroundColor: AppTheme.getBg(isDark).withValues(alpha: 0.9),
                onPressed: () => _recenterUser(userLoc),
                child: Icon(Icons.my_location_rounded, color: _isAutoCameraEnabled ? AppTheme.accent : textColor))),
            ])),

            // Status panel
            Expanded(flex: 4, child: ListView(padding: const EdgeInsets.all(16), children: [
              GlassCard(child: Column(children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text(status.toUpperCase().replaceAll('_', ' '), style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w900, fontSize: 12))),
                const SizedBox(height: 12),
                if (providerId != null) Row(children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.accent,
                    backgroundImage: reqData['providerPic'] != null && reqData['providerPic'].toString().isNotEmpty
                        ? NetworkImage(reqData['providerPic'])
                        : null,
                    child: reqData['providerPic'] != null && reqData['providerPic'].toString().isNotEmpty
                        ? null
                        : const Icon(Icons.person, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(reqData['providerName'] ?? "Carrier", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                    Text(isFuel ? "Fuel delivery" : isAccident ? "Assistance active" : "Carrier active", style: TextStyle(color: dimColor, fontSize: 12)),
                  ])),
                  IconButton.filled(
                    onPressed: () => launchUrl(Uri.parse("tel:${reqData['providerPhone']}")),
                    icon: const Icon(Icons.phone, color: Colors.white),
                    style: IconButton.styleFrom(backgroundColor: AppTheme.accent)),
                ]),
                const SizedBox(height: 16),
                ClipRRect(borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(value: _getProgressValue(status, isTowing), backgroundColor: AppTheme.getStroke(isDark), color: AppTheme.accent, minHeight: 6)),
                if (isTowing && _destinationSubmitted && reqData['destinationName'] != null) ...[
                  const SizedBox(height: 12),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.3))),
                    child: Row(children: [
                      const Icon(Icons.location_on, color: Colors.green, size: 16), const SizedBox(width: 8),
                      Expanded(child: Text("Delivering to: ${reqData['destinationName']}",
                        style: const TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.w600))),
                    ])),
                ],
              ])),
              const SizedBox(height: 20),
              ...order.map((step) => _StatusItem(active: _isAtLeast(status, step, order),
                title: _getStepTitle(step, isTowing, isAccident, loc),
                sub: _getStepSub(step, isTowing, isAccident, reqData['destinationName'], loc),
                isLast: step == order.last, isDark: isDark)),
              if (status == 'requested') Padding(padding: const EdgeInsets.only(top: 32, bottom: 16),
                child: Center(child: TextButton.icon(onPressed: _showCancelDialog,
                  icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
                  label: const Text("CANCEL REQUEST", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))))),
            ])),
          ]);
        },
      ),
    ));
  }

  String _getStepTitle(String step, bool isTowing, bool isAccident, AppLocalizations loc) {
    switch (step) {
      case 'requested':   return loc.tr('findingHelp');
      case 'accepted':    return loc.tr('carrierAssigned');
      case 'en_route':    return loc.tr('enRoute');
      case 'arrived':     return loc.tr('arrived');
      case 'towing':      return loc.tr('towingTrip');
      case 'in_progress': return isAccident ? "Recovery Underway" : "In Progress";
      case 'completed':   return loc.tr('completed');
      default: return "";
    }
  }

  String _getStepSub(String step, bool isTowing, bool isAccident, String? dest, AppLocalizations loc) {
    switch (step) {
      case 'requested':   return "Connecting to network";
      case 'accepted':    return "Request accepted";
      case 'en_route':    return "On the way to you";
      case 'arrived':     return "At your location";
      case 'towing':      return "Towing to ${dest ?? 'destination'}";
      case 'in_progress': return isAccident ? "Accident recovery in progress" : "Work in progress";
      case 'completed':   return "Service complete";
      default: return "";
    }
  }

  Widget _buildAwaitingProviderView(Map<String, dynamic> reqData, bool isDark, Color textColor, Color dimColor) {
    final method = (reqData['paymentMethod'] ?? 'cash').toString();
    final amount = (reqData['totalPaid'] as num?)?.toStringAsFixed(0) ?? (reqData['price'] as num?)?.toStringAsFixed(0) ?? '0';
    return Container(
      color: AppTheme.getBg(isDark), padding: const EdgeInsets.all(24),
      child: Center(child: GlassCard(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 12),
        Container(padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.orange.withValues(alpha: 0.1)),
          child: const Icon(Icons.hourglass_top_rounded, color: Colors.orange, size: 52)),
        const SizedBox(height: 20),
        Text("Waiting for Provider", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textColor)),
        const SizedBox(height: 8),
        Text(
          method == 'card'
            ? "The garage is processing your card payment on their machine."
            : "Hand over cash to the provider. They will confirm receipt.",
          textAlign: TextAlign.center,
          style: TextStyle(color: dimColor, fontSize: 14)),
        const SizedBox(height: 24),
        Container(padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2))),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Amount", style: TextStyle(color: dimColor, fontSize: 12)),
              Text("LKR $amount", style: const TextStyle(color: AppTheme.accent, fontSize: 24, fontWeight: FontWeight.w900)),
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text("Method", style: TextStyle(color: dimColor, fontSize: 12)),
              Text(method.toUpperCase(), style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
            ]),
          ])),
        const SizedBox(height: 24),
        const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.orange, strokeWidth: 2)),
        const SizedBox(height: 12),
        Text("This will update automatically once confirmed", style: TextStyle(color: dimColor, fontSize: 11)),
      ]))),
    );
  }

  Widget _buildRatingView(Map<String, dynamic> reqData) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: AppTheme.getBg(isDark), padding: const EdgeInsets.all(24),
      child: Center(child: GlassCard(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.check_circle_rounded, color: Colors.green, size: 60),
        const SizedBox(height: 12),
        Text("Job Completed!", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.getTextPrimary(isDark))),
        if (reqData['price'] != null) ...[const SizedBox(height: 8),
          Text("LKR ${(reqData['price'] as num).toStringAsFixed(0)}", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppTheme.accent))],
        Divider(height: 40, color: isDark ? Colors.white10 : Colors.grey.shade200),
        CircleAvatar(
          radius: 40,
          backgroundColor: AppTheme.accent.withValues(alpha: 0.2),
          backgroundImage: reqData['providerPic'] != null && reqData['providerPic'].toString().isNotEmpty
              ? NetworkImage(reqData['providerPic'])
              : null,
          child: reqData['providerPic'] != null && reqData['providerPic'].toString().isNotEmpty
              ? null
              : const Icon(Icons.person, color: AppTheme.accent, size: 40),
        ),
        const SizedBox(height: 12),
        Text(reqData['providerName'] ?? "Carrier", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.getTextPrimary(isDark))),
        const SizedBox(height: 30),
        Text("How was your experience?", style: TextStyle(color: AppTheme.getTextPrimary(isDark).withValues(alpha: 0.7), fontSize: 15)),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) => IconButton(
          icon: Icon(i < _userRating ? Icons.star_rounded : Icons.star_outline_rounded, color: AppTheme.accent, size: 38),
          onPressed: () => setState(() => _userRating = i + 1)))),
        const SizedBox(height: 32),
        SizedBox(width: double.infinity, child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: () async {
            if (_userRating == 0) return;
            await FirebaseFirestore.instance.collection('requests').doc(widget.requestId).update({'rating': _userRating.toDouble(), 'ratingStatus': 'submitted'});
            if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
          },
          child: const Text("SUBMIT & CONTINUE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
      ]))),
    );
  }
}

// ─── Destination Picker (Map + Search) ───
class _DestinationPickerScreen extends StatefulWidget {
  final bool isDark;
  final AppLocalizations loc;
  final Future<void> Function(LatLng, String) onConfirm;
  const _DestinationPickerScreen({required this.isDark, required this.loc, required this.onConfirm});
  @override
  State<_DestinationPickerScreen> createState() => _DestinationPickerScreenState();
}

class _DestinationPickerScreenState extends State<_DestinationPickerScreen> {
  final _searchCtrl = TextEditingController();
  LatLng? _selectedPos;
  String _selectedName = "";
  bool _isLoading = false;
  bool _isLocating = true;
  GoogleMapController? _mapCtrl;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position pos = await Geolocator.getCurrentPosition();
      setState(() {
        _selectedPos = LatLng(pos.latitude, pos.longitude);
        _isLocating = false;
      });
      _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(_selectedPos!, 15));
    } catch (_) {
      setState(() => _isLocating = false);
    }
  }

  Future<void> _searchLocation() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final locs = await locationFromAddress(query);
      if (locs.isNotEmpty) {
        final pos = LatLng(locs.first.latitude, locs.first.longitude);
        setState(() { _selectedPos = pos; _selectedName = query; });
        _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(pos, 15));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Location not found. Try again.")));
    }
    setState(() => _isLoading = false);
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    try {
      final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        setState(() => _selectedName = [p.locality, p.subAdministrativeArea, p.administrativeArea].where((s) => s != null && s.isNotEmpty).join(', '));
      }
    } catch (_) {
      setState(() => _selectedName = "${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = AppTheme.getTextPrimary(isDark);
    final defaultPos = _selectedPos ?? const LatLng(0, 0);

    return Scaffold(
      appBar: AppBar(title: Text(widget.loc.tr('pickDestination'), style: const TextStyle(fontWeight: FontWeight.w900))),
      body: Stack(children: [
        if (_isLocating)
          const Center(child: CircularProgressIndicator(color: AppTheme.accent))
        else
          GoogleMap(
            initialCameraPosition: CameraPosition(target: defaultPos, zoom: 15),
            onMapCreated: (c) => _mapCtrl = c,
            onTap: (pos) { setState(() => _selectedPos = pos); _reverseGeocode(pos); },
            markers: _selectedPos != null ? {Marker(markerId: const MarkerId("dest"), position: _selectedPos!, draggable: true,
              onDragEnd: (pos) { setState(() => _selectedPos = pos); _reverseGeocode(pos); })} : {},
          ),
        // Search bar
        Positioned(top: 10, left: 16, right: 16, child: Container(
          decoration: BoxDecoration(color: AppTheme.getCard(isDark), borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)]),
          child: Row(children: [
            Expanded(child: TextField(controller: _searchCtrl,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(hintText: widget.loc.tr('searchLocation'), border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                prefixIcon: const Icon(Icons.search, color: AppTheme.accent)))),
            _isLoading
              ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
              : IconButton(icon: const Icon(Icons.send_rounded, color: AppTheme.accent), onPressed: _searchLocation),
          ]),
        )),
        // Selected location + confirm
        Positioned(bottom: 0, left: 0, right: 0, child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppTheme.getCard(isDark),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)]),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (_selectedName.isNotEmpty) ...[
              Row(children: [
                const Icon(Icons.location_on, color: AppTheme.accent, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(_selectedName, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15))),
              ]),
              const SizedBox(height: 16),
            ],
            SizedBox(width: double.infinity, child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              onPressed: (_selectedName.isEmpty || _selectedPos == null) ? null : () async {
                await widget.onConfirm(_selectedPos!, _selectedName);
                if (mounted) Navigator.pop(context);
              },
              child: Text(widget.loc.tr('confirmDestination'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            )),
          ]),
        )),
      ]),
    );
  }
}

class _StatusItem extends StatelessWidget {
  final bool active, isLast, isDark;
  final String title, sub;
  const _StatusItem({required this.active, required this.title, required this.sub, this.isLast = false, required this.isDark});
  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(child: Row(children: [
      Column(children: [
        Icon(active ? Icons.check_circle : Icons.circle_outlined, color: active ? AppTheme.accent : AppTheme.getTextDim(isDark), size: 24),
        if (!isLast) Expanded(child: Container(width: 2, color: active ? AppTheme.accent : AppTheme.getStroke(isDark))),
      ]),
      const SizedBox(width: 16),
      Expanded(child: Padding(padding: const EdgeInsets.only(bottom: 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: active ? AppTheme.getTextPrimary(isDark) : AppTheme.getTextDim(isDark), fontSize: 15)),
        Text(sub, style: TextStyle(fontSize: 13, color: active ? AppTheme.getTextPrimary(isDark).withValues(alpha: 0.7) : AppTheme.getTextDim(isDark).withValues(alpha: 0.5))),
      ]))),
    ]));
  }
}