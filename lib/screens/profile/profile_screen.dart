import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 6),
            const Center(
              child: CircleAvatar(
                radius: 34,
                backgroundColor: AppTheme.accent,
                child: Icon(Icons.person_rounded, size: 38, color: Colors.black),
              ),
            ),
            const SizedBox(height: 10),
            const Center(child: Text("Kasun Perera", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
            const SizedBox(height: 4),
            const Center(child: Text("Member since June 2024", style: TextStyle(color: AppTheme.textDim))),
            const SizedBox(height: 14),
            GlassCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: const [
                  _PStat(title: "12", sub: "Services"),
                  _PStat(title: "2", sub: "Vehicles"),
                  _PStat(title: "4.9", sub: "Avg Rating"),
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
                      const Text("CONTACT INFORMATION",
                          style: TextStyle(color: AppTheme.textDim, fontWeight: FontWeight.w800, letterSpacing: 1)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.edit_rounded, size: 18, color: AppTheme.accent),
                        label: const Text("Edit", style: TextStyle(color: AppTheme.accent)),
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  const _InfoRow(icon: Icons.phone_rounded, label: "Phone", value: "+94 77 123 4567"),
                  const SizedBox(height: 10),
                  const _InfoRow(icon: Icons.email_rounded, label: "Email", value: "kasun.perera@email.com"),
                  const SizedBox(height: 10),
                  const _InfoRow(icon: Icons.warning_rounded, label: "Emergency Contact", value: "+94 71 987 6543"),
                ],
              ),
            ),
            const SizedBox(height: 14),
            GlassCard(
              child: Column(
                children: [
                  _SettingRow(title: "Payment Methods", icon: Icons.credit_card_rounded),
                  _SettingRow(title: "Account Security", icon: Icons.shield_rounded),
                  Row(
                    children: [
                      const Expanded(child: _SettingRow(title: "Notifications", icon: Icons.notifications_rounded, showArrow: false)),
                      Switch(value: true, onChanged: (_) {}),
                    ],
                  ),
                  _SettingRow(title: "Help & Support", icon: Icons.help_rounded),
                ],
              ),
            ),
          ],
        ),
      ),
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

  const _SettingRow({
    required this.title,
    required this.icon,
    this.showArrow = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppTheme.textDim),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      trailing: showArrow ? const Icon(Icons.chevron_right_rounded, color: AppTheme.textDim) : null,
      onTap: () {},
    );
  }
}
