import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/glass_card.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = AppTheme.getTextPrimary(isDark);
    final dimColor = AppTheme.getTextDim(isDark);

    return Scaffold(
      appBar: AppBar(title: Text(loc.tr('aboutUs'), style: const TextStyle(fontWeight: FontWeight.w900))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: AppTheme.sosGradient),
                boxShadow: [BoxShadow(color: AppTheme.accent.withValues(alpha: 0.3), blurRadius: 30, spreadRadius: 5)],
              ),
              child: const Icon(Icons.car_repair_rounded, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Text("ResQHub", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: textColor)),
            Text("v1.0.0", style: TextStyle(color: dimColor, fontSize: 14)),
            const SizedBox(height: 30),
            GlassCard(
              child: Text(
                "ResQHub is Sri Lanka's premier roadside assistance platform. We connect stranded motorists with verified service providers for towing, fuel delivery, battery assistance, and more — all in real-time.\n\nOur mission is to ensure no driver is ever left helpless on the road. With live tracking, secure payments, and a network of trusted partners, ResQHub delivers peace of mind at every journey.",
                style: TextStyle(color: dimColor, fontSize: 14, height: 1.6),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            GlassCard(
              child: Column(
                children: [
                  _AboutRow(icon: Icons.email_outlined, label: "support@resqhub.lk", textColor: textColor, dimColor: dimColor),
                  Divider(color: isDark ? Colors.white10 : Colors.grey.shade200),
                  _AboutRow(icon: Icons.phone_outlined, label: "+94 11 234 5678", textColor: textColor, dimColor: dimColor),
                  Divider(color: isDark ? Colors.white10 : Colors.grey.shade200),
                  _AboutRow(icon: Icons.language_outlined, label: "www.resqhub.lk", textColor: textColor, dimColor: dimColor),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Text("© 2026 ResQHub. All rights reserved.", style: TextStyle(color: dimColor, fontSize: 12)),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color textColor, dimColor;
  const _AboutRow({required this.icon, required this.label, required this.textColor, required this.dimColor});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Icon(icon, color: AppTheme.accent, size: 20),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: textColor, fontSize: 14)),
      ]),
    );
  }
}
