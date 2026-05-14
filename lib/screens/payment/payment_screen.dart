import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../l10n/app_localizations.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PaymentScreen
// ─────────────────────────────────────────────────────────────────────────────
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
  String? _selectedCardId;

  double _baseCharge = 0;
  double _perKmRate = 0;
  double _platformFee = 0;
  bool _isLoadingRates = true;

  @override
  void initState() {
    super.initState();
    _fetchRates();
  }

  // ── Fetch service rates from Firestore ──────────────────────────────────────
  Future<void> _fetchRates() async {
    try {
      final st =
      (widget.reqData['serviceType'] ?? '').toString().toLowerCase();
      final isGarage = widget.reqData['providerRole'] == 'garage' ||
          st == 'battery' ||
          st == 'lockout' ||
          st == 'engine' ||
          st == 'flat_tire';

      final platformDoc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('platform_settings')
          .get();
      double pFee = 250;
      if (platformDoc.exists) {
        pFee =
            (platformDoc.data()?['platformFee'] as num?)?.toDouble() ?? 250;
      }

      double base = 2000;
      double perKm = 100;

      if (isGarage) {
        final garageDoc = await FirebaseFirestore.instance
            .collection('settings')
            .doc('garage_service_rates')
            .get();
        if (garageDoc.exists) {
          final data = garageDoc.data()!;
          if (st == 'engine') {
            base = (data['engineBase'] as num?)?.toDouble() ?? 5000;
          } else if (st == 'battery') {
            base = (data['batteryBase'] as num?)?.toDouble() ?? 1500;
          } else if (st == 'lockout') {
            base = (data['lockoutBase'] as num?)?.toDouble() ?? 1200;
          } else {
            base = (data['mechanicalBase'] as num?)?.toDouble() ?? 3000;
          }
          perKm = (data['perKm'] as num?)?.toDouble() ?? 0;
        }
      } else if (st == 'fuel') {
        final fuelDoc = await FirebaseFirestore.instance
            .collection('settings')
            .doc('fuel_prices')
            .get();
        if (fuelDoc.exists) {
          final data = fuelDoc.data()!;
          base = (data['fuelBase'] as num?)?.toDouble() ?? 1000;
          perKm = (data['fuelPerKm'] as num?)?.toDouble() ?? 80;
        }
      } else {
        final serviceDoc = await FirebaseFirestore.instance
            .collection('settings')
            .doc('service_rates')
            .get();
        if (serviceDoc.exists) {
          final data = serviceDoc.data()!;
          if (st == 'towing') {
            base = (data['towingBase'] as num?)?.toDouble() ?? 2500;
            perKm = (data['towingPerKm'] as num?)?.toDouble() ?? 150;
          } else if (st == 'accident') {
            base = (data['accidentBase'] as num?)?.toDouble() ?? 3000;
            perKm = (data['accidentPerKm'] as num?)?.toDouble() ?? 150;
          }
        }
      }

      if (mounted) {
        setState(() {
          _baseCharge = base;
          _perKmRate = perKm;
          _platformFee = pFee;
          _isLoadingRates = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingRates = false);
    }
  }

  // ── Price helpers ────────────────────────────────────────────────────────────
  double get _distanceKm {
    final d = widget.reqData['distanceKm'];
    if (d != null) return (d as num).toDouble();
    return 0;
  }

  double get _computedDistanceKm {
    if (_distanceKm > 0) return _distanceKm;
    final providerPrice = widget.reqData['price'];
    if (providerPrice != null && _perKmRate > 0) {
      final double priceNum = (providerPrice as num).toDouble();
      if (priceNum > _baseCharge) {
        return (priceNum - _baseCharge) / _perKmRate;
      }
    }
    return 0.0;
  }

  double get _distanceCharge => _computedDistanceKm * _perKmRate;

  double get _totalPrice {
    final providerPrice = widget.reqData['price'];
    if (providerPrice != null) return (providerPrice as num).toDouble();
    return _baseCharge + _distanceCharge;
  }

  /// Convert LKR → USD for PayPal (PayPal does not support LKR).
  /// Using a fixed approximate rate. Replace with a live rate API if needed.
  double get _totalPriceUSD => (_totalPrice / 300).clamp(0.01, 999999);

  // ── Cash payment ─────────────────────────────────────────────────────────────
  Future<void> _submitCashPayment() async {
    setState(() => _isProcessing = true);
    try {
      final isGarage = widget.reqData['providerRole'] == 'garage';
      await FirebaseFirestore.instance
          .collection('requests')
          .doc(widget.requestId)
          .update({
        'paymentMethod': 'cash',
        'paymentStatus': 'awaiting_provider',
        'totalPaid': _totalPrice,
      });
      // Don't call onPaymentComplete — wait for provider to confirm
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Payment failed. Try again.")),
        );
      }
    }
  }

  // ── PayPal payment flow ──────────────────────────────────────────────────────
  Future<void> _startPayPalPayment() async {
    setState(() => _isProcessing = true);
    try {
      // 1. Call Firebase Function to create a PayPal order
      final callable = FirebaseFunctions.instance
          .httpsCallable('createPayPalOrder');

      final result = await callable.call({
        'amount': _totalPriceUSD.toStringAsFixed(2),
        'currency': 'USD',
        'requestId': widget.requestId,
      });

      final approvalUrl = result.data['approvalUrl'] as String?;
      final orderId = result.data['orderId'] as String?;

      if (approvalUrl == null || orderId == null) {
        throw Exception("Invalid PayPal response");
      }

      if (!mounted) return;

      // 2. Open PayPal approval in a WebView
      final success = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => _PayPalWebView(
            approvalUrl: approvalUrl,
            successUrlFragment: 'auto360.app/paypal/success',
            cancelUrlFragment: 'auto360.app/paypal/cancel',
          ),
        ),
      );

      if (success == true) {
        // 3. Capture the order via Firebase Function
        final captureCallable = FirebaseFunctions.instance
            .httpsCallable('capturePayPalOrder');

        final captureResult = await captureCallable.call({
          'orderId': orderId,
          'requestId': widget.requestId,
        });

        if (captureResult.data['success'] == true) {
          if (mounted) widget.onPaymentComplete();
          return;
        }
      }

      // User cancelled or capture failed
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("PayPal payment was cancelled.")),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("PayPal error: ${e.toString()}")),
        );
      }
    }
  }

  // ── Card payment (garage card machine) ──────────────────────────────────────
  Future<void> _submitCardPayment() async {
    setState(() => _isProcessing = true);
    try {
      await FirebaseFirestore.instance
          .collection('requests')
          .doc(widget.requestId)
          .update({
        'paymentMethod': 'card',
        'paymentStatus': 'awaiting_provider',
        'totalPaid': _totalPrice,
        if (_selectedCardId != null) 'savedCardId': _selectedCardId,
      });
      // Don't call onPaymentComplete — wait for garage to confirm card machine payment
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Payment failed. Try again.")),
        );
      }
    }
  }

  // ── Route to correct payment handler ────────────────────────────────────────
  Future<void> _handlePayment() async {
    if (_selectedMethod == 'cash') {
      await _submitCashPayment();
    } else if (_selectedMethod == 'paypal') {
      await _startPayPalPayment();
    } else {
      await _submitCardPayment();
    }
  }

  // ── Add card bottom sheet ────────────────────────────────────────────────────
  void _showAddCardBottomSheet(BuildContext context, String uid) {
    final holderNameController = TextEditingController();
    final cardNumberController = TextEditingController();
    final expiryController = TextEditingController();
    final cvvController = TextEditingController();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 24,
              ),
              decoration: BoxDecoration(
                color: AppTheme.getBg(isDark),
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Add New Card",
                      style: TextStyle(
                        color: AppTheme.getTextPrimary(isDark),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: holderNameController,
                      label: "Cardholder Name",
                      isDark: isDark,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: cardNumberController,
                      label: "Card Number",
                      isDark: isDark,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: expiryController,
                            label: "MM/YY",
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: cvvController,
                            label: "CVV",
                            isDark: isDark,
                            obscureText: true,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: isSaving
                            ? null
                            : () async {
                          final num =
                          cardNumberController.text.trim();
                          if (num.length < 4) return;
                          setModalState(() => isSaving = true);
                          try {
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(uid)
                                .collection('savedCards')
                                .add({
                              'holderName':
                              holderNameController.text.trim(),
                              'last4': num.substring(num.length - 4),
                              'createdAt':
                              FieldValue.serverTimestamp(),
                            });
                            if (ctx.mounted) Navigator.pop(ctx);
                          } catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content:
                                  Text("Failed to save card"),
                                ),
                              );
                            }
                          } finally {
                            if (ctx.mounted) {
                              setModalState(() => isSaving = false);
                            }
                          }
                        },
                        child: isSaving
                            ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                            : const Text(
                          "Save Card",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required bool isDark,
    bool obscureText = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: TextStyle(color: AppTheme.getTextPrimary(isDark)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppTheme.getTextDim(isDark)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.white24 : Colors.grey.shade300,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.accent),
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = AppTheme.getTextPrimary(isDark);
    final dimColor = AppTheme.getTextDim(isDark);
    final rawServiceType = (widget.reqData['serviceType'] ?? '').toString();
    final providerName = widget.reqData['garageName'] ??
        widget.reqData['providerName'] ??
        'Service Provider';
    final isGarage = widget.reqData['providerRole'] == 'garage';
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (_isLoadingRates) {
      return Container(
        color: AppTheme.getBg(isDark),
        child: const Center(
          child: CircularProgressIndicator(color: AppTheme.accent),
        ),
      );
    }

    return Container(
      color: AppTheme.getBg(isDark),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // ── Header ────────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accent.withValues(alpha: 0.1),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: AppTheme.accent,
                  size: 42,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                loc.tr('payment'),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
              Text(
                rawServiceType.toUpperCase().replaceAll('_', ' '),
                style: TextStyle(
                  color: dimColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 20),

              // ── Provider info ─────────────────────────────────────────────
              GlassCard(
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor:
                      AppTheme.accent.withValues(alpha: 0.2),
                      child: Icon(
                        isGarage
                            ? Icons.store_rounded
                            : Icons.local_shipping_rounded,
                        color: AppTheme.accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            providerName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: textColor,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            isGarage ? "Garage Service" : "Carrier Service",
                            style: TextStyle(color: dimColor, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Price breakdown ───────────────────────────────────────────
              GlassCard(
                child: Column(
                  children: [
                    _PriceRow(
                      label: loc.tr('baseCharge'),
                      value: "LKR ${_baseCharge.toStringAsFixed(0)}",
                      textColor: textColor,
                      dimColor: dimColor,
                    ),
                    if (_computedDistanceKm > 0) ...[
                      const SizedBox(height: 8),
                      _PriceRow(
                        label:
                        "${loc.tr('distance')} (${_computedDistanceKm.toStringAsFixed(1)} km × ${_perKmRate.toStringAsFixed(0)} ${loc.tr('perKm')})",
                        value:
                        "LKR ${_distanceCharge.toStringAsFixed(0)}",
                        textColor: textColor,
                        dimColor: dimColor,
                      ),
                    ],
                    Divider(
                      height: 24,
                      color: isDark ? Colors.white10 : Colors.grey.shade200,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          loc.tr('total'),
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          "LKR ${_totalPrice.toStringAsFixed(0)}",
                          style: const TextStyle(
                            color: AppTheme.accent,
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                          ),
                        ),
                      ],
                    ),
                    // PayPal USD note
                    if (_selectedMethod == 'paypal') ...[
                      const SizedBox(height: 8),
                      Text(
                        "≈ USD ${_totalPriceUSD.toStringAsFixed(2)} (PayPal charges in USD)",
                        style: TextStyle(color: dimColor, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Payment method selection ───────────────────────────────────
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  loc.tr('selectPayment'),
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Cash
              _PaymentMethodCard(
                icon: Icons.payments_rounded,
                title: loc.tr('cash'),
                subtitle: loc.tr('payDirectly'),
                isSelected: _selectedMethod == 'cash',
                isDark: isDark,
                onTap: () => setState(() {
                  _selectedMethod = 'cash';
                  _selectedCardId = null;
                }),
              ),
              const SizedBox(height: 10),

              // PayPal
              _PaymentMethodCard(
                icon: Icons.account_balance_wallet_rounded,
                title: "PayPal",
                subtitle: "Pay securely via PayPal",
                isSelected: _selectedMethod == 'paypal',
                isDark: isDark,
                trailing: _PayPalBadge(),
                onTap: () => setState(() {
                  _selectedMethod = 'paypal';
                  _selectedCardId = null;
                }),
              ),
              const SizedBox(height: 10),

              // Card (garage only — they have card machines)
              if (isGarage) ...[
                _PaymentMethodCard(
                  icon: Icons.credit_card_rounded,
                  title: loc.tr('card'),
                  subtitle: "Pay via garage card machine",
                  isSelected: _selectedMethod == 'card',
                  isDark: isDark,
                  onTap: () => setState(() => _selectedMethod = 'card'),
                ),
              ],

              // ── Saved cards (only when card method selected) ───────────────
              if (_selectedMethod == 'card' && uid != null) ...[
                const SizedBox(height: 16),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .collection('savedCards')
                      .snapshots(),
                  builder: (context, snap) {
                    final cards = snap.data?.docs ?? [];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (cards.isNotEmpty) ...[
                          Text(
                            loc.tr('savedCards'),
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...cards.map((doc) {
                            final data =
                            doc.data() as Map<String, dynamic>;
                            final isSelected = _selectedCardId == doc.id;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: GestureDetector(
                                onTap: () => setState(
                                        () => _selectedCardId = doc.id),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppTheme.accent
                                        .withValues(alpha: 0.05)
                                        : AppTheme.getCard(isDark),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppTheme.accent
                                          : (isDark
                                          ? Colors.white10
                                          : Colors.grey.shade200),
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.credit_card,
                                        color: isSelected
                                            ? AppTheme.accent
                                            : dimColor,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "•••• ${data['last4']}",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: textColor,
                                              ),
                                            ),
                                            Text(
                                              data['holderName'] ?? '',
                                              style: TextStyle(
                                                color: dimColor,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        const Icon(Icons.check_circle,
                                            color: AppTheme.accent),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: () => _showAddCardBottomSheet(context, uid),
                          child: Container(
                            padding:
                            const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color:
                              AppTheme.accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.accent
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.add_circle_outline_rounded,
                                  color: AppTheme.accent,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Add New Card",
                                  style: TextStyle(
                                    color: AppTheme.accent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],

              const SizedBox(height: 24),

              // ── Pay button ────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedMethod == 'paypal'
                        ? const Color(0xFF003087) // PayPal navy
                        : AppTheme.accent,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _isProcessing ? null : _handlePayment,
                  child: _isProcessing
                      ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : _buildPayButtonLabel(loc),
                ),
              ),

              if (_selectedMethod == 'cash') ...[
                const SizedBox(height: 12),
                Text(
                  "After you hand over cash, the provider will confirm receipt to complete payment.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: dimColor, fontSize: 12),
                ),
              ],

              if (_selectedMethod == 'card' && isGarage) ...[
                const SizedBox(height: 12),
                Text(
                  "The garage will process your card on their machine and confirm payment.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: dimColor, fontSize: 12),
                ),
              ],

              if (_selectedMethod == 'paypal') ...[
                const SizedBox(height: 12),
                Text(
                  "You'll be redirected to PayPal to complete payment securely.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: dimColor, fontSize: 12),
                ),
              ],

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPayButtonLabel(AppLocalizations loc) {
    switch (_selectedMethod) {
      case 'cash':
        return Text(
          loc.tr('confirmCash'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 15,
          ),
        );
      case 'paypal':
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.lock_rounded, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text(
              "Pay with PayPal",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ],
        );
      default:
        return Text(
          "${loc.tr('payNow')} LKR ${_totalPrice.toStringAsFixed(0)}",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 15,
          ),
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PayPal WebView Screen
// ─────────────────────────────────────────────────────────────────────────────
class _PayPalWebView extends StatefulWidget {
  final String approvalUrl;
  final String successUrlFragment;
  final String cancelUrlFragment;

  const _PayPalWebView({
    required this.approvalUrl,
    required this.successUrlFragment,
    required this.cancelUrlFragment,
  });

  @override
  State<_PayPalWebView> createState() => _PayPalWebViewState();
}

class _PayPalWebViewState extends State<_PayPalWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) => setState(() => _isLoading = false),
          onNavigationRequest: (request) {
            final url = request.url;
            // Success — user approved on PayPal
            if (url.contains(widget.successUrlFragment)) {
              Navigator.pop(context, true);
              return NavigationDecision.prevent;
            }
            // Cancel — user cancelled on PayPal
            if (url.contains(widget.cancelUrlFragment)) {
              Navigator.pop(context, false);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.approvalUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("PayPal Payment"),
        backgroundColor: const Color(0xFF003087),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF009CDE)),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PayPal Badge widget
// ─────────────────────────────────────────────────────────────────────────────
class _PayPalBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF003087),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        "PayPal",
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper widgets
// ─────────────────────────────────────────────────────────────────────────────
class _PriceRow extends StatelessWidget {
  final String label, value;
  final Color textColor, dimColor;

  const _PriceRow({
    required this.label,
    required this.value,
    required this.textColor,
    required this.dimColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(child: Text(label, style: TextStyle(color: dimColor, fontSize: 13))),
        Text(value, style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final bool isSelected, isDark;
  final VoidCallback onTap;
  final Widget? trailing;

  const _PaymentMethodCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accent.withValues(alpha: 0.05)
              : AppTheme.getCard(isDark),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppTheme.accent
                : (isDark ? Colors.white10 : Colors.grey.shade200),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.accent.withValues(alpha: 0.2)
                    : (isDark ? Colors.white10 : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? AppTheme.accent
                    : (isDark ? Colors.white54 : Colors.grey),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.getTextPrimary(isDark),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.getTextDim(isDark),
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              trailing!,
              const SizedBox(width: 8),
            ],
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: isSelected
                  ? AppTheme.accent
                  : (isDark ? Colors.white24 : Colors.grey.shade300),
            ),
          ],
        ),
      ),
    );
  }
}