import 'package:flutter/material.dart';
import '../../models/demo_models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../request/request_flow.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const locationTitle = "Galle Road, Colombo 03";
    const vehicle = DemoVehicle(
      name: "Toyota Corolla",
      plate: "CAB-1234",
      meta: "Default Vehicle",
      isDefault: true,
    );

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("ResQHub", style: TextStyle(fontWeight: FontWeight.w800)),
              SizedBox(height: 2),
              Text("Roadside Assistance", style: TextStyle(fontSize: 12, color: AppTheme.textDim)),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(
                label: const Text("Protected"),
                labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                backgroundColor: const Color(0xFF0D2A1A),
                side: BorderSide.none,
              ),
            )
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 6),
            const Center(
              child: Text("Need help? Tap the button below",
                  style: TextStyle(color: AppTheme.textDim)),
            ),
            const SizedBox(height: 14),

            // SOS button
            Center(
              child: InkWell(
                borderRadius: BorderRadius.circular(120),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RequestFlowScreen()),
                  );
                },
                child: Container(
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.accent.withOpacity(0.18),
                    border: Border.all(color: AppTheme.accent.withOpacity(0.6), width: 2),
                  ),
                  child: Center(
                    child: Container(
                      width: 130,
                      height: 130,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.accent,
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.warning_rounded, color: Colors.white, size: 32),
                          SizedBox(height: 8),
                          Text("SOS",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 22)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Center(
              child: Text("Press for emergency roadside assistance",
                  style: TextStyle(color: AppTheme.textDim, fontSize: 12)),
            ),

            const SizedBox(height: 24),
            const Text("QUICK SERVICES",
                style: TextStyle(letterSpacing: 1.1, color: AppTheme.textDim, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),

            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: const [
                _QuickTile(icon: Icons.battery_charging_full_rounded, label: "Battery"),
                _QuickTile(icon: Icons.tire_repair_rounded, label: "Flat Tire"),
                _QuickTile(icon: Icons.local_gas_station_rounded, label: "No Fuel"),
                _QuickTile(icon: Icons.local_shipping_rounded, label: "Towing"),
                _QuickTile(icon: Icons.key_rounded, label: "Lockout"),
                _QuickTile(icon: Icons.build_rounded, label: "Other"),
              ],
            ),

            const SizedBox(height: 16),

            GlassCard(
              child: Row(
                children: [
                  const Icon(Icons.location_on_rounded, color: AppTheme.accent),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Your Location", style: TextStyle(color: AppTheme.textDim, fontSize: 12)),
                        SizedBox(height: 2),
                        Text(locationTitle, style: TextStyle(fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text("Update", style: TextStyle(color: AppTheme.accent)),
                  )
                ],
              ),
            ),

            const SizedBox(height: 12),

            GlassCard(
              onTap: () {},
              child: Row(
                children: [
                  const Icon(Icons.directions_car_rounded, color: AppTheme.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(vehicle.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text("${vehicle.plate} • ${vehicle.meta}",
                            style: const TextStyle(color: AppTheme.textDim, fontSize: 12)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppTheme.textDim),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  final IconData icon;
  final String label;
  const _QuickTile({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    );
  }
}
