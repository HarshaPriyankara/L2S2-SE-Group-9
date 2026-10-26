import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'app_session.dart';

class PdfService {
  // 1.0 -> "1", 2.5 -> "2.5"
  static String _fmtQty(dynamic q) {
    final d = (q as num).toDouble();
    return d == d.roundToDouble() ? d.toInt().toString() : d.toString();
  }

  // 80mm thermal roll: 80mm wide, height = content height
  static const PdfPageFormat _roll80 = PdfPageFormat(
    80 * PdfPageFormat.mm,
    double.infinity,
    marginAll: 3 * PdfPageFormat.mm,
  );

  // Loads a TTF font from assets (null if the file is missing).
  // [optional] fonts are skipped silently when the file does not exist.
  static Future<pw.Font?> _loadFont(String path, {bool optional = false}) async {
    try {
      return pw.Font.ttf(await rootBundle.load(path));
    } catch (e) {
      if (!optional) debugPrint('PDF font load failed ($path): $e');
      return null;
    }
  }

  // Unicode fonts so the PDF has no "Helvetica has no Unicode support" warning.
  // Sinhala fonts are optional: they are used only when the files exist.
  static Future<pw.ThemeData> _buildTheme() async {
    final regular = await _loadFont('assests/fonts/NotoSans-Regular.ttf');
    final bold = await _loadFont('assests/fonts/NotoSans-Bold.ttf');
    final italic = await _loadFont('assests/fonts/NotoSans-Italic.ttf',
        optional: true);
    final boldItalic = await _loadFont('assests/fonts/NotoSans-BoldItalic.ttf',
        optional: true);
    final sinhala = await _loadFont('assests/fonts/NotoSansSinhala-Regular.ttf',
        optional: true);
    final sinhalaBold = await _loadFont(
        'assests/fonts/NotoSansSinhala-Bold.ttf',
        optional: true);

    if (regular == null || bold == null) {
      debugPrint('PDF: NotoSans fonts missing -> falling back to Helvetica');
      return pw.ThemeData(); // old behaviour
    }

    return pw.ThemeData.withFont(
      base: regular,
      bold: bold,
      // No italic font file -> use the normal one (so Helvetica is never used)
      italic: italic ?? regular,
      boldItalic: boldItalic ?? bold,
      fontFallback: [
        ?sinhala,
        ?sinhalaBold,
      ],
    );
  }

