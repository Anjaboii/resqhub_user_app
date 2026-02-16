import 'package:flutter/material.dart';
import '../../models/demo_models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/primary_button.dart';
import '../tracking/live_tracking_screen.dart';

class RequestFlowScreen extends StatefulWidget {
  const RequestFlowScreen({super.key});

  @override
  State<RequestFlowScreen> createState() => _RequestFlowScreenState();
}

class _RequestFlowScreenState extends State<RequestFlowScreen> {
  int step = 0;
  ServiceType? selectedService = ServiceType.battery;
  int selectedVehicleIndex = 0;
  String location = "Galle Road, Colombo 03";
  final details = TextEditingController();

  final vehicles = const [
    DemoVehicle(name: "Toyota Corolla", plate: "CAB-1234", meta: ""),
    DemoVehicle(name: "Honda Civic", plate: "WP-5678", meta: ""),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Request Assistance", style: const TextStyle(fontWeight: FontWeight.w900)),
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
                    vehicles: vehicles,
                    selectedIndex: selectedVehicleIndex,
                    onSelectVehicle: (i) => setState(() => selectedVehicleIndex = i),
                    location: location,
                    onChangeLocation: () => setState(() => location = "Near Liberty Plaza"),
                  ),
                _ => _Step3(
                    service: selectedService!,
                    vehicle: vehicles[selectedVehicleIndex],
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
                    text: step == 0 ? "Continue" : (step == 2 ? "Request Help" : "Continue"),
                    onPressed: () {
                      if (step < 2) {
                        setState(() => step++);
                      } else {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LiveTrackingScreen(
                              serviceName: serviceTitle(selectedService!),
                              vehicleName: "${vehicles[selectedVehicleIndex].name} (${vehicles[selectedVehicleIndex].plate})",
                              location: location,
                            ),
                          ),
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
                      Icon(Icons.miscellaneous_services_rounded,
                          color: isSel ? AppTheme.accent : Colors.white),
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
  final List vehicles;
  final int selectedIndex;
  final ValueChanged<int> onSelectVehicle;
  final String location;
  final VoidCallback onChangeLocation;

  const _Step2({
    required this.vehicles,
    required this.selectedIndex,
    required this.onSelectVehicle,
    required this.location,
    required this.onChangeLocation,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const Text("Vehicle & Location", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        const Text("Confirm your vehicle and current location", style: TextStyle(color: AppTheme.textDim)),
        const SizedBox(height: 14),
        const Text("Select Vehicle", style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        for (int i = 0; i < vehicles.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassCard(
              onTap: () => onSelectVehicle(i),
              child: Row(
                children: [
                  const Icon(Icons.directions_car_rounded, color: AppTheme.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(vehicles[i].name, style: const TextStyle(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 2),
                        Text(vehicles[i].plate, style: const TextStyle(color: AppTheme.textDim)),
                      ],
                    ),
                  ),
                  if (i == selectedIndex) const Icon(Icons.check_circle_rounded, color: AppTheme.accent),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
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
  final DemoVehicle vehicle;
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
              _RowKV(k: "Vehicle", v: vehicle.name),
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppTheme.stroke)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.stroke)),
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
        Text(v, style: const TextStyle(fontWeight: FontWeight.w900)),
      ],
    );
  }
}
