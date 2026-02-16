import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/primary_button.dart';

class LiveTrackingScreen extends StatefulWidget {
  final String serviceName;
  final String vehicleName;
  final String location;

  const LiveTrackingScreen({
    super.key,
    required this.serviceName,
    required this.vehicleName,
    required this.location,
  });

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  bool accepted = false;

  @override
  void initState() {
    super.initState();
    // demo: auto switch to accepted after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => accepted = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Live Tracking", style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w800)),
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Live map tracking", style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                Container(
                  height: 160,
                  decoration: BoxDecoration(
                    color: const Color(0xFF111A2E),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.stroke),
                  ),
                  child: const Center(
                    child: Icon(Icons.location_on_rounded, color: AppTheme.accent, size: 40),
                  ),
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: accepted ? 0.7 : 0.25,
                  backgroundColor: AppTheme.stroke,
                  color: AppTheme.accent,
                  minHeight: 6,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (accepted) ...[
            GlassCard(
              child: Row(
                children: const [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Estimated Arrival", style: TextStyle(color: AppTheme.textDim)),
                        SizedBox(height: 4),
                        Text("5 min", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                  CircleAvatar(
                    backgroundColor: AppTheme.accent,
                    child: Icon(Icons.navigation_rounded, color: Colors.black),
                  )
                ],
              ),
            ),
            const SizedBox(height: 12),

            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("AutoCare Garage", style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  const Text("Saman Kumara • 4.8 ★ • 342 jobs", style: TextStyle(color: AppTheme.textDim)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: PrimaryButton(text: "Call", onPressed: () {}, filled: false)),
                      const SizedBox(width: 10),
                      Expanded(child: PrimaryButton(text: "Message", onPressed: () {}, filled: false)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("STATUS", style: TextStyle(color: AppTheme.textDim, fontWeight: FontWeight.w800, letterSpacing: 1)),
                const SizedBox(height: 10),
                _StatusItem(active: true, title: "Searching", sub: "Finding nearby providers..."),
                _StatusItem(active: accepted, title: "Accepted", sub: "Provider accepted your request"),
                _StatusItem(active: false, title: "En Route", sub: "Provider is on the way"),
                _StatusItem(active: false, title: "Arrived", sub: "Provider arrived at location"),
                _StatusItem(active: false, title: "In Progress", sub: "Assistance in progress"),
              ],
            ),
          ),

          const SizedBox(height: 12),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("SERVICE DETAILS", style: TextStyle(color: AppTheme.textDim, fontWeight: FontWeight.w800, letterSpacing: 1)),
                const SizedBox(height: 10),
                _KV("Service Type", widget.serviceName),
                _KV("Vehicle", widget.vehicleName),
                _KV("Location", widget.location),
                _KV("Estimated Cost", "Rs. 2,500"),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusItem extends StatelessWidget {
  final bool active;
  final String title;
  final String sub;

  const _StatusItem({required this.active, required this.title, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: active ? AppTheme.accent : AppTheme.stroke,
            child: active
                ? const Icon(Icons.check_rounded, size: 16, color: Colors.black)
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(sub, style: const TextStyle(color: AppTheme.textDim, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KV extends StatelessWidget {
  final String k;
  final String v;
  const _KV(this.k, this.v);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(k, style: const TextStyle(color: AppTheme.textDim))),
          Flexible(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w900), textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}
