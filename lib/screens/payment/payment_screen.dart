import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class PaymentScreen extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic> reqData;
  final VoidCallback onPaymentComplete;

  const PaymentScreen({
    super.key,
    required this.requestId,
    required this.reqData,
    required this.onPaymentComplete,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _selectedMethod = 'cash';
  bool _isProcessing = false;

  Future<void> _submitPayment() async {
    setState(() => _isProcessing = true);
    try {
      await FirebaseFirestore.instance
          .collection('requests')
          .doc(widget.requestId)
          .update({
        'paymentMethod': _selectedMethod,
        'paymentStatus': 'paid',
        'paidAt': FieldValue.serverTimestamp(),
      });
      if (mounted) widget.onPaymentComplete();
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Payment failed. Please try again.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final num price = widget.reqData['price'] ?? 0;
    final String serviceType = widget.reqData['serviceType'] ?? '';
    final String providerName = widget.reqData['providerName'] ??
        widget.reqData['garageName'] ?? 'Provider';
    final bool isGarage = widget.reqData['providerRole'] == 'garage';

    return Container(
      color: AppTheme.bg,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accent.withOpacity(0.1),
                ),
                child: const Icon(Icons.receipt_long_rounded,
                    color: AppTheme.accent, size: 48),
              ),
              const SizedBox(height: 16),
              const Text("Payment",
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Colors.white)),
              const SizedBox(height: 4),
              Text(serviceType.toUpperCase().replaceAll('_', ' '),
                  style: const TextStyle(
                      color: AppTheme.textDim,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2)),
              const SizedBox(height: 24),

              // Price Card
              GlassCard(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Service Charge",
                            style: TextStyle(
                                color: AppTheme.textDim, fontSize: 14)),
                        Text("LKR ${price.toStringAsFixed(0)}",
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                      ],
                    ),
                    const Divider(height: 24, color: Colors.white10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Total",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 18)),
                        Text("LKR ${price.toStringAsFixed(0)}",
                            style: const TextStyle(
                                color: AppTheme.accent,
                                fontWeight: FontWeight.w900,
                                fontSize: 24)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Provider Info
              GlassCard(
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppTheme.accent.withOpacity(0.2),
                      child: Icon(
                          isGarage ? Icons.store_rounded : Icons.person,
                          color: AppTheme.accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(providerName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          Text(isGarage ? "Garage Service" : "Carrier Service",
                              style: const TextStyle(
                                  color: AppTheme.textDim, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Payment Method Selection
              Align(
                alignment: Alignment.centerLeft,
                child: const Text("Select Payment Method",
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16)),
              ),
              const SizedBox(height: 12),
              _PaymentMethodCard(
                icon: Icons.payments_rounded,
                title: "Cash",
                subtitle: "Pay directly to the provider",
                isSelected: _selectedMethod == 'cash',
                onTap: () => setState(() => _selectedMethod = 'cash'),
              ),
              const SizedBox(height: 10),
              _PaymentMethodCard(
                icon: Icons.credit_card_rounded,
                title: "Card",
                subtitle: "Pay via debit or credit card",
                isSelected: _selectedMethod == 'card',
                onTap: () => setState(() => _selectedMethod = 'card'),
              ),
              const SizedBox(height: 32),

              // Card details (shown only if card selected)
              if (_selectedMethod == 'card') ...[
                _CardDetailsForm(),
                const SizedBox(height: 24),
              ],

              // Pay Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _isProcessing ? null : _submitPayment,
                  child: _isProcessing
                      ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          color: Colors.black, strokeWidth: 2))
                      : Text(
                      _selectedMethod == 'cash'
                          ? "CONFIRM CASH PAYMENT"
                          : "PAY LKR ${price.toStringAsFixed(0)}",
                      style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 15)),
                ),
              ),
              const SizedBox(height: 16),
              if (_selectedMethod == 'cash')
                const Text(
                  "Please have the exact amount ready for the provider.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textDim, fontSize: 12),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentMethodCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accent.withOpacity(0.1)
              : AppTheme.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.accent : Colors.white10,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.accent.withOpacity(0.2)
                    : Colors.white10,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon,
                  color: isSelected ? AppTheme.accent : Colors.white54,
                  size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color:
                          isSelected ? Colors.white : Colors.white70)),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12,
                          color: isSelected
                              ? AppTheme.textDim
                              : AppTheme.textDim.withOpacity(0.5))),
                ],
              ),
            ),
            Icon(
              isSelected
                  ? Icons.check_circle_rounded
                  : Icons.circle_outlined,
              color: isSelected ? AppTheme.accent : Colors.white24,
            ),
          ],
        ),
      ),
    );
  }
}

class _CardDetailsForm extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Card Details",
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16)),
        const SizedBox(height: 12),
        TextField(
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.number,
          decoration: _inputDecoration("Card Number", Icons.credit_card),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                style: const TextStyle(color: Colors.white),
                decoration:
                _inputDecoration("MM/YY", Icons.calendar_today),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                style: const TextStyle(color: Colors.white),
                obscureText: true,
                decoration: _inputDecoration("CVV", Icons.lock_outline),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          style: const TextStyle(color: Colors.white),
          decoration:
          _inputDecoration("Cardholder Name", Icons.person_outline),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppTheme.textDim),
      prefixIcon: Icon(icon, color: AppTheme.textDim, size: 20),
      filled: true,
      fillColor: AppTheme.card,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.accent)),
    );
  }
}