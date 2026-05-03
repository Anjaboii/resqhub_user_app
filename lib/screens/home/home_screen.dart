import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../request/request_flow.dart';
import '../tracking/live_tracking_dispatcher.dart';
import 'notification_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: -100, right: -50,
            child: CircleAvatar(radius: 150, backgroundColor: AppTheme.accent.withOpacity(0.05)),
          ),
          SafeArea(
            child: Column(
              children: [
                // 🛰️ 1. ACTIVE REQUEST BANNER
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('requests')
                      .where('userId', isEqualTo: user?.uid)
                      .where('status', whereIn: [
                    'requested', 'accepted', 'en_route', 'arrived',
                    'towing', 'in_progress',
                  ])
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    final reqDoc = snapshot.data!.docs.first;
                    final reqData = reqDoc.data() as Map<String, dynamic>;

                    return Container(
                      margin: const EdgeInsets.all(16),
                      child: GlassCard(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => TrackingDispatcher(requestId: reqDoc.id),
                          ));
                        },
                        child: Row(
                          children: [
                            const Icon(Icons.emergency_share, color: Colors.orangeAccent),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Request Active: ${reqData['status']?.toUpperCase().replaceAll('_', ' ')}",
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.orangeAccent)),
                                  const Text("Tap to view live tracking", style: TextStyle(fontSize: 11, color: AppTheme.textDim)),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textDim),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                // 📄 2. HOME CONTENT
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Welcome back,", style: TextStyle(color: AppTheme.textDim, fontSize: 14)),
                              Text(user?.displayName ?? "ResQ User",
                                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          // 🔔 NOTIFICATION CENTER BUTTON
                          Stack(
                            alignment: Alignment.topRight,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 28),
                                onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const NotificationScreen())
                                ),
                              ),
                              Positioned(
                                top: 10, right: 10,
                                child: Container(
                                  width: 8, height: 8,
                                  decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      GlassCard(
                        child: const Row(
                          children: [
                            Icon(Icons.verified_user_rounded, color: Colors.greenAccent),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("System Status", style: TextStyle(color: AppTheme.textDim, fontSize: 12)),
                                  Text("Secured & Online", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 60),
                      Center(
                        child: GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RequestFlowScreen())),
                          child: AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              return Container(
                                width: 200, height: 200,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.accent.withOpacity(0.2 * (1 - _pulseController.value)),
                                      blurRadius: 40, spreadRadius: 30 * _pulseController.value,
                                    )
                                  ],
                                ),
                                child: child,
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.all(15),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(colors: AppTheme.sosGradient),
                              ),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.warning_amber_rounded, color: Colors.white, size: 50),
                                  Text("SOS", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 60),
                      const Text("QUICK ASSIST", style: TextStyle(color: AppTheme.textDim, fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 15),
                      GridView.count(
                        crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 1.5,
                        children: const [
                          _ServiceCard(icon: Icons.battery_alert_rounded, title: "Battery", color: Colors.orangeAccent),
                          _ServiceCard(icon: Icons.tire_repair_rounded, title: "Flat Tire", color: Colors.blueAccent),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final IconData icon; final String title; final Color color;
  const _ServiceCard({required this.icon, required this.title, required this.color});
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RequestFlowScreen())),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: color, size: 30),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}