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
          ['battery', 'lockout', 'engine', 'flat_tire', 'flatTire'].contains(st);

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
      jobData['platformFee'] = pFee;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final vehicleMap = widget.jobData['vehicle'] as Map<String, dynamic>? ?? {};

    // 🎯 Get the dynamic status from Firestore
    final String status = (widget.jobData['status'] ?? 'completed').toString().toLowerCase();

    // 🎨 Determine status-specific colors
    final Color statusColor = status == 'completed' ? Colors.greenAccent : Colors.redAccent;
    final IconData statusIcon = status == 'completed' ? Icons.check_circle_rounded : Icons.cancel_rounded;

    return Scaffold(
      backgroundColor: AppTheme.bg,
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
                    backgroundColor: AppTheme.accent, // 🎨 Using your AppTheme accent
                    child: const Icon(Icons.person, color: Colors.black, size: 35),
                  ),
                  const SizedBox(height: 12),
                  Text(widget.jobData['providerName'] ?? "Rescuer",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),

                  const SizedBox(height: 8),

                  // 🏷️ Dynamic Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withOpacity(0.5)),
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

            // ISSUE REPORTED Section
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("ISSUE REPORTED", style: TextStyle(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _row(Icons.report_problem_rounded, "Service Category", (widget.jobData['serviceType'] ?? "FLAT TIRE").toString().toUpperCase()),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // VEHICLE INFO Section
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("VEHICLE INFO", style: TextStyle(color: AppTheme.textDim, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _row(Icons.directions_car, "Model", vehicleMap['name'] ?? "Suzuki Swift"),
                  const Divider(color: Colors.white10, height: 32),
                  _row(Icons.tag, "Plate Number", vehicleMap['plate'] ?? "555 - 6666"),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // LOCATION & CONTACT Section
            GlassCard(
              child: Column(
                children: [
                  _row(Icons.location_on, "Location", widget.jobData['locationText'] ?? "1600 Amphitheatre Pkwy, Mountain View"),
                  const Divider(color: Colors.white10, height: 32),
                  _row(Icons.phone, "Provider Phone", widget.jobData['providerPhone'] ?? "0774796913"),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // PAYMENT Section (NEW — non-invasive addition)
            if (status == 'completed' && (widget.jobData['totalPaid'] != null || widget.jobData['price'] != null))
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("PAYMENT", style: TextStyle(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _row(Icons.payments_rounded, "Amount Paid",
                        "LKR ${((widget.jobData['totalPaid'] as num?) ?? (widget.jobData['price'] as num?) ?? 0).toStringAsFixed(0)}"),
                    if (widget.jobData['paymentMethod'] != null) ...[
                      const Divider(color: Colors.white10, height: 24),
                      _row(Icons.credit_card_rounded, "Payment Method",
                          (widget.jobData['paymentMethod'] ?? 'cash').toString().toUpperCase()),
                    ],
                  ],
                ),
              ),

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

  Widget _row(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.accent, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppTheme.textDim, fontSize: 11)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
            ],
          ),
        ),
      ],
    );
  }
}