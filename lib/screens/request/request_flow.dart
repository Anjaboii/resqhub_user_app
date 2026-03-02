import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/demo_models.dart'; // ServiceType + serviceTitle/serviceSubtitle
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/primary_button.dart';
import '../tracking/live_tracking_screen.dart';

class RequestVehicle {
  final String name;
  final String plate;
  final String meta;
  final String source; // "saved" | "temporary"

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
    "vehicleSource": source, // ✅ store inside the vehicle map
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

  // Vehicle selection
  String? selectedVehicleId; // docId for saved vehicle
  bool useTemporaryVehicle = false;
  RequestVehicle? selectedVehicle;

  // Temporary vehicle inputs
  final tempVehicleName = TextEditingController();
  final tempVehiclePlate = TextEditingController();
  final tempVehicleMeta = TextEditingController();

  // Location + details
  String location = "Galle Road, Colombo 03";
  final details = TextEditingController();

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

  /// Best: Auth displayName -> Firestore users/{uid}.fullName -> email prefix -> "User"
  Future<String> _resolveUserName() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return "User";

    final dn = (u.displayName ?? "").trim();
    if (dn.isNotEmpty) return dn;

    try {
      final doc = await FirebaseFirestore.instance.collection("users").doc(u.uid).get();
      final fullName = (doc.data()?["fullName"] ?? "").toString().trim();
      if (fullName.isNotEmpty) return fullName;
    } catch (_) {
      // ignore and fallback
    }

