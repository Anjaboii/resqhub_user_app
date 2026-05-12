import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/glass_card.dart';

class FAQScreen extends StatelessWidget {
  const FAQScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = AppTheme.getTextPrimary(isDark);
    final dimColor = AppTheme.getTextDim(isDark);

    final faqs = [
      {"q": "How do I request roadside assistance?", "a": "Tap the SOS button on the home screen, select your service type, choose your vehicle, and submit. A nearby provider will be assigned to help you."},
      {"q": "What payment methods are accepted?", "a": "We accept cash payments and card payments (Visa/Mastercard). You can save cards for future use."},
      {"q": "How do I track my service provider?", "a": "Once a provider accepts your request, you'll see real-time tracking on the map showing their location and estimated arrival."},
      {"q": "Can I cancel a request?", "a": "Yes, you can cancel a request before the provider arrives. Go to the tracking screen and tap 'Cancel Request'."},
      {"q": "How do I add a vehicle?", "a": "Go to the Vehicles tab, tap the + button, select your vehicle brand and model, enter the plate number, and save."},
      {"q": "Is my payment information secure?", "a": "Yes, we use industry-standard encryption. Card details are stored securely and never shared with third parties."},
      {"q": "How do I change the app language?", "a": "Go to Profile → Preferences → Language and select your preferred language (English, Sinhala, or Tamil)."},
      {"q": "What services are available?", "a": "We offer towing, fuel delivery, battery jump-start, flat tire repair, lockout assistance, engine diagnostics, and accident response."},
    ];

    return Scaffold(
      appBar: AppBar(title: Text(loc.tr('faq'), style: const TextStyle(fontWeight: FontWeight.w900))),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: faqs.length,
        itemBuilder: (context, i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GlassCard(
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 12),
                iconColor: AppTheme.accent,
                collapsedIconColor: dimColor,
                title: Text(faqs[i]["q"]!, style: TextStyle(fontWeight: FontWeight.w700, color: textColor, fontSize: 14)),
                children: [Text(faqs[i]["a"]!, style: TextStyle(color: dimColor, fontSize: 13, height: 1.5))],
              ),
            ),
          );
        },
      ),
    );
  }
}
