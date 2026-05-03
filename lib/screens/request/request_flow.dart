import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../../models/demo_models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/primary_button.dart';
import '../tracking/live_tracking_dispatcher.dart'; // Updated Import

class RequestVehicle {
  final String name, plate, meta, source;
  const RequestVehicle({required this.name, required this.plate, required this.meta, required this.source});
  Map<String, dynamic> toMap() => {"name": name, "plate": plate, "meta": meta, "vehicleSource": source};
}

class RequestFlowScreen extends StatefulWidget {
  const RequestFlowScreen({super.key});
  @override
  State<RequestFlowScreen> createState() => _RequestFlowScreenState();
}

class _RequestFlowScreenState extends State<RequestFlowScreen> {
  int step = 0;
  String selectedMode = "carrier"; // Step 0: Carrier or Garage
  ServiceType? selectedService = ServiceType.battery; // Step 1
  String? selectedVehicleId; // Step 2
  bool useTemporaryVehicle = false;
  RequestVehicle? selectedVehicle;

  final tempName = TextEditingController(), tempPlate = TextEditingController(), tempMeta = TextEditingController(), details = TextEditingController();
  String location = "Fetching GPS location...";
  double? latitude, longitude;

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) { setState(() => location = "GPS disabled"); return; }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) { setState(() => location = "Permission denied"); return; }
    }
    try {
      Position pos = await Geolocator.getCurrentPosition();
      List<Placemark> p = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      setState(() {
        latitude = pos.latitude; longitude = pos.longitude;
        location = p.isNotEmpty ? "${p[0].street}, ${p[0].locality}" : "Unknown Location";
      });
    } catch (e) { setState(() => location = "Location Error"); }
  }

  @override
  void dispose() { details.dispose(); tempName.dispose(); tempPlate.dispose(); tempMeta.dispose(); super.dispose(); }

  Future<void> _submitRequest() async {
    final u = FirebaseAuth.instance.currentUser!;
    final doc = await FirebaseFirestore.instance.collection("users").doc(u.uid).get();
    final uName = doc.data()?["fullName"] ?? u.displayName ?? "User";
    final uPhone = doc.data()?["phone"] ?? "";

    final data = {
      "userId": u.uid,
      "userName": uName,
      "userPhone": uPhone,
      "providerRole": selectedMode, // Saved from Step 0
      "serviceType": selectedService!.name,
      "vehicle": selectedVehicle!.toMap(),
      "locationText": location,
      "lat": latitude,
      "lng": longitude,
      "status": "requested",
      "createdAt": FieldValue.serverTimestamp(),
      "providerName": "",
      "providerPhone": "",
      "rating": 0.0,
      "review": "",
      "ratingStatus": "none",
    };

    if (details.text.trim().isNotEmpty) data["details"] = details.text.trim();

    final docRef = await FirebaseFirestore.instance.collection("requests").add(data);

    if (!mounted) return;
    // Navigate to Dispatcher to handle the role logic automatically
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => TrackingDispatcher(
      requestId: docRef.id,
    )));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Request Assistance", style: TextStyle(fontWeight: FontWeight.w900)),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => step == 0 ? Navigator.pop(context) : setState(() => step--)
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _StepBar(step: step), // Updated to show progress through 4 steps
            const SizedBox(height: 18),
            Expanded(
              child: switch (step) {
                0 => _Step0Mode(
                    selected: selectedMode,
                    onSelect: (m) => setState(() => selectedMode = m)
                ),
                1 => _Step1(
                    selected: selectedService!,
                    onSelect: (s) => setState(() => selectedService = s)
                ),
                2 => _Step2(
                  selectedVehicleId: selectedVehicleId,
                  onSelect: (id, v) => setState(() { selectedVehicleId = id; selectedVehicle = v; useTemporaryVehicle = false; }),
                  useTemporary: useTemporaryVehicle,
                  onToggle: () => setState(() { useTemporaryVehicle = !useTemporaryVehicle; selectedVehicle = null; selectedVehicleId = null; }),
                  tempName: tempName, tempPlate: tempPlate, tempMeta: tempMeta,
                  onTempChanged: () => setState(() => selectedVehicle = RequestVehicle(name: tempName.text, plate: tempPlate.text.toUpperCase(), meta: tempMeta.text, source: "temporary")),
                  location: location, onRefreshLoc: _determinePosition,
                ),
                _ => _Step3(
                    service: selectedService!,
                    vehicle: selectedVehicle!,
                    location: location,
                    details: details
                ),
              },
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              text: step == 3 ? "Request Help" : "Continue",
              onPressed: () async {
                if (step == 2 && selectedVehicle == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a vehicle.")));
                  return;
                }
                step < 3 ? setState(() => step++) : await _submitRequest();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// --- STEP WIDGETS ---

class _StepBar extends StatelessWidget {
  final int step;
  const _StepBar({required this.step});
  @override
  Widget build(BuildContext context) {
    return Row(children: List.generate(4, (i) => Expanded(child: Container(height: 6, margin: const EdgeInsets.symmetric(horizontal: 4), decoration: BoxDecoration(color: step >= i ? AppTheme.accent : AppTheme.stroke, borderRadius: BorderRadius.circular(10))))));
  }
}

class _Step0Mode extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  const _Step0Mode({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Choose Service Type", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 20),
        _ModeCard(
          title: "Carrier Service",
          sub: "A recovery truck or mobile mechanic comes to you.",
          icon: Icons.local_shipping_rounded,
          isSelected: selected == "carrier",
          onTap: () => onSelect("carrier"),
        ),
        const SizedBox(height: 15),
        _ModeCard(
          title: "Garage Service",
          sub: "Drive your vehicle to a nearby partner workshop.",
          icon: Icons.store_rounded,
          isSelected: selected == "garage",
          onTap: () => onSelect("garage"),
        ),
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String title, sub;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  const _ModeCard({required this.title, required this.sub, required this.icon, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: isSelected ? Border.all(color: AppTheme.accent, width: 2) : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 36, color: isSelected ? AppTheme.accent : Colors.white54),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(sub, style: const TextStyle(color: AppTheme.textDim, fontSize: 12)),
                ],
              ),
            ),
            if (isSelected) const Icon(Icons.check_circle, color: AppTheme.accent),
          ],
        ),
      ),
    );
  }
}

