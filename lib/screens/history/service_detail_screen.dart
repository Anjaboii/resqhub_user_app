import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class ServiceDetailScreen extends StatelessWidget {
  final Map<String, dynamic> jobData;

  const ServiceDetailScreen({super.key, required this.jobData});

  @override
  Widget build(BuildContext context) {
    final vehicleMap = jobData['vehicle'] as Map<String, dynamic>? ?? {};

    // 🎯 Get the dynamic status from Firestore
    final String status = (jobData['status'] ?? 'completed').toString().toLowerCase();

    // 🎨 Determine status-specific colors
    final Color statusColor = status == 'completed' ? Colors.greenAccent : Colors.redAccent;
    final IconData statusIcon = status == 'completed' ? Icons.check_circle_rounded : Icons.cancel_rounded;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text("Trip Details", style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header Card with Dynamic Status
            GlassCard(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: AppTheme.accent, // 🎨 Using your AppTheme accent
                    child: const Icon(Icons.person, color: Colors.black, size: 35),
                  ),
                  const SizedBox(height: 12),
                  Text(jobData['providerName'] ?? "Rescuer",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),

                  const SizedBox(height: 8),

                  // 🏷️ Dynamic Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, color: statusColor, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          status.toUpperCase(),
                          style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ISSUE REPORTED Section
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("ISSUE REPORTED", style: TextStyle(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _row(Icons.report_problem_rounded, "Service Category", (jobData['serviceType'] ?? "FLAT TIRE").toString().toUpperCase()),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // VEHICLE INFO Section
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("VEHICLE INFO", style: TextStyle(color: AppTheme.textDim, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _row(Icons.directions_car, "Model", vehicleMap['name'] ?? "Suzuki Swift"),
                  const Divider(color: Colors.white10, height: 32),
                  _row(Icons.tag, "Plate Number", vehicleMap['plate'] ?? "555 - 6666"),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // LOCATION & CONTACT Section
            GlassCard(
              child: Column(
                children: [
                  _row(Icons.location_on, "Location", jobData['locationText'] ?? "1600 Amphitheatre Pkwy, Mountain View"),
                  const Divider(color: Colors.white10, height: 32),
                  _row(Icons.phone, "Provider Phone", jobData['providerPhone'] ?? "0774796913"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.accent, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppTheme.textDim, fontSize: 11)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
            ],
          ),
        ),
      ],
    );
  }
}