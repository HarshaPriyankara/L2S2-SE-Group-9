import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfService {
  // 1.0 -> "1", 2.5 -> "2.5"
  static String _fmtQty(dynamic q) {
    final d = (q as num).toDouble();
    return d == d.roundToDouble() ? d.toInt().toString() : d.toString();
  }

  static Future<Uint8List> generateInvoicePdf(Map<String, dynamic> saleDetails) async {
    final pdf = pw.Document();

    final sale = saleDetails['sale'];
    final List items = saleDetails['items'];
    final store = saleDetails['store'];

    // Normal Total = Total + Discount  (Discount = sum of (Normal - Our) x Qty)
    final double total = (sale['TotalAmount'] as num).toDouble();
    final double discount = (sale['TotalDiscount'] as num).toDouble();
    final double normalTotal = total + discount;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header - Business Info
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        store['StoreName'] ?? 'EasyBill POS',
                        style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text('Invoice / Receipt'),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Invoice No: #${sale['BillID']}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('Date: ${sale['BillDate']}'),
                    ],
                  ),
                ],
              ),
              pw.Divider(thickness: 1),
              pw.SizedBox(height: 10),

              // Customer Details
              pw.Text('Customer Details:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('Name: ${sale['CustomerName'] ?? 'Cash Customer'}'),
              if (sale['ContactNumber'] != null) pw.Text('Phone: ${sale['ContactNumber']}'),
              pw.SizedBox(height: 15),

              // Items Table
              pw.TableHelper.fromTextArray(
                headers: [
                  '#',
                  'Item',
                  'Qty',
                  'Normal Price (Rs.)',
                  'Our Price (Rs.)',
                  'SubTotal (Rs.)'
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
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
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
                      pw.Text('Normal Total: Rs. ${normalTotal.toStringAsFixed(2)}'),
                      pw.Text('Discount: Rs. ${discount.toStringAsFixed(2)}'),
                      pw.Text(
                        'Total Amount: Rs. ${total.toStringAsFixed(2)}',
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text('Cash Paid: Rs. ${(sale['CashReceived'] as num).toStringAsFixed(2)}'),
                      pw.Text('Balance: Rs. ${(sale['Balance'] as num).toStringAsFixed(2)}'),
                    ],
                  ),
                ],
              ),
              pw.Spacer(),
              pw.Center(
                child: pw.Text('Thank you for your business!', style: pw.TextStyle(fontStyle: pw.FontStyle.italic)),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // Save invoice as a PDF file (user picks the location)
  static Future<String?> saveInvoicePdf(Map<String, dynamic> saleDetails) async {
    final bytes = await generateInvoicePdf(saleDetails);
    final billId = saleDetails['sale']['BillID'];

    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Invoice PDF',
      fileName: 'Invoice_$billId.pdf',
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
      onLayout: (PdfPageFormat format) async => pdfBytes,
    );
  }
}