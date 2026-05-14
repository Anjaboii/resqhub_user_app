import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

/// Generates a professional PDF invoice for completed ResQHub services.
class InvoicePdfService {
  /// Main entry: builds the full invoice PDF and returns raw bytes.
  static Future<Uint8List> generateInvoice({
    required Map<String, dynamic> jobData,
    required String invoiceId,
  }) async {
    final pdf = pw.Document();

    // ── Extract data ──────────────────────────────────────────────────────────
    final String status = (jobData['status'] ?? 'completed').toString();
    final String serviceType = (jobData['serviceType'] ?? '').toString();
    final String providerRole = (jobData['providerRole'] ?? '').toString();
    final bool isGarage = providerRole == 'garage' ||
        ['battery', 'lockout', 'engine', 'flat_tire', 'flatTire'].contains(serviceType.toLowerCase());

    final String providerName = jobData['garageName'] ??
        jobData['providerName'] ?? 'Service Provider';
    final String providerPhone = jobData['providerPhone'] ?? '';
    final String userName = jobData['userName'] ?? 'Customer';
    final String userPhone = jobData['userPhone'] ?? '';
    final String locationText = jobData['locationText'] ?? '';

    final vehicleMap = jobData['vehicle'] as Map<String, dynamic>? ?? {};
    final String vehicleName = vehicleMap['name'] ?? 'N/A';
    final String vehiclePlate = vehicleMap['plate'] ?? 'N/A';

    final double totalPaid = (jobData['totalPaid'] as num?)?.toDouble() ??
        (jobData['price'] as num?)?.toDouble() ?? 0;
    final String paymentMethod = jobData['paymentMethod'] ?? 'cash';

    // Parse date
    final dynamic createdAt = jobData['createdAt'];
    final dynamic paidAt = jobData['paidAt'];
    String dateStr = 'N/A';
    String paidDateStr = 'N/A';
    if (createdAt != null) {
      try {
        final dt = createdAt.toDate();
        dateStr = DateFormat('MMM dd, yyyy – hh:mm a').format(dt);
      } catch (_) {}
    }
    if (paidAt != null) {
      try {
        final dt = paidAt.toDate();
        paidDateStr = DateFormat('MMM dd, yyyy – hh:mm a').format(dt);
      } catch (_) {}
    }

    // ── Theme colors ──────────────────────────────────────────────────────────
    final accentColor = PdfColor.fromHex('#648F3C');
    final dimText = PdfColor.fromHex('#94A3B8');

    // ── Carrier pricing breakdown ─────────────────────────────────────────────
    final double baseCharge = (jobData['baseCharge'] as num?)?.toDouble() ?? 0;
    final double perKmRate = (jobData['perKmRate'] as num?)?.toDouble() ?? 0;
    final double distanceKm = (jobData['distanceKm'] as num?)?.toDouble() ?? 0;
    final double distanceCharge = distanceKm * perKmRate;


    // ── Garage bill items ─────────────────────────────────────────────────────
    // Partner app saves: parts: [{name, price}], serviceCharge, partsTotal
    final List<dynamic> billItems = jobData['parts'] as List<dynamic>? ?? [];
    final double serviceCharge = (jobData['serviceCharge'] as num?)?.toDouble() ?? 0;
    final double partsTotal = (jobData['partsTotal'] as num?)?.toDouble() ?? 0;
    final String garageNotes = jobData['garageNotes']?.toString() ?? '';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          // ─── Header ───────────────────────────────────────────────────
          _buildHeader(accentColor, invoiceId, dateStr),
          pw.SizedBox(height: 24),

          // ─── Provider & Customer Info ──────────────────────────────────
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: _buildInfoBlock(
                'SERVICE PROVIDER',
                [providerName, providerPhone, isGarage ? 'Garage Service' : 'Carrier Service'],
                accentColor, dimText,
              )),
              pw.SizedBox(width: 20),
              pw.Expanded(child: _buildInfoBlock(
                'CUSTOMER',
                [userName, userPhone, locationText],
                accentColor, dimText,
              )),
            ],
          ),
          pw.SizedBox(height: 20),

          // ─── Vehicle & Service Info ────────────────────────────────────
          _buildSection('SERVICE DETAILS', accentColor),
          pw.SizedBox(height: 8),
          _buildDetailRow('Service Type', serviceType.toUpperCase().replaceAll('_', ' '), dimText),
          _buildDetailRow('Vehicle', '$vehicleName ($vehiclePlate)', dimText),
          _buildDetailRow('Status', status.toUpperCase(), dimText),
          _buildDetailRow('Location', locationText, dimText),
          if (paymentMethod.isNotEmpty)
            _buildDetailRow('Payment Method', paymentMethod.toUpperCase(), dimText),
          if (paidDateStr != 'N/A')
            _buildDetailRow('Paid At', paidDateStr, dimText),
          pw.SizedBox(height: 24),

          // ─── Billing Breakdown ────────────────────────────────────────
          _buildSection('BILLING BREAKDOWN', accentColor),
          pw.SizedBox(height: 8),

          if (isGarage && billItems.isNotEmpty) ...[
            // Garage: itemized parts table
            _buildGarageBillTable(billItems, serviceCharge, partsTotal, totalPaid, accentColor, dimText),
            if (garageNotes.isNotEmpty) ...[
              pw.SizedBox(height: 12),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: dimText, width: 0.5),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Garage Notes:', style: pw.TextStyle(fontSize: 9, color: dimText, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text(garageNotes, style: pw.TextStyle(fontSize: 9, color: dimText)),
                  ],
                ),
              ),
            ],
          ] else if (isGarage && billItems.isEmpty) ...[
            // Garage with no itemized bill — show flat total
            _buildBillRow('Service Charge', totalPaid, dimText),
            pw.Divider(color: dimText, thickness: 0.5),
            _buildBillRow('TOTAL', totalPaid, accentColor, isBold: true, fontSize: 14),
          ] else ...[
            // Carrier: base + distance
            _buildCarrierBillTable(baseCharge, perKmRate, distanceKm, distanceCharge, totalPaid, accentColor, dimText),
          ],
          pw.SizedBox(height: 32),

          // ─── Footer ───────────────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F0FDF4'),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              children: [
                pw.Icon(pw.IconData(0xe876), size: 18, color: accentColor),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pw.Text(
                    'Thank you for using ResQHub! We appreciate your trust in our roadside assistance network.',
                    style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#166534')),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Center(
            child: pw.Text(
              'ResQHub — Your Trusted Roadside Assistance Partner',
              style: pw.TextStyle(fontSize: 8, color: dimText),
            ),
          ),
          pw.Center(
            child: pw.Text(
              'Invoice #$invoiceId • Generated on ${DateFormat('MMM dd, yyyy').format(DateTime.now())}',
              style: pw.TextStyle(fontSize: 7, color: dimText),
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  // ─── Header ─────────────────────────────────────────────────────────────────
  static pw.Widget _buildHeader(PdfColor accent, String invoiceId, String date) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: accent,
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('ResQHub', style: pw.TextStyle(
                fontSize: 26, fontWeight: pw.FontWeight.bold, color: PdfColors.white,
              )),
              pw.SizedBox(height: 4),
              pw.Text('SERVICE INVOICE', style: pw.TextStyle(
                fontSize: 11, color: PdfColors.white, letterSpacing: 3,
              )),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('Invoice #', style: pw.TextStyle(fontSize: 9, color: PdfColors.white)),
              pw.Text(invoiceId.length > 8 ? invoiceId.substring(0, 8).toUpperCase() : invoiceId.toUpperCase(),
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
              pw.SizedBox(height: 4),
              pw.Text(date, style: pw.TextStyle(fontSize: 8, color: PdfColors.white)),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Info block ─────────────────────────────────────────────────────────────
  static pw.Widget _buildInfoBlock(String title, List<String> lines, PdfColor accent, PdfColor dim) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0'), width: 0.5),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 9, color: accent, fontWeight: pw.FontWeight.bold, letterSpacing: 1)),
          pw.SizedBox(height: 8),
          ...lines.where((l) => l.isNotEmpty).map((l) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Text(l, style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#1E293B'))),
          )),
        ],
      ),
    );
  }

  // ─── Section header ─────────────────────────────────────────────────────────
  static pw.Widget _buildSection(String title, PdfColor accent) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: pw.BoxDecoration(
        color: accent,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(title, style: pw.TextStyle(
        fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white, letterSpacing: 1.5,
      )),
    );
  }

  // ─── Detail row ─────────────────────────────────────────────────────────────
  static pw.Widget _buildDetailRow(String label, String value, PdfColor dim) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        children: [
          pw.SizedBox(width: 140, child: pw.Text(label, style: pw.TextStyle(fontSize: 10, color: dim))),
          pw.Expanded(child: pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
        ],
      ),
    );
  }

  // ─── Bill row ───────────────────────────────────────────────────────────────
  static pw.Widget _buildBillRow(String label, double amount, PdfColor color, {bool isBold = false, double fontSize = 11}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(
            fontSize: fontSize, color: color,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          )),
          pw.Text('LKR ${amount.toStringAsFixed(2)}', style: pw.TextStyle(
            fontSize: fontSize, color: color,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          )),
        ],
      ),
    );
  }

  // ─── Carrier billing table ──────────────────────────────────────────────────
  static pw.Widget _buildCarrierBillTable(
    double baseCharge, double perKmRate, double distanceKm,
    double distanceCharge, double total,
    PdfColor accent, PdfColor dim,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColor.fromHex('#E2E8F0'), width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(4),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(2),
      },
      children: [
        // Header row
        pw.TableRow(
          decoration: pw.BoxDecoration(color: accent),
          children: [
            _tableHeaderCell('Description'),
            _tableHeaderCell('Details'),
            _tableHeaderCell('Amount (LKR)', align: pw.TextAlign.right),
          ],
        ),
        // Base Charge
        _tableDataRow('Base Service Charge', '', baseCharge),
        // Distance
        if (distanceKm > 0)
          _tableDataRow(
            'Distance Charge',
            '${distanceKm.toStringAsFixed(1)} km × ${perKmRate.toStringAsFixed(0)}/km',
            distanceCharge,
          ),
        // Total
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F0FDF4')),
          children: [
            _tableTotalCell('TOTAL', accent),
            _tableTotalCell('', accent),
            _tableTotalCell('LKR ${total.toStringAsFixed(2)}', accent, align: pw.TextAlign.right),
          ],
        ),
      ],
    );
  }

  // ─── Garage billing table ───────────────────────────────────────────────────
  static pw.Widget _buildGarageBillTable(
    List<dynamic> items, double serviceCharge, double partsTotal,
    double total, PdfColor accent, PdfColor dim,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColor.fromHex('#E2E8F0'), width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(1),
        1: const pw.FlexColumnWidth(5),
        2: const pw.FlexColumnWidth(2),
      },
      children: [
        // Header
        pw.TableRow(
          decoration: pw.BoxDecoration(color: accent),
          children: [
            _tableHeaderCell('#'),
            _tableHeaderCell('Item / Part'),
            _tableHeaderCell('Price (LKR)', align: pw.TextAlign.right),
          ],
        ),
        // Items — partner app saves [{name, price}]
        ...items.asMap().entries.map((entry) {
          final idx = entry.key + 1;
          final item = entry.value as Map<String, dynamic>;
          final name = (item['name'] ?? 'Part').toString();
          final price = (item['price'] as num?)?.toDouble() ?? 0;
          return pw.TableRow(children: [
            _tableCell(idx.toString()),
            _tableCell(name),
            _tableCell('LKR ${price.toStringAsFixed(2)}', align: pw.TextAlign.right),
          ]);
        }),
        // Parts Subtotal
        if (partsTotal > 0)
          pw.TableRow(
            decoration: pw.BoxDecoration(color: PdfColor.fromHex('#FFF7ED')),
            children: [
              _tableCell(''),
              _tableCell('Parts Subtotal', isBold: true),
              _tableCell('LKR ${partsTotal.toStringAsFixed(2)}', align: pw.TextAlign.right, isBold: true),
            ],
          ),
        // Service Charge
        if (serviceCharge > 0)
          pw.TableRow(
            decoration: pw.BoxDecoration(color: PdfColor.fromHex('#FFF7ED')),
            children: [
              _tableCell(''),
              _tableCell('Service Charge', isBold: true),
              _tableCell('LKR ${serviceCharge.toStringAsFixed(2)}', align: pw.TextAlign.right, isBold: true),
            ],
          ),
        // Grand Total
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F0FDF4')),
          children: [
            _tableTotalCell('', accent),
            _tableTotalCell('TOTAL', accent),
            _tableTotalCell('LKR ${total.toStringAsFixed(2)}', accent, align: pw.TextAlign.right),
          ],
        ),
      ],
    );
  }

  // ─── Table cell helpers ─────────────────────────────────────────────────────
  static pw.Widget _tableHeaderCell(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: pw.Text(text, style: pw.TextStyle(
        fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white,
      ), textAlign: align),
    );
  }

  static pw.Widget _tableCell(String text, {pw.TextAlign align = pw.TextAlign.left, bool isBold = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      child: pw.Text(text, style: pw.TextStyle(
        fontSize: 9, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ), textAlign: align),
    );
  }

  static pw.Widget _tableTotalCell(String text, PdfColor color, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: pw.Text(text, style: pw.TextStyle(
        fontSize: 11, fontWeight: pw.FontWeight.bold, color: color,
      ), textAlign: align),
    );
  }

  static pw.TableRow _tableDataRow(String desc, String details, double amount) {
    return pw.TableRow(children: [
      _tableCell(desc),
      _tableCell(details),
      _tableCell('LKR ${amount.toStringAsFixed(2)}', align: pw.TextAlign.right),
    ]);
  }

  static pw.TableRow _garageItemRow(String idx, String name, String qty, double unitPrice, double total) {
    return pw.TableRow(children: [
      _tableCell(idx),
      _tableCell(name),
      _tableCell(qty),
      _tableCell('LKR ${unitPrice.toStringAsFixed(2)}'),
      _tableCell('LKR ${total.toStringAsFixed(2)}', align: pw.TextAlign.right),
    ]);
  }
}
