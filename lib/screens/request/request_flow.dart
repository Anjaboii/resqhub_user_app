import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../../models/demo_models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/primary_button.dart';
import '../tracking/live_tracking_dispatcher.dart';

class RequestVehicle {
  final String name, plate, meta, source;
  const RequestVehicle({required this.name, required this.plate, required this.meta, required this.source});
  Map<String, dynamic> toMap() => {"name": name, "plate": plate, "meta": meta, "vehicleSource": source};
}

// Services available per mode
const List<ServiceType> carrierServices = [ServiceType.fuel, ServiceType.towing, ServiceType.accident ];
const List<ServiceType> garageServices = [
  ServiceType.battery, ServiceType.flatTire, ServiceType.lockout,
  ServiceType.engine, ServiceType.other,
];

class RequestFlowScreen extends StatefulWidget {
  const RequestFlowScreen({super.key});
  @override
  State<RequestFlowScreen> createState() => _RequestFlowScreenState();
}

class _RequestFlowScreenState extends State<RequestFlowScreen> {
  int step = 0;
  String selectedMode = "carrier";
  ServiceType? selectedService;
  String? selectedVehicleId;
  bool useTemporaryVehicle = false;
  RequestVehicle? selectedVehicle;

  // Fuel specific
  String selectedFuelType = "Petrol";
  int fuelQuantity = 5;

  final tempName = TextEditingController();
  final tempPlate = TextEditingController();
  final tempMeta = TextEditingController();
  final details = TextEditingController();

  String location = "Fetching GPS location...";
  double? latitude, longitude;

  bool get isFuelService => selectedService == ServiceType.fuel;
  bool get isTowingService => selectedService == ServiceType.towing;

  // Total steps depends on service
  // Fuel: 0(mode) → 1(service) → 2(fuel details) → 3(vehicle) → 4(summary)
  // Others: 0(mode) → 1(service) → 2(vehicle) → 3(summary)
  int get totalSteps => isFuelService ? 5 : 4;

