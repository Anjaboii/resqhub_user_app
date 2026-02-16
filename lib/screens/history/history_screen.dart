import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Service History", style: TextStyle(fontWeight: FontWeight.w900)),
          actions: [
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.filter_alt_outlined, color: AppTheme.accent),
            )
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GlassCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: const [
                  _Stat(title: "4", sub: "Completed"),
                  _Stat(title: "Rs. 16.0k", sub: "Total Spent"),
                  _Stat(title: "4.8", sub: "Avg Rating"),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: const [
                _Chip("All", selected: true),
                SizedBox(width: 8),
                _Chip("Completed"),
                SizedBox(width: 8),
                _Chip("Cancelled"),
              ],
            ),
            const SizedBox(height: 12),
            const _HistoryCard(
              title: "Battery Jump Start",
              provider: "AutoCare Garage",
              badge: "Completed",
              price: "Rs. 2,500",
              vehicle: "Toyota Corolla • CAB-1234",
              date: "Dec 10, 2024 • 10:30 AM",
              location: "Galle Road, Colombo 03",
              stars: 5,
            ),
            const SizedBox(height: 12),
            const _HistoryCard(
              title: "Tire Replacement",
              provider: "QuickFix Motors",
              badge: "Completed",
              price: "Rs. 3,500",
              vehicle: "Toyota Corolla • CAB-1234",
              date: "Nov 28, 2024 • 02:15 PM",
              location: "Baseline Road, Colombo 09",
              stars: 4,
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String title;
  final String sub;
  const _Stat({required this.title, required this.sub});

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

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  const _Chip(this.label, {this.selected = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? AppTheme.accent.withOpacity(0.2) : AppTheme.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: selected ? AppTheme.accent : AppTheme.stroke),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? AppTheme.accent : AppTheme.textDim,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final String title, provider, badge, price, vehicle, date, location;
  final int stars;
  const _HistoryCard({
    required this.title,
    required this.provider,
    required this.badge,
    required this.price,
    required this.vehicle,
    required this.date,
    required this.location,
    required this.stars,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D2A1A),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(badge, style: const TextStyle(color: Color(0xFF3CE06D), fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(provider, style: const TextStyle(color: AppTheme.textDim)),
          const SizedBox(height: 12),
          Text(vehicle, style: const TextStyle(color: AppTheme.textDim, fontSize: 12)),
          const SizedBox(height: 6),
          Text(date, style: const TextStyle(color: AppTheme.textDim, fontSize: 12)),
          const SizedBox(height: 6),
          Text(location, style: const TextStyle(color: AppTheme.textDim, fontSize: 12)),
          const SizedBox(height: 10),
          Row(
            children: [
              for (int i = 0; i < 5; i++)
                Icon(i < stars ? Icons.star_rounded : Icons.star_border_rounded, size: 18, color: AppTheme.accent),
              const Spacer(),
              Text(price, style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }
}