  /// Builds the invoice PDF using the business settings stored in
  /// saleDetails['store'] (name, phone, address, email, logo, footer,
  /// currency, invoice prefix, receipt size).
  static Future<Uint8List> generateInvoicePdf(
      Map<String, dynamic> saleDetails) async {
    final pdf = pw.Document(theme: await _buildTheme());

    final sale = saleDetails['sale'];
    final List items = saleDetails['items'];
    final Map store = saleDetails['store'];

    String text(String key) => (store[key] ?? '').toString().trim();

    final String storeName =
        text('StoreName').isEmpty ? 'EasyBill POS' : text('StoreName');
    final String contact = text('StoreContact');
    final String address = text('StoreAddress');
    final String email = text('StoreEmail');
    final String footer = text('FooterMessage');
    final String cur =
        text('CurrencySymbol').isEmpty ? 'Rs.' : text('CurrencySymbol');
    final bool thermal = text('ReceiptSize') == '80mm';

    final String invoiceNo = AppSession.formatInvoiceNo(
        sale['BillID'] as int, store['InvoicePrefix']?.toString());

    // Logo (stored as base64 text)
    pw.MemoryImage? logo;
    final String logoData = text('StoreLogo');
    if (logoData.isNotEmpty) {
      try {
        logo = pw.MemoryImage(base64Decode(logoData));
      } catch (_) {
        logo = null; // bad image -> just skip it
      }
    }

    // Normal Total = Total + Discount  (Discount = sum of (Normal - Our) x Qty)
    final double total = (sale['TotalAmount'] as num).toDouble();
    final double discount = (sale['TotalDiscount'] as num).toDouble();
    final double normalTotal = total + discount;
    final double cash = (sale['CashReceived'] as num).toDouble();
    final double balance = (sale['Balance'] as num).toDouble();

    final String customerName = (sale['CustomerName'] ?? 'Cash Customer').toString();
    final String customerPhone = (sale['ContactNumber'] ?? '').toString().trim();

    if (thermal) {
      pdf.addPage(pw.Page(
        pageFormat: _roll80,
        build: (pw.Context context) => _thermalLayout(
          storeName: storeName,
          contact: contact,
          address: address,
          email: email,
          footer: footer,
          cur: cur,
          logo: logo,
          invoiceNo: invoiceNo,
          date: sale['BillDate'].toString(),
          customerName: customerName,
          customerPhone: customerPhone,
          items: items,
          normalTotal: normalTotal,
          discount: discount,
          total: total,
          cash: cash,
          balance: balance,
        ),
      ));
    } else {
      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => _a4Layout(
          storeName: storeName,
          contact: contact,
          address: address,
          email: email,
          footer: footer,
          cur: cur,
          logo: logo,
          invoiceNo: invoiceNo,
          date: sale['BillDate'].toString(),
          customerName: customerName,
          customerPhone: customerPhone,
          items: items,
          normalTotal: normalTotal,
          discount: discount,
          total: total,
          cash: cash,
          balance: balance,
        ),
      ));
    }

    return pdf.save();
  }

  // ------------------------------------------------------------ A4
  static pw.Widget _a4Layout({
    required String storeName,
    required String contact,
    required String address,
    required String email,
    required String footer,
    required String cur,
    required pw.MemoryImage? logo,
    required String invoiceNo,
    required String date,
    required String customerName,
    required String customerPhone,
    required List items,
    required double normalTotal,
    required double discount,
    required double total,
    required double cash,
    required double balance,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Header - Business Info
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          // end = Invoice No / Date sit at the bottom, next to the divider
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Row(
              // end = store name block sits at the bottom, next to the divider
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                if (logo != null) ...[
                  pw.SizedBox(
                    width: 64,
                    height: 64,
                    child: pw.Image(logo, fit: pw.BoxFit.contain),
                  ),
                  pw.SizedBox(width: 12),
                ],
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      storeName,
                      style: pw.TextStyle(
                          fontSize: 22, fontWeight: pw.FontWeight.bold),
                    ),
                    if (address.isNotEmpty) pw.Text(address),
                    if (contact.isNotEmpty) pw.Text('Tel: $contact'),
                    if (email.isNotEmpty) pw.Text('Email: $email'),
                    pw.Text('Invoice / Receipt'),
                  ],
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Invoice No: $invoiceNo',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text('Date: $date'),
              ],
            ),
          ],
        ),
        pw.Divider(thickness: 1),
        pw.SizedBox(height: 10),

        // Customer Details
        pw.Text('Customer Details:',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.Text('Name: $customerName'),
        if (customerPhone.isNotEmpty) pw.Text('Phone: $customerPhone'),
        pw.SizedBox(height: 15),

        // Items Table
        pw.TableHelper.fromTextArray(
          headers: [
            '#',
            'Item',
            'Qty',
            'Normal Price ($cur)',
            'Our Price ($cur)',
            'SubTotal ($cur)'
          ],
          data: List.generate(items.length, (index) {
            final item = items[index];
            final unit = (item['UnitPrice'] as num).toDouble();
            // Old invoices have no NormalPrice -> fall back to unit price
            final normal = (item['NormalPrice'] as num?)?.toDouble() ?? unit;
            return [
              (index + 1).toString(),
              item['ProductName'] ?? 'Product',
              _fmtQty(item['Quantity']),
              normal.toStringAsFixed(2),
              unit.toStringAsFixed(2),
              (item['SubTotal'] as num).toStringAsFixed(2),
            ];
          }),
          headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blue),
          cellAlignment: pw.Alignment.centerLeft,
          columnWidths: {
            0: const pw.FixedColumnWidth(28), // #
            1: const pw.FlexColumnWidth(4), // Item
            2: const pw.FixedColumnWidth(40), // Qty
            3: const pw.FlexColumnWidth(2), // Normal Price
            4: const pw.FlexColumnWidth(2), // Our Price
            5: const pw.FlexColumnWidth(2), // SubTotal
          },
          cellAlignments: {
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerRight,
            4: pw.Alignment.centerRight,
            5: pw.Alignment.centerRight,
          },
        ),
        pw.SizedBox(height: 15),

        // Summary
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Normal Total: $cur ${normalTotal.toStringAsFixed(2)}'),
                pw.Text('Discount: $cur ${discount.toStringAsFixed(2)}'),
                pw.Text(
                  'Total Amount: $cur ${total.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text('Cash Paid: $cur ${cash.toStringAsFixed(2)}'),
                pw.Text('Balance: $cur ${balance.toStringAsFixed(2)}'),
              ],
            ),
          ],
        ),
        pw.Spacer(),
        if (footer.isNotEmpty)
          pw.Center(
            child: pw.Text(footer,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontStyle: pw.FontStyle.italic)),
          ),
      ],
    );
  }

  // ------------------------------------------------------------ 80mm receipt
  static pw.Widget _thermalLayout({
    required String storeName,
    required String contact,
    required String address,
    required String email,
    required String footer,
    required String cur,
    required pw.MemoryImage? logo,
    required String invoiceNo,
    required String date,
    required String customerName,
    required String customerPhone,
    required List items,
    required double normalTotal,
    required double discount,
    required double total,
    required double cash,
    required double balance,
  }) {
    const double small = 8;
    final pw.TextStyle base = const pw.TextStyle(fontSize: small);
    final pw.TextStyle bold =
        pw.TextStyle(fontSize: small, fontWeight: pw.FontWeight.bold);

    pw.Widget line(String left, String right, {pw.TextStyle? style}) {
      return pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(left, style: style ?? base),
          pw.Text(right, style: style ?? base),
        ],
      );
    }

    final pw.Widget divider = pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Divider(thickness: 0.5, height: 1),
    );

    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // Header
        if (logo != null)
          pw.Center(
            child: pw.SizedBox(
              height: 40,
              child: pw.Image(logo, fit: pw.BoxFit.contain),
            ),
          ),
        if (logo != null) pw.SizedBox(height: 4),
        pw.Text(storeName,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        if (address.isNotEmpty)
          pw.Text(address, textAlign: pw.TextAlign.center, style: base),
        if (contact.isNotEmpty)
          pw.Text('Tel: $contact', textAlign: pw.TextAlign.center, style: base),
        if (email.isNotEmpty)
          pw.Text(email, textAlign: pw.TextAlign.center, style: base),
        divider,

        // Invoice info
        pw.Text('Invoice: $invoiceNo', style: bold),
        pw.Text('Date: $date', style: base),
        pw.Text('Customer: $customerName', style: base),
        if (customerPhone.isNotEmpty)
          pw.Text('Phone: $customerPhone', style: base),
        divider,

        // Items: name, then "qty x price ........ subtotal"
        for (final item in items) ...[
          pw.Text((item['ProductName'] ?? 'Product').toString(), style: bold),
          line(
            '${_fmtQty(item['Quantity'])} x ${(item['UnitPrice'] as num).toStringAsFixed(2)}',
            (item['SubTotal'] as num).toStringAsFixed(2),
          ),
          pw.SizedBox(height: 3),
        ],
        divider,

        // Summary
        line('Normal Total', '$cur ${normalTotal.toStringAsFixed(2)}'),
        line('Discount', '$cur ${discount.toStringAsFixed(2)}'),
        pw.SizedBox(height: 2),
        line('TOTAL', '$cur ${total.toStringAsFixed(2)}',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 2),
        line('Cash Paid', '$cur ${cash.toStringAsFixed(2)}'),
        line('Balance', '$cur ${balance.toStringAsFixed(2)}'),

        if (footer.isNotEmpty) ...[
          divider,
          pw.Text(footer,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                  fontSize: small, fontStyle: pw.FontStyle.italic)),
        ],
        pw.SizedBox(height: 6),
      ],
    );
  }

  // Save invoice as a PDF file (user picks the location)
  static Future<String?> saveInvoicePdf(Map<String, dynamic> saleDetails) async {
    final bytes = await generateInvoicePdf(saleDetails);
    final billId = saleDetails['sale']['BillID'] as int;
    final prefix = saleDetails['store']['InvoicePrefix']?.toString();
    final niceName =
        AppSession.formatInvoiceNo(billId, prefix).replaceAll(RegExp(r'[^\w\-]'), '_');

    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Invoice PDF',
      fileName: 'Invoice_$niceName.pdf',
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (path == null) return null; // user cancelled

    final finalPath = path.toLowerCase().endsWith('.pdf') ? path : '$path.pdf';
    await File(finalPath).writeAsBytes(bytes);
    return finalPath;
  }

  // Open the saved PDF in the default PDF viewer
  static Future<void> openFile(String path) async {
    if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', path]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [path]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [path]);
    }
  }

  // PDF Preview and Print Preview
  static Future<void> printInvoice(Map<String, dynamic> saleDetails) async {
    final pdfBytes = await generateInvoicePdf(saleDetails);
    await Printing.layoutPdf(
      name: 'Invoice',
      onLayout: (PdfPageFormat format) async => pdfBytes,
    );
  }
}