import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool notificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const SafeArea(
        child: Scaffold(
          body: Center(child: Text("Please login to view profile")),
        ),
      );
    }

    final uid = user.uid;
    final email = user.email ?? "—";
    final displayName = (user.displayName?.trim().isNotEmpty ?? false) ? user.displayName!.trim() : "User";
    final createdAt = user.metadata.creationTime;

    String memberSinceText(DateTime? dt) {
      if (dt == null) return "Member since —";
      const months = [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
      ];
      return "Member since ${months[dt.month - 1]} ${dt.year}";
    }

    final userDocRef = FirebaseFirestore.instance.collection("users").doc(uid);
    final vehiclesColRef = userDocRef.collection("vehicles");

    final servicesQuery = FirebaseFirestore.instance
        .collection("requests")
        .where("userId", isEqualTo: uid);

    return SafeArea(
      child: Scaffold(
        body: StreamBuilder<DocumentSnapshot>(
          stream: userDocRef.snapshots(),
          builder: (context, userSnap) {
            final userData = (userSnap.data?.data() as Map<String, dynamic>?) ?? {};
            final phone = (userData["phone"] ?? "—").toString();

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const SizedBox(height: 6),
                Center(
                  child: CircleAvatar(
                    radius: 34,
                    backgroundColor: AppTheme.accent,
                    child: Text(
                      displayName.isNotEmpty ? displayName[0].toUpperCase() : "U",
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    displayName,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    memberSinceText(createdAt),
                    style: const TextStyle(color: AppTheme.textDim),
                  ),
                ),

                const SizedBox(height: 14),

                GlassCard(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      StreamBuilder<QuerySnapshot>(
                        stream: servicesQuery.snapshots(),
                        builder: (context, snap) {
                          final count = snap.data?.docs.length ?? 0;
                          return _PStat(title: "$count", sub: "Services");
                        },
                      ),
                      StreamBuilder<QuerySnapshot>(
                        stream: vehiclesColRef.snapshots(),
                        builder: (context, snap) {
                          final count = snap.data?.docs.length ?? 0;
                          return _PStat(title: "$count", sub: "Vehicles");
                        },
                      ),
                      const _PStat(title: "—", sub: "Avg Rating"),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            "CONTACT INFORMATION",
                            style: TextStyle(
                              color: AppTheme.textDim,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () => _openEditContactSheet(
                              context,
                              userDocRef: userDocRef,
                              currentPhone: phone == "—" ? "" : phone,
                            ),
                            icon: const Icon(Icons.edit_rounded, size: 18, color: AppTheme.accent),
                            label: const Text("Edit", style: TextStyle(color: AppTheme.accent)),
                          )
                        ],
                      ),
                      const SizedBox(height: 8),
                      _InfoRow(icon: Icons.phone_rounded, label: "Phone", value: phone),
                      const SizedBox(height: 10),
                      _InfoRow(icon: Icons.email_rounded, label: "Email", value: email),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                GlassCard(
                  child: Column(
                    children: [
                      _SettingRow(
                        title: "Payment Methods",
                        icon: Icons.credit_card_rounded,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Payment Methods - coming soon")),
                          );
                        },
                      ),
                      _SettingRow(
                        title: "Account Security",
                        icon: Icons.shield_rounded,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Account Security - coming soon")),
                          );
                        },
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _SettingRow(
                              title: "Notifications",
                              icon: Icons.notifications_rounded,
                              showArrow: false,
                              onTap: () {},
                            ),
                          ),
                          Switch(
                            value: notificationsEnabled,
                            onChanged: (v) => setState(() => notificationsEnabled = v),
                          ),
                        ],
                      ),
                      _SettingRow(
                        title: "Help & Support",
                        icon: Icons.help_rounded,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Help & Support - coming soon")),
                          );
                        },
                      ),
                      _SettingRow(
                        title: "Logout",
                        icon: Icons.logout_rounded,
                        onTap: () async {
                          await FirebaseAuth.instance.signOut();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _openEditContactSheet(
      BuildContext context, {
        required DocumentReference userDocRef,
        required String currentPhone,
      }) async {
    final phoneCtrl = TextEditingController(text: currentPhone);

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 14,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Edit Contact Info", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: "Phone",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    await userDocRef.set({
                      "phone": phoneCtrl.text.trim(),
                      "updatedAt": FieldValue.serverTimestamp(),
                    }, SetOptions(merge: true));

                    if (context.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Profile updated ✅")),
                      );
                    }
                  },
                  child: const Text("Save", style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PStat extends StatelessWidget {
  final String title;
  final String sub;
  const _PStat({required this.title, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(sub, style: const TextStyle(color: AppTheme.textDim, fontSize: 12)),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.textDim),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppTheme.textDim, fontSize: 12)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingRow extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool showArrow;
  final VoidCallback onTap;

  const _SettingRow({
    required this.title,
    required this.icon,
    required this.onTap,
    this.showArrow = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppTheme.textDim),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      trailing: showArrow ? const Icon(Icons.chevron_right_rounded, color: AppTheme.textDim) : null,
      onTap: onTap,
    );
  }
}