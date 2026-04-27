import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart'; // 👈 Make sure to run: flutter pub add geocoding

import '../../models/demo_models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/primary_button.dart';
import '../tracking/live_tracking_screen.dart';

class RequestVehicle {
  final String name;
  final String plate;
  final String meta;
  final String source;

  const RequestVehicle({
    required this.name,
    required this.plate,
    required this.meta,
    required this.source,
  });

  Map<String, dynamic> toMap() => {
    "name": name,
    "plate": plate,
    "meta": meta,
    "vehicleSource": source,
  };
}

class RequestFlowScreen extends StatefulWidget {
  const RequestFlowScreen({super.key});

  @override
  State<RequestFlowScreen> createState() => _RequestFlowScreenState();
}

class _RequestFlowScreenState extends State<RequestFlowScreen> {
  int step = 0;
  ServiceType? selectedService = ServiceType.battery;
  String? selectedVehicleId;
  bool useTemporaryVehicle = false;
  RequestVehicle? selectedVehicle;

  final tempVehicleName = TextEditingController();
  final tempVehiclePlate = TextEditingController();
  final tempVehicleMeta = TextEditingController();
  final details = TextEditingController();

  // 📍 Real-time Location Data
  String location = "Fetching GPS location...";
  double? latitude;
  double? longitude;

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  // 📡 UPDATED: Now fetches real address names
  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => location = "GPS is disabled on device");
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => location = "Location permission denied");
        return;
      }
    }

    try {
      // 1. Get raw coordinates
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high
      );

      // 2. Convert coordinates to human-readable address
      List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude
      );

      String readableAddress = "Unknown Location";
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        // Formatting the address (Street, City)
        readableAddress = "${place.street}, ${place.locality}";
      }

      setState(() {
        latitude = position.latitude;
        longitude = position.longitude;
        location = readableAddress; // 👈 Real name instead of "GPS Detected"
      });
    } catch (e) {
      setState(() => location = "Error fetching address");
    }
  }

  @override
  void dispose() {
    details.dispose();
    tempVehicleName.dispose();
    tempVehiclePlate.dispose();
    tempVehicleMeta.dispose();
    super.dispose();
  }

  User get _user {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) throw Exception("Not logged in");
    return u;
  }

  Future<String> _resolveUserName() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return "User";
    final dn = (u.displayName ?? "").trim();
    if (dn.isNotEmpty) return dn;
    try {
      final doc = await FirebaseFirestore.instance.collection("users").doc(u.uid).get();
      final fullName = (doc.data()?["fullName"] ?? "").toString().trim();
      if (fullName.isNotEmpty) return fullName;
    } catch (_) {}
    return "User";
  }

  void _emitTemporaryVehicle() {
    final name = tempVehicleName.text.trim();
    final plate = tempVehiclePlate.text.trim().toUpperCase();
    if (name.isEmpty || plate.isEmpty) {
      setState(() {
        selectedVehicle = null;
        selectedVehicleId = null;
      });
      return;
    }
    setState(() {
      selectedVehicle = RequestVehicle(
        name: name,
        plate: plate,
        meta: tempVehicleMeta.text.trim(),
        source: "temporary",
      );
      selectedVehicleId = null;
    });
  }

  Future<void> _submitRequestAndGoTracking() async {
    final uid = _user.uid;
    final uName = await _resolveUserName();

    final data = <String, dynamic>{
      "userId": uid,
      "userName": uName,
      "serviceType": selectedService!.name,
      "vehicle": selectedVehicle!.toMap(),
      "locationText": location,
      "lat": latitude,
      "lng": longitude,
      "status": "requested",
      "createdAt": FieldValue.serverTimestamp(),
      "providerName": "",
      "providerPhone": "",
    };

    final trimmedDetails = details.text.trim();
    if (trimmedDetails.isNotEmpty) {
      data["details"] = trimmedDetails;
    }

    final docRef = await FirebaseFirestore.instance.collection("requests").add(data);

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => LiveTrackingScreen(
          requestId: docRef.id,
          serviceName: serviceTitle(selectedService!),
          vehicleName: "${selectedVehicle!.name} (${selectedVehicle!.plate})",
          location: location,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canContinueStep2 = selectedVehicle != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Request Assistance", style: TextStyle(fontWeight: FontWeight.w900)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (step == 0) Navigator.pop(context);
            else setState(() => step--);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _StepBar(step: step),
            const SizedBox(height: 18),
            Expanded(
              child: switch (step) {
                0 => _Step1(
                  selected: selectedService!,
                  onSelect: (s) => setState(() => selectedService = s),
                ),
                1 => _Step2(
                  selectedVehicleId: selectedVehicleId,
                  onSelectSavedVehicle: (id, v) => setState(() {
                    selectedVehicleId = id;
                    selectedVehicle = v;
                    useTemporaryVehicle = false;
                  }),
                  useTemporary: useTemporaryVehicle,
                  onToggleTemporary: () => setState(() {
                    useTemporaryVehicle = !useTemporaryVehicle;
                    if (useTemporaryVehicle) {
                      selectedVehicleId = null;
                      selectedVehicle = null;
                    } else {
                      tempVehicleName.clear();
                      tempVehiclePlate.clear();
                      tempVehicleMeta.clear();
                      selectedVehicle = null;
                    }
                  }),
                  tempName: tempVehicleName,
                  tempPlate: tempVehiclePlate,
                  tempMeta: tempVehicleMeta,
                  onTempChanged: _emitTemporaryVehicle,
                  location: location,
                  onChangeLocation: _determinePosition,
                ),
                _ => _Step3(
                  service: selectedService!,
                  vehicle: selectedVehicle!,
                  location: location,
                  details: details,
                ),
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    text: step == 2 ? "Request Help" : "Continue",
                    onPressed: () async {
                      if (step == 1 && !canContinueStep2) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Please select a vehicle.")),
                        );
                        return;
                      }
                      if (step < 2) {
                        setState(() => step++);
                        return;
                      }
                      try {
                        await _submitRequestAndGoTracking();
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Failed: $e")),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --- UI WIDGETS ---

class _StepBar extends StatelessWidget {
  final int step;
  const _StepBar({required this.step});

  @override
  Widget build(BuildContext context) {
    Widget bar(bool active) => Expanded(
      child: Container(
        height: 6,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: active ? AppTheme.accent : AppTheme.stroke,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );

    return Row(
      children: [
        bar(step >= 0),
        bar(step >= 1),
        bar(step >= 2),
      ],
    );
  }
}

class _Step1 extends StatelessWidget {
  final ServiceType selected;
  final ValueChanged<ServiceType> onSelect;
  const _Step1({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final items = ServiceType.values;
    return ListView(
      children: [
        const Text("What's the issue?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        const Text("Select the assistance you need", style: TextStyle(color: AppTheme.textDim)),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.35,
          ),
          itemBuilder: (_, i) {
            final s = items[i];
            final isSel = s == selected;
            return GlassCard(
              onTap: () => onSelect(s),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.miscellaneous_services_rounded, color: isSel ? AppTheme.accent : Colors.white),
                      const Spacer(),
                      if (isSel) const Icon(Icons.check_circle_rounded, color: AppTheme.accent),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(serviceTitle(s), style: const TextStyle(fontWeight: FontWeight.w900)),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _Step2 extends StatelessWidget {
  final String? selectedVehicleId;
  final void Function(String id, RequestVehicle v) onSelectSavedVehicle;
  final bool useTemporary;
  final VoidCallback onToggleTemporary;
  final TextEditingController tempName;
  final TextEditingController tempPlate;
  final TextEditingController tempMeta;
  final VoidCallback onTempChanged;
  final String location;
  final VoidCallback onChangeLocation;

  const _Step2({
    required this.selectedVehicleId,
    required this.onSelectSavedVehicle,
    required this.useTemporary,
    required this.onToggleTemporary,
    required this.tempName,
    required this.tempPlate,
    required this.tempMeta,
    required this.onTempChanged,
    required this.location,
    required this.onChangeLocation,
  });

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final vehiclesRef = FirebaseFirestore.instance.collection('users').doc(uid).collection('vehicles');

    return ListView(
      children: [
        const Text("Vehicle & Location", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        Row(
          children: [
            const Expanded(child: Text("Select Vehicle", style: TextStyle(fontWeight: FontWeight.w800))),
            TextButton(
              onPressed: onToggleTemporary,
              child: Text(useTemporary ? "Use saved" : "Use another", style: const TextStyle(color: AppTheme.accent)),
            ),
          ],
        ),
        if (!useTemporary)
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: vehiclesRef.snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snap.data!.docs;
              return Column(
                children: [
                  for (final d in docs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GlassCard(
                        onTap: () => onSelectSavedVehicle(d.id, RequestVehicle(
                          name: d.data()["name"] ?? "",
                          plate: d.data()["plate"] ?? "",
                          meta: d.data()["meta"] ?? "",
                          source: "saved",
                        )),
                        child: Row(
                          children: [
                            const Icon(Icons.directions_car_rounded, color: AppTheme.accent),
                            const SizedBox(width: 10),
                            Expanded(child: Text(d.data()["name"] ?? "", style: const TextStyle(fontWeight: FontWeight.w900))),
                            if (d.id == selectedVehicleId) const Icon(Icons.check_circle_rounded, color: AppTheme.accent),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          )
        else
          Column(
            children: [
              TextField(controller: tempName, onChanged: (_) => onTempChanged(), decoration: const InputDecoration(hintText: "Vehicle Name")),
              const SizedBox(height: 10),
              TextField(controller: tempPlate, onChanged: (_) => onTempChanged(), decoration: const InputDecoration(hintText: "Plate Number")),
            ],
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Text("Location", style: TextStyle(fontWeight: FontWeight.w800)),
            const Spacer(),
            IconButton(onPressed: onChangeLocation, icon: const Icon(Icons.my_location, color: AppTheme.accent, size: 20))
          ],
        ),
        GlassCard(child: Text(location, style: const TextStyle(fontWeight: FontWeight.w900))),
      ],
    );
  }
}

class _Step3 extends StatelessWidget {
  final ServiceType service;
  final RequestVehicle vehicle;
  final String location;
  final TextEditingController details;

  const _Step3({required this.service, required this.vehicle, required this.location, required this.details});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const Text("Summary & Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        GlassCard(
          child: Column(
            children: [
              _RowKV(k: "Service", v: serviceTitle(service)),
              _RowKV(k: "Vehicle", v: "${vehicle.name} (${vehicle.plate})"),
              _RowKV(k: "Location", v: location),
            ],
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: details,
          maxLines: 3,
          decoration: const InputDecoration(hintText: "Describe the issue (optional)"),
        ),
      ],
    );
  }
}

class _RowKV extends StatelessWidget {
  final String k;
  final String v;
  const _RowKV({required this.k, required this.v});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [Expanded(child: Text(k)), Text(v, style: const TextStyle(fontWeight: FontWeight.bold))]),
    );
  }
}