    final email = (u.email ?? "").trim();
    if (email.contains("@")) return email.split("@").first;
    return "User";
  }

  /// Update selectedVehicle from temporary fields.
  /// If fields are empty, selectedVehicle becomes null (so user can't continue).
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
      "userName": uName, // ✅ add user name
      "serviceType": selectedService!.name, // enum name
      "vehicle": selectedVehicle!.toMap(),  // includes vehicleSource
      "locationText": location,
      "status": "requested",
      "createdAt": FieldValue.serverTimestamp(),
    };

    final trimmedDetails = details.text.trim();
    if (trimmedDetails.isNotEmpty) {
      data["details"] = trimmedDetails; // ✅ only save if not empty
    }

    await FirebaseFirestore.instance.collection("requests").add(data);

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => LiveTrackingScreen(
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
                      // switching to temporary: clear saved selection & wait for typing
                      selectedVehicleId = null;
                      selectedVehicle = null;
                    } else {
                      // switching back to saved: clear temp inputs & selection
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
                  onChangeLocation: () => setState(() => location = "Near Liberty Plaza"),
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
                          const SnackBar(content: Text("Please select a vehicle (saved or temporary).")),
                        );
                        return;
                      }

                      if (step < 2) {
                        setState(() => step++);
                        return;
                      }

                      // step == 2
                      try {
                        await _submitRequestAndGoTracking();
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Failed to create request: $e")),
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
        const Text("Select the type of assistance you need", style: TextStyle(color: AppTheme.textDim)),
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
                  const SizedBox(height: 4),
                  Text(serviceSubtitle(s), style: const TextStyle(color: AppTheme.textDim, fontSize: 12)),
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

    // If you don't have createdAt yet, remove orderBy line.
    final vehiclesRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('vehicles');

    return ListView(
      children: [
        const Text("Vehicle & Location", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        const Text("Confirm your vehicle and current location", style: TextStyle(color: AppTheme.textDim)),
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
        const SizedBox(height: 8),

        if (!useTemporary)
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: vehiclesRef.snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final docs = snap.data!.docs;
              if (docs.isEmpty) {
                return GlassCard(
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      "No saved vehicles yet.\nGo to Vehicles tab to add one, or tap 'Use another'.",
                      style: TextStyle(color: AppTheme.textDim),
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  for (final d in docs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GlassCard(
                        onTap: () {
                          final data = d.data();
                          onSelectSavedVehicle(
                            d.id,
                            RequestVehicle(
                              name: (data["name"] ?? "").toString(),
                              plate: (data["plate"] ?? "").toString(),
                              meta: (data["meta"] ?? "").toString(),
                              source: "saved",
                            ),
                          );
                        },
                        child: Row(
                          children: [
                            const Icon(Icons.directions_car_rounded, color: AppTheme.accent),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text((d.data()["name"] ?? "").toString(),
                                      style: const TextStyle(fontWeight: FontWeight.w900)),
                                  const SizedBox(height: 2),
                                  Text((d.data()["plate"] ?? "").toString(),
                                      style: const TextStyle(color: AppTheme.textDim)),
                                ],
                              ),
                            ),
                            if (d.id == selectedVehicleId)
                              const Icon(Icons.check_circle_rounded, color: AppTheme.accent),
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
              TextField(
                controller: tempName,
                onChanged: (_) => onTempChanged(),
                decoration: InputDecoration(
                  hintText: "Vehicle name (e.g. Toyota Corolla)",
                  hintStyle: const TextStyle(color: AppTheme.textDim),
                  filled: true,
                  fillColor: AppTheme.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppTheme.stroke),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppTheme.stroke),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: tempPlate,
                onChanged: (_) => onTempChanged(),
                decoration: InputDecoration(
                  hintText: "Plate number (e.g. CAB-1234)",
                  hintStyle: const TextStyle(color: AppTheme.textDim),
                  filled: true,
                  fillColor: AppTheme.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppTheme.stroke),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppTheme.stroke),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: tempMeta,
                onChanged: (_) => onTempChanged(),
                decoration: InputDecoration(
                  hintText: "Notes (optional)",
                  hintStyle: const TextStyle(color: AppTheme.textDim),
                  filled: true,
                  fillColor: AppTheme.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppTheme.stroke),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppTheme.stroke),
                  ),
                ),
              ),
            ],
          ),

        const SizedBox(height: 16),
        const Text("Your Location", style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        GlassCard(
          child: Row(
            children: [
              const Icon(Icons.location_on_rounded, color: AppTheme.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(location, style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    const Text("Near Liberty Plaza", style: TextStyle(color: AppTheme.textDim, fontSize: 12)),
                  ],
                ),
              ),
              TextButton(
                onPressed: onChangeLocation,
                child: const Text("Change", style: TextStyle(color: AppTheme.accent)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Step3 extends StatelessWidget {
  final ServiceType service;
  final RequestVehicle vehicle;
  final String location;
  final TextEditingController details;

  const _Step3({
    required this.service,
    required this.vehicle,
    required this.location,
    required this.details,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const Text("Additional Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        const Text("Help us understand your situation better", style: TextStyle(color: AppTheme.textDim)),
        const SizedBox(height: 14),
        GlassCard(
          child: Column(
            children: [
              _RowKV(k: "Service", v: serviceTitle(service)),
              const SizedBox(height: 8),
              _RowKV(k: "Vehicle", v: "${vehicle.name} (${vehicle.plate})"),
              const SizedBox(height: 8),
              _RowKV(k: "Location", v: location),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text("Describe the issue (optional)", style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        TextField(
          controller: details,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: "E.g. Car won't start, making clicking sound when turning key...",
            hintStyle: const TextStyle(color: AppTheme.textDim),
            filled: true,
            fillColor: AppTheme.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.stroke),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.stroke),
            ),
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          onTap: () {},
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.photo_camera_rounded, color: AppTheme.textDim),
              SizedBox(width: 10),
              Text("Add photos (optional)", style: TextStyle(color: AppTheme.textDim, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: const Row(
            children: [
              Icon(Icons.warning_rounded, color: AppTheme.accent),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "If this is a life-threatening emergency, please call 119 immediately.",
                  style: TextStyle(color: AppTheme.textDim, fontSize: 12),
                ),
              ),
            ],
          ),
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
    return Row(
      children: [
        Expanded(child: Text(k, style: const TextStyle(color: AppTheme.textDim))),
        Flexible(
          child: Text(
            v,
            style: const TextStyle(fontWeight: FontWeight.w900),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}