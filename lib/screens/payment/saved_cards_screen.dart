import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../l10n/app_localizations.dart';

class SavedCardsScreen extends StatelessWidget {
  const SavedCardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final cardsRef = FirebaseFirestore.instance.collection('users').doc(uid).collection('savedCards');

    return Scaffold(
      appBar: AppBar(title: Text(loc.tr('savedCards'), style: const TextStyle(fontWeight: FontWeight.w900))),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.accent,
        onPressed: () => _showAddCardSheet(context, cardsRef),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: cardsRef.orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.credit_card_off_rounded, size: 60, color: AppTheme.getTextDim(isDark)),
                const SizedBox(height: 16),
                Text("No saved cards", style: TextStyle(color: AppTheme.getTextDim(isDark), fontSize: 16)),
                const SizedBox(height: 8),
                Text("Add a card for faster payments", style: TextStyle(color: AppTheme.getTextDim(isDark).withValues(alpha: 0.6), fontSize: 13)),
              ]),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _CreditCardWidget(
                  last4: data['last4'] ?? '****',
                  holder: data['holderName'] ?? 'Card Holder',
                  expiry: data['expiry'] ?? 'MM/YY',
                  brand: data['brand'] ?? 'visa',
                  onDelete: () async {
                    await docs[i].reference.delete();
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Card removed")));
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddCardSheet(BuildContext context, CollectionReference cardsRef) {
    final numberCtrl = TextEditingController();
    final holderCtrl = TextEditingController();
    final expiryCtrl = TextEditingController();
    final cvvCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(color: AppTheme.getCard(isDark), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(10))),
          const SizedBox(height: 20),
          Text("Add New Card", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppTheme.getTextPrimary(isDark))),
          const SizedBox(height: 20),
          TextField(controller: numberCtrl, keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(16), _CardNumberFormatter()],
            decoration: const InputDecoration(labelText: "Card Number", prefixIcon: Icon(Icons.credit_card, color: AppTheme.accent), hintText: "1234 5678 9012 3456")),
          const SizedBox(height: 12),
          TextField(controller: holderCtrl, textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: "Cardholder Name", prefixIcon: Icon(Icons.person_outline, color: AppTheme.accent))),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(controller: expiryCtrl, keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4), _ExpiryFormatter()],
              decoration: const InputDecoration(labelText: "MM/YY", prefixIcon: Icon(Icons.calendar_today, color: AppTheme.accent)))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: cvvCtrl, obscureText: true, keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
              decoration: const InputDecoration(labelText: "CVV", prefixIcon: Icon(Icons.lock_outline, color: AppTheme.accent)))),
          ]),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, height: 55, child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            onPressed: () async {
              final num = numberCtrl.text.replaceAll(' ', '');
              if (num.length < 13 || holderCtrl.text.isEmpty || expiryCtrl.text.isEmpty) return;
              final brand = num.startsWith('4') ? 'visa' : num.startsWith('5') ? 'mastercard' : 'card';
              await cardsRef.add({
                'last4': num.substring(num.length - 4),
                'holderName': holderCtrl.text.trim().toUpperCase(),
                'expiry': expiryCtrl.text.trim(),
                'brand': brand,
                'createdAt': FieldValue.serverTimestamp(),
              });
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text("Save Card", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
          )),
        ]),
      ),
    );
  }
}

class _CreditCardWidget extends StatelessWidget {
  final String last4, holder, expiry, brand;
  final VoidCallback onDelete;
  const _CreditCardWidget({required this.last4, required this.holder, required this.expiry, required this.brand, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final colors = brand == 'visa'
        ? [const Color(0xFF1A1F71), const Color(0xFF4B6CB7)]
        : brand == 'mastercard'
        ? [const Color(0xFFEB001B), const Color(0xFFF79E1B)]
        : [const Color(0xFF334155), const Color(0xFF64748B)];

    return Container(
      height: 190,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
        boxShadow: [BoxShadow(color: colors[0].withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(brand.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2)),
          IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline, color: Colors.white70, size: 20)),
        ]),
        const Spacer(),
        Text("•••• •••• •••• $last4", style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: 3)),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("CARD HOLDER", style: TextStyle(color: Colors.white60, fontSize: 10, letterSpacing: 1)),
            Text(holder, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text("EXPIRES", style: TextStyle(color: Colors.white60, fontSize: 10, letterSpacing: 1)),
            Text(expiry, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          ]),
        ]),
      ]),
    );
  }
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if ((i + 1) % 4 == 0 && i != text.length - 1) buffer.write(' ');
    }
    return TextEditingValue(text: buffer.toString(), selection: TextSelection.collapsed(offset: buffer.length));
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll('/', '');
    if (text.length >= 2) {
      return TextEditingValue(text: '${text.substring(0, 2)}/${text.substring(2)}', selection: TextSelection.collapsed(offset: text.length + 1));
    }
    return newValue;
  }
}