class _Step1 extends StatelessWidget {
  final ServiceType selected;
  final ValueChanged<ServiceType> onSelect;
  const _Step1({required this.selected, required this.onSelect});
  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      const Text("What's the issue?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      const SizedBox(height: 14),
      GridView.builder(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: ServiceType.values.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.3),
        itemBuilder: (_, i) {
          final s = ServiceType.values[i];
          final isSel = s == selected;
          return GlassCard(onTap: () => onSelect(s), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(Icons.miscellaneous_services_rounded, color: isSel ? AppTheme.accent : Colors.white), const Spacer(), if (isSel) const Icon(Icons.check_circle_rounded, color: AppTheme.accent)]),
            const SizedBox(height: 12), Text(serviceTitle(s), style: const TextStyle(fontWeight: FontWeight.w900)),
          ]));
        },
      ),
    ]);
  }
}

class _Step2 extends StatelessWidget {
  final String? selectedVehicleId;
  final void Function(String id, RequestVehicle v) onSelect;
  final bool useTemporary;
  final VoidCallback onToggle, onRefreshLoc, onTempChanged;
  final TextEditingController tempName, tempPlate, tempMeta;
  final String location;

  const _Step2({required this.selectedVehicleId, required this.onSelect, required this.useTemporary, required this.onToggle, required this.tempName, required this.tempPlate, required this.tempMeta, required this.onRefreshLoc, required this.onTempChanged, required this.location});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final vehiclesRef = FirebaseFirestore.instance.collection('users').doc(uid).collection('vehicles');

    return ListView(children: [
      Row(children: [const Expanded(child: Text("Select Vehicle", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))), TextButton(onPressed: onToggle, child: Text(useTemporary ? "Use saved" : "Use another", style: const TextStyle(color: AppTheme.accent)))]),
      if (!useTemporary) StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: vehiclesRef.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const LinearProgressIndicator();
          final docs = snap.data!.docs;

          if (selectedVehicleId == null && docs.isNotEmpty) {
            var def = docs.first;
            for (var d in docs) {
              if (d.data()['isDefault'] == true) {
                def = d;
                break;
              }
            }
            WidgetsBinding.instance.addPostFrameCallback((_) => onSelect(
                def.id,
                RequestVehicle(name: def.data()["name"] ?? "", plate: def.data()["plate"] ?? "", meta: def.data()["meta"] ?? "", source: "saved")
            ));
          }

          return Column(children: docs.map((d) {
            final isSel = d.id == selectedVehicleId;
            return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                    onTap: () => onSelect(d.id, RequestVehicle(name: d.data()["name"] ?? "", plate: d.data()["plate"] ?? "", meta: d.data()["meta"] ?? "", source: "saved")),
                    child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        child: Row(children: [
                          Icon(Icons.directions_car_rounded, color: isSel ? Colors.white : Colors.white54),
                          const SizedBox(width: 12),
                          Expanded(child: Text(d.data()["name"] ?? "", style: TextStyle(fontWeight: FontWeight.w900, color: isSel ? Colors.white : Colors.white70))),
                          if (isSel) const Icon(Icons.check_circle_rounded, color: AppTheme.accent, size: 26)
                        ])
                    )
                )
            );
          }).toList());
        },
      ) else Column(children: [TextField(controller: tempName, onChanged: (_) => onTempChanged(), decoration: const InputDecoration(hintText: "Vehicle Name")), const SizedBox(height: 10), TextField(controller: tempPlate, onChanged: (_) => onTempChanged(), decoration: const InputDecoration(hintText: "Plate Number"))]),
      const SizedBox(height: 20),
      Row(children: [const Text("Location", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), const Spacer(), IconButton(onPressed: onRefreshLoc, icon: const Icon(Icons.my_location, color: AppTheme.accent))]),
      GlassCard(child: Text(location, style: const TextStyle(fontWeight: FontWeight.w900))),
    ]);
  }
}

class _Step3 extends StatelessWidget {
  final ServiceType service; final RequestVehicle vehicle; final String location; final TextEditingController details;
  const _Step3({required this.service, required this.vehicle, required this.location, required this.details});
  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      const Text("Summary", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      const SizedBox(height: 14),
      GlassCard(child: Column(children: [_RowKV(k: "Service", v: serviceTitle(service)), _RowKV(k: "Vehicle", v: "${vehicle.name} (${vehicle.plate})"), _RowKV(k: "Location", v: location)])),
      const SizedBox(height: 20),
      TextField(controller: details, maxLines: 3, decoration: const InputDecoration(hintText: "Issue details (optional)")),
    ]);
  }
}

class _RowKV extends StatelessWidget {
  final String k, v; const _RowKV({required this.k, required this.v});
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [Expanded(child: Text(k, style: const TextStyle(color: AppTheme.textDim))), Text(v, style: const TextStyle(fontWeight: FontWeight.bold))]));
  }
}