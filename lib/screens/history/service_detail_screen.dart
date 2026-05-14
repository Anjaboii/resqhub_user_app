import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:printing/printing.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../services/invoice_pdf_service.dart';

class ServiceDetailScreen extends StatefulWidget {
  final Map<String, dynamic> jobData;
  final String? requestId;

  const ServiceDetailScreen({super.key, required this.jobData, this.requestId});

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  bool _isGeneratingPdf = false;

  Future<void> _downloadInvoice() async {
    setState(() => _isGeneratingPdf = true);
    try {
      final invoiceId = widget.requestId ??
          DateTime.now().millisecondsSinceEpoch.toString();

      // Fetch billing breakdown from Firestore settings (same logic as PaymentScreen)
      final jobData = Map<String, dynamic>.from(widget.jobData);

      // If billing breakdown data is missing, fetch from settings
      if (jobData['baseCharge'] == null) {
        await _fetchAndAttachRates(jobData);
      }

      final pdfBytes = await InvoicePdfService.generateInvoice(
        jobData: jobData,
        invoiceId: invoiceId,
      );

      if (!mounted) return;

      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'ResQHub_Invoice_${invoiceId.length > 8 ? invoiceId.substring(0, 8) : invoiceId}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate invoice: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  /// Fetch service rates from Firestore (mirrors PaymentScreen logic)
  Future<void> _fetchAndAttachRates(Map<String, dynamic> jobData) async {
    try {
      final st = (jobData['serviceType'] ?? '').toString().toLowerCase();
      final isGarage = jobData['providerRole'] == 'garage' ||
          ['battery', 'lockout', 'engine', 'flat_tire', 'flattire', 'flat tire',
           'mechanical', 'hybrid', 'electrical', 'other'].contains(st);

      // Platform fee
      final platformDoc = await FirebaseFirestore.instance
          .collection('settings').doc('platform_settings').get();
      double pFee = 250;
      if (platformDoc.exists) {
        pFee = (platformDoc.data()?['platformFee'] as num?)?.toDouble() ?? 250;
      }

      double base = 2000;
      double perKm = 100;

      if (isGarage) {
        final garageDoc = await FirebaseFirestore.instance
            .collection('settings').doc('garage_service_rates').get();
        if (garageDoc.exists) {
          final data = garageDoc.data()!;
          if (st == 'engine') base = (data['engineBase'] as num?)?.toDouble() ?? 5000;
          else if (st == 'battery') base = (data['batteryBase'] as num?)?.toDouble() ?? 1500;
          else if (st == 'lockout') base = (data['lockoutBase'] as num?)?.toDouble() ?? 1200;
          else base = (data['mechanicalBase'] as num?)?.toDouble() ?? 3000;
          perKm = (data['perKm'] as num?)?.toDouble() ?? 0;
        }
      } else if (st == 'fuel') {
        final fuelDoc = await FirebaseFirestore.instance
            .collection('settings').doc('fuel_prices').get();
        if (fuelDoc.exists) {
          base = (fuelDoc.data()!['fuelBase'] as num?)?.toDouble() ?? 1000;
          perKm = (fuelDoc.data()!['fuelPerKm'] as num?)?.toDouble() ?? 80;
        }
      } else {
        final serviceDoc = await FirebaseFirestore.instance
            .collection('settings').doc('service_rates').get();
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

      // Compute distance from price if available
      double distanceKm = (jobData['distanceKm'] as num?)?.toDouble() ?? 0;
      if (distanceKm == 0 && perKm > 0) {
        final totalPaid = (jobData['totalPaid'] as num?)?.toDouble() ??
            (jobData['price'] as num?)?.toDouble() ?? 0;
        if (totalPaid > base) {
          distanceKm = (totalPaid - base) / perKm;
        }
      }

      jobData['baseCharge'] = base;
      jobData['perKmRate'] = perKm;
      jobData['distanceKm'] = distanceKm;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = AppTheme.getTextPrimary(isDark);
    final dimColor = AppTheme.getTextDim(isDark);
    final vehicleMap = widget.jobData['vehicle'] as Map<String, dynamic>? ?? {};

    // 🎯 Get the dynamic status from Firestore
    final String status = (widget.jobData['status'] ?? 'completed').toString().toLowerCase();

    // 🎨 Determine status-specific colors
    final Color statusColor = status == 'completed' ? Colors.greenAccent : Colors.redAccent;
    final IconData statusIcon = status == 'completed' ? Icons.check_circle_rounded : Icons.cancel_rounded;

    return Scaffold(
      backgroundColor: AppTheme.getBg(isDark),
      appBar: AppBar(
        title: const Text("Trip Details", style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Download Invoice Button
          if (status == 'completed')
            _isGeneratingPdf
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          color: AppTheme.accent, strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.picture_as_pdf_rounded,
                        color: AppTheme.accent),
                    tooltip: 'Download Invoice',
                    onPressed: _downloadInvoice,
                  ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header Card with Dynamic Status
            GlassCard(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: AppTheme.accent,
                    backgroundImage: widget.jobData['providerPic'] != null && widget.jobData['providerPic'].toString().isNotEmpty
                        ? NetworkImage(widget.jobData['providerPic'])
                        : null,
                    child: widget.jobData['providerPic'] != null && widget.jobData['providerPic'].toString().isNotEmpty
                        ? null
                        : const Icon(Icons.person, color: Colors.black, size: 35),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    (widget.jobData['garageName']?.toString().isNotEmpty == true ? widget.jobData['garageName'] : null) ?? 
                    (widget.jobData['providerName']?.toString().isNotEmpty == true ? widget.jobData['providerName'] : null) ?? 
                    "Unknown Provider",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 8),

                  // 🏷️ Dynamic Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, color: statusColor, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          status.toUpperCase(),
                          style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // DATE & TIME Section
            () {
              final createdAt = widget.jobData['createdAt'];
              final completedAt = widget.jobData['completedAt'];
              String formatTs(dynamic ts) {
                if (ts == null) return 'N/A';
                if (ts is Timestamp) {
                  final dt = ts.toDate();
                  final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
                  final ampm = dt.hour >= 12 ? 'PM' : 'AM';
                  return '${dt.day}/${dt.month}/${dt.year} at ${h.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $ampm';
                }
                return ts.toString();
              }
              return GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("DATE & TIME", style: TextStyle(color: dimColor, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _row(Icons.calendar_today_rounded, "Requested", formatTs(createdAt), isDark),
                    if (completedAt != null) ...[
                      Divider(color: isDark ? Colors.white10 : Colors.grey.shade200, height: 32),
                      _row(Icons.check_circle_outline_rounded, "Completed", formatTs(completedAt), isDark),
                    ],
                  ],
                ),
              );
            }(),
            const SizedBox(height: 16),

            // ISSUE REPORTED Section
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("ISSUE REPORTED", style: TextStyle(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _row(Icons.report_problem_rounded, "Service Category", (widget.jobData['serviceType'] ?? "N/A").toString().toUpperCase(), isDark),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // VEHICLE INFO Section
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("VEHICLE INFO", style: TextStyle(color: dimColor, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _row(Icons.directions_car, "Model", vehicleMap['name'] ?? "N/A", isDark),
                  Divider(color: isDark ? Colors.white10 : Colors.grey.shade200, height: 32),
                  _row(Icons.tag, "Plate Number", vehicleMap['plate'] ?? "N/A", isDark),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // LOCATION & CONTACT Section
            GlassCard(
              child: Column(
                children: [
                  _row(Icons.location_on, "Location", widget.jobData['locationText'] ?? "N/A", isDark),
                  Divider(color: isDark ? Colors.white10 : Colors.grey.shade200, height: 32),
                  _row(
                    Icons.phone, 
                    "Provider Phone", 
                    (widget.jobData['garagePhone']?.toString().isNotEmpty == true ? widget.jobData['garagePhone'] : null) ?? 
                    (widget.jobData['providerPhone']?.toString().isNotEmpty == true ? widget.jobData['providerPhone'] : null) ?? 
                    "N/A", 
                    isDark
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // PAYMENT Section (NEW — non-invasive addition)
            if (status == 'completed' && (widget.jobData['totalPaid'] != null || widget.jobData['price'] != null))
              _buildPaymentSection(),

            // Download Invoice Button (NEW — non-invasive addition)
            if (status == 'completed') ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _isGeneratingPdf ? null : _downloadInvoice,
                  icon: _isGeneratingPdf
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.picture_as_pdf_rounded,
                          color: Colors.white),
                  label: Text(
                    _isGeneratingPdf ? 'Generating...' : 'Download Invoice PDF',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final d = widget.jobData;
    final st = (d['serviceType'] ?? '').toString().toLowerCase();
    final isGarage = d['providerRole'] == 'garage' ||
        ['battery', 'lockout', 'engine', 'flat_tire', 'flatTire',
         'mechanical', 'hybrid', 'electrical', 'other'].contains(st);
    final double totalPaid = (d['totalPaid'] as num?)?.toDouble() ??
        (d['price'] as num?)?.toDouble() ?? 0;
    final List<dynamic> parts = d['parts'] as List<dynamic>? ?? [];
    final double serviceCharge = (d['serviceCharge'] as num?)?.toDouble() ?? 0;
    final double partsTotal = (d['partsTotal'] as num?)?.toDouble() ?? 0;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("BILLING DETAILS",
              style: TextStyle(color: AppTheme.accent, fontSize: 11,
                  fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 16),

          if (isGarage && parts.isNotEmpty) ...[
            // ── Itemized parts list ──
            ...parts.asMap().entries.map((entry) {
              final item = entry.value as Map<String, dynamic>;
              final name = (item['name'] ?? 'Part').toString();
              final price = (item['price'] as num?)?.toDouble() ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 22, height: 22,
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text("${entry.key + 1}",
                            style: TextStyle(
                                color: AppTheme.accent,
                                fontSize: 10,
                                fontWeight: FontWeight.w800)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(name,
                          style: TextStyle(
                              color: AppTheme.getTextPrimary(isDark), fontSize: 13)),
                    ),
                    Text("LKR ${price.toStringAsFixed(0)}",
                        style: TextStyle(
                            color: AppTheme.getTextDim(isDark),
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            }),
            Divider(color: isDark ? Colors.white10 : Colors.grey.shade200, height: 20),
            // Parts subtotal
            _billLine("Parts Total", "LKR ${partsTotal.toStringAsFixed(0)}", isDark),
            if (serviceCharge > 0)
              _billLine("Service Charge", "LKR ${serviceCharge.toStringAsFixed(0)}", isDark),
            Divider(color: isDark ? Colors.white10 : Colors.grey.shade200, height: 20),
            // Grand total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("TOTAL",
                    style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 16,
                        fontWeight: FontWeight.w900)),
                Text("LKR ${totalPaid.toStringAsFixed(0)}",
                    style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 16,
                        fontWeight: FontWeight.w900)),
              ],
            ),
          ] else ...[
            // ── Simple total for carriers or garages without parts ──
            _row(Icons.payments_rounded, "Amount Paid",
                "LKR ${totalPaid.toStringAsFixed(0)}", isDark),
          ],

          if (d['paymentMethod'] != null) ...[
            Divider(color: isDark ? Colors.white10 : Colors.grey.shade200, height: 24),
            _row(Icons.credit_card_rounded, "Payment Method",
                (d['paymentMethod'] ?? 'cash').toString().toUpperCase(), isDark),
          ],
        ],
      ),
    );
  }

  Widget _billLine(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppTheme.getTextDim(isDark), fontSize: 12)),
          Text(value, style: TextStyle(color: AppTheme.getTextPrimary(isDark).withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value, bool isDark) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.accent, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: AppTheme.getTextDim(isDark), fontSize: 11)),
              Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.getTextPrimary(isDark))),
            ],
          ),
        ),
      ],
    );
  }
}