  @override
  void initState() {
    super.initState();
    _determinePosition();
    // Set default service for carrier
    selectedService = carrierServices.first;
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
        latitude = pos.latitude;
        longitude = pos.longitude;
        location = p.isNotEmpty ? "${p[0].street}, ${p[0].locality}" : "Unknown Location";
      });
    } catch (e) { setState(() => location = "Location Error"); }
  }

  @override
  void dispose() {
    details.dispose(); tempName.dispose();
    tempPlate.dispose(); tempMeta.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    final u = FirebaseAuth.instance.currentUser!;
    final doc = await FirebaseFirestore.instance.collection("users").doc(u.uid).get();
    final uName = doc.data()?["fullName"] ?? u.displayName ?? "User";
    final uPhone = doc.data()?["phone"] ?? "";

    final data = <String, dynamic>{
      "userId": u.uid,
      "userName": uName,
      "userPhone": uPhone,
      "providerRole": selectedMode,
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

    // Add fuel details if fuel service
    if (isFuelService) {
      data["fuelType"] = selectedFuelType;
      data["fuelQuantity"] = fuelQuantity;
    }

    if (details.text.trim().isNotEmpty) data["details"] = details.text.trim();

    final docRef = await FirebaseFirestore.instance.collection("requests").add(data);

    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (_) => TrackingDispatcher(requestId: docRef.id),
    ));
  }

  void _onModeSelected(String mode) {
    setState(() {
      selectedMode = mode;
      // Reset service to first available for this mode
      selectedService = mode == "carrier"
          ? carrierServices.first
          : garageServices.first;
    });
  }

  bool _canProceed() {
    if (step == 1 && selectedService == null) return false;
    if (step == (isFuelService ? 3 : 2) && selectedVehicle == null) return false;
    return true;
  }

  String _buttonText() {
    final lastStep = totalSteps - 1;
    return step == lastStep ? "Request Help" : "Continue";
  }

  @override
  Widget build(BuildContext context) {
    final lastStep = totalSteps - 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Request Assistance",
            style: TextStyle(fontWeight: FontWeight.w900)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => step == 0
              ? Navigator.pop(context)
              : setState(() => step--),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _StepBar(step: step, total: totalSteps),
            const SizedBox(height: 18),
            Expanded(
              child: _buildStep(),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              text: _buttonText(),
              onPressed: () async {
                if (!_canProceed()) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please complete this step.")),
                  );
                  return;
                }
                if (step < lastStep) {
                  setState(() => step++);
                } else {
                  await _submitRequest();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() {
    // Step 0: Mode selection
    if (step == 0) {
      return _Step0Mode(selected: selectedMode, onSelect: _onModeSelected);
    }

    // Step 1: Service selection (filtered by mode)
    if (step == 1) {
      final services = selectedMode == "carrier" ? carrierServices : garageServices;
      return _Step1(
        services: services,
        selected: selectedService ?? services.first,
        onSelect: (s) => setState(() => selectedService = s),
      );
    }

    // Step 2 (fuel only): Fuel type + quantity
    if (step == 2 && isFuelService) {
      return _StepFuelDetails(
        fuelType: selectedFuelType,
        quantity: fuelQuantity,
        onFuelTypeChanged: (t) => setState(() => selectedFuelType = t),
        onQuantityChanged: (q) => setState(() => fuelQuantity = q),
      );
    }

    // Step 2 (non-fuel) or Step 3 (fuel): Vehicle selection
    if (step == (isFuelService ? 3 : 2)) {
      return _Step2(
        selectedVehicleId: selectedVehicleId,
        onSelect: (id, v) => setState(() {
          selectedVehicleId = id;
          selectedVehicle = v;
          useTemporaryVehicle = false;
        }),
        useTemporary: useTemporaryVehicle,
        onToggle: () => setState(() {
          useTemporaryVehicle = !useTemporaryVehicle;
          selectedVehicle = null;
          selectedVehicleId = null;
        }),
        tempName: tempName,
        tempPlate: tempPlate,
        tempMeta: tempMeta,
        onTempChanged: () => setState(() => selectedVehicle = RequestVehicle(
          name: tempName.text,
          plate: tempPlate.text.toUpperCase(),
          meta: tempMeta.text,
          source: "temporary",
        )),
        location: location,
        onRefreshLoc: _determinePosition,
      );
    }

    // Last step: Summary
    return _Step3(
      service: selectedService!,
      vehicle: selectedVehicle!,
      location: location,
      details: details,
      fuelType: isFuelService ? selectedFuelType : null,
      fuelQuantity: isFuelService ? fuelQuantity : null,
    );
  }
}

// --- STEP WIDGETS ---

class _StepBar extends StatelessWidget {
  final int step, total;
  const _StepBar({required this.step, required this.total});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) => Expanded(
        child: Container(
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: step >= i ? AppTheme.accent : AppTheme.stroke,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      )),
    );
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
        const Text("Choose Service Type",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 20),
        _ModeCard(
          title: "Carrier Service",
          sub: "Towing or fuel delivery — we come to you.",
          icon: Icons.local_shipping_rounded,
          isSelected: selected == "carrier",
          onTap: () => onSelect("carrier"),
        ),
        const SizedBox(height: 15),
        _ModeCard(
          title: "Garage Service",
          sub: "Mechanic comes to fix your vehicle on the spot.",
          icon: Icons.build_rounded,
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
  const _ModeCard({required this.title, required this.sub, required this.icon,
    required this.isSelected, required this.onTap});

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
  final List<ServiceType> services;
  final ServiceType selected;
  final ValueChanged<ServiceType> onSelect;
  const _Step1({required this.services, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const Text("What do you need?",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: services.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, crossAxisSpacing: 12,
            mainAxisSpacing: 12, childAspectRatio: 1.3,
          ),
          itemBuilder: (_, i) {
            final s = services[i];
            final isSel = s == selected;
            return GlassCard(
              onTap: () => onSelect(s),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(_serviceIcon(s), color: isSel ? AppTheme.accent : Colors.white),
                    const Spacer(),
                    if (isSel) const Icon(Icons.check_circle_rounded, color: AppTheme.accent),
                  ]),
                  const SizedBox(height: 12),
                  Text(serviceTitle(s),
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(serviceSubtitle(s),
                      style: const TextStyle(color: AppTheme.textDim, fontSize: 11)),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  IconData _serviceIcon(ServiceType s) {
    switch (s) {
      case ServiceType.fuel: return Icons.local_gas_station_rounded;
      case ServiceType.towing: return Icons.local_shipping_rounded;
      case ServiceType.battery: return Icons.battery_alert_rounded;
      case ServiceType.flatTire: return Icons.tire_repair_rounded;
      case ServiceType.lockout: return Icons.lock_rounded;
      case ServiceType.engine: return Icons.engineering_rounded;
      case ServiceType.accident: return Icons.car_crash_rounded;
      case ServiceType.other: return Icons.miscellaneous_services_rounded;
    }
  }
}

// Fuel type and quantity step
class _StepFuelDetails extends StatelessWidget {
  final String fuelType;
  final int quantity;
  final ValueChanged<String> onFuelTypeChanged;
  final ValueChanged<int> onQuantityChanged;

  const _StepFuelDetails({
    required this.fuelType,
    required this.quantity,
    required this.onFuelTypeChanged,
    required this.onQuantityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const Text("Fuel Details",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 20),

        // Fuel type selector
        const Text("Fuel Type", style: TextStyle(color: AppTheme.textDim, fontSize: 13)),
        const SizedBox(height: 10),
        Row(
          children: ["Petrol", "Diesel"].map((type) {
            final isSelected = fuelType == type;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GlassCard(
                  onTap: () => onFuelTypeChanged(type),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: isSelected
                          ? Border.all(color: AppTheme.accent, width: 2)
                          : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.local_gas_station_rounded,
                          color: isSelected ? AppTheme.accent : Colors.white54,
                          size: 30,
                        ),
                        const SizedBox(height: 8),
                        Text(type,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: isSelected ? AppTheme.accent : Colors.white,
                            )),
                        if (isSelected)
                          const Icon(Icons.check_circle_rounded,
                              color: AppTheme.accent, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 30),

        // Quantity selector
        const Text("Quantity (Liters)",
            style: TextStyle(color: AppTheme.textDim, fontSize: 13)),
        const SizedBox(height: 10),
        GlassCard(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: quantity > 1
                    ? () => onQuantityChanged(quantity - 1)
                    : null,
                icon: const Icon(Icons.remove_circle_outline,
                    color: AppTheme.accent, size: 32),
              ),
              Column(
                children: [
                  Text(
                    "$quantity L",
                    style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.white),
                  ),
                  const Text("liters",
                      style: TextStyle(color: AppTheme.textDim, fontSize: 12)),
                ],
              ),
              IconButton(
                onPressed: quantity < 50
                    ? () => onQuantityChanged(quantity + 1)
                    : null,
                icon: const Icon(Icons.add_circle_outline,
                    color: AppTheme.accent, size: 32),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        // Quick select buttons
        const Text("Quick Select",
            style: TextStyle(color: AppTheme.textDim, fontSize: 13)),
        const SizedBox(height: 8),
        Row(
          children: [5, 10, 15, 20].map((q) {
            final isSelected = quantity == q;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onQuantityChanged(q),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.accent.withOpacity(0.2)
                          : AppTheme.stroke,
                      borderRadius: BorderRadius.circular(10),
                      border: isSelected
                          ? Border.all(color: AppTheme.accent)
                          : null,
                    ),
                    child: Center(
                      child: Text("$q L",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected ? AppTheme.accent : Colors.white70,
                          )),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _Step2 extends StatelessWidget {
  final String? selectedVehicleId;
  final void Function(String id, RequestVehicle v) onSelect;
  final bool useTemporary;
  final VoidCallback onToggle, onRefreshLoc, onTempChanged;
  final TextEditingController tempName, tempPlate, tempMeta;
  final String location;

  const _Step2({
    required this.selectedVehicleId, required this.onSelect,
    required this.useTemporary, required this.onToggle,
    required this.tempName, required this.tempPlate, required this.tempMeta,
    required this.onRefreshLoc, required this.onTempChanged, required this.location,
  });

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final vehiclesRef = FirebaseFirestore.instance
        .collection('users').doc(uid).collection('vehicles');

    return ListView(children: [
      Row(children: [
        const Expanded(child: Text("Select Vehicle",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
        TextButton(
          onPressed: onToggle,
          child: Text(useTemporary ? "Use saved" : "Use another",
              style: const TextStyle(color: AppTheme.accent)),
        ),
      ]),
      if (!useTemporary)
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: vehiclesRef.snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) return const LinearProgressIndicator();
            final docs = snap.data!.docs;

            if (selectedVehicleId == null && docs.isNotEmpty) {
              var def = docs.first;
              for (var d in docs) {
                if (d.data()['isDefault'] == true) { def = d; break; }
              }
              WidgetsBinding.instance.addPostFrameCallback((_) => onSelect(
                def.id,
                RequestVehicle(
                  name: def.data()["name"] ?? "",
                  plate: def.data()["plate"] ?? "",
                  meta: def.data()["meta"] ?? "",
                  source: "saved",
                ),
              ));
            }

            return Column(children: docs.map((d) {
              final isSel = d.id == selectedVehicleId;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  onTap: () => onSelect(d.id, RequestVehicle(
                    name: d.data()["name"] ?? "",
                    plate: d.data()["plate"] ?? "",
                    meta: d.data()["meta"] ?? "",
                    source: "saved",
                  )),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Row(children: [
                      Icon(Icons.directions_car_rounded,
                          color: isSel ? Colors.white : Colors.white54),
                      const SizedBox(width: 12),
                      Expanded(child: Text(d.data()["name"] ?? "",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: isSel ? Colors.white : Colors.white70,
                          ))),
                      if (isSel) const Icon(Icons.check_circle_rounded,
                          color: AppTheme.accent, size: 26),
                    ]),
                  ),
                ),
              );
            }).toList());
          },
        )
      else
        Column(children: [
          TextField(controller: tempName, onChanged: (_) => onTempChanged(),
              decoration: const InputDecoration(hintText: "Vehicle Name")),
          const SizedBox(height: 10),
          TextField(controller: tempPlate, onChanged: (_) => onTempChanged(),
              decoration: const InputDecoration(hintText: "Plate Number")),
        ]),
      const SizedBox(height: 20),
      Row(children: [
        const Text("Location",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const Spacer(),
        IconButton(onPressed: onRefreshLoc,
            icon: const Icon(Icons.my_location, color: AppTheme.accent)),
      ]),
      GlassCard(child: Text(location,
          style: const TextStyle(fontWeight: FontWeight.w900))),
    ]);
  }
}

class _Step3 extends StatelessWidget {
  final ServiceType service;
  final RequestVehicle vehicle;
  final String location;
  final TextEditingController details;
  final String? fuelType;
  final int? fuelQuantity;

  const _Step3({
    required this.service, required this.vehicle,
    required this.location, required this.details,
    this.fuelType, this.fuelQuantity,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      const Text("Summary",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      const SizedBox(height: 14),
      GlassCard(
        child: Column(children: [
          _RowKV(k: "Service", v: serviceTitle(service)),
          _RowKV(k: "Vehicle", v: "${vehicle.name} (${vehicle.plate})"),
          _RowKV(k: "Location", v: location),
          if (fuelType != null)
            _RowKV(k: "Fuel Type", v: fuelType!),
          if (fuelQuantity != null)
            _RowKV(k: "Quantity", v: "$fuelQuantity Liters"),
        ]),
      ),
      const SizedBox(height: 20),
      TextField(
        controller: details,
        maxLines: 3,
        decoration: const InputDecoration(
            hintText: "Additional details (optional)"),
      ),
    ]);
  }
}

class _RowKV extends StatelessWidget {
  final String k, v;
  const _RowKV({required this.k, required this.v});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(child: Text(k, style: const TextStyle(color: AppTheme.textDim))),
        Text(v, style: const TextStyle(fontWeight: FontWeight.bold)),
      ]),
    );
  }
}