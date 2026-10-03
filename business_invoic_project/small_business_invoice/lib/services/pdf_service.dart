import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfService {
  static Future<Uint8List> generateInvoicePdf(Map<String, dynamic> saleDetails) async {
    final pdf = pw.Document();

    final sale = saleDetails['sale'];
    final List items = saleDetails['items'];
    final store = saleDetails['store'];

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
                headers: ['#', 'Item', 'Qty', 'Unit Price (Rs.)', 'SubTotal (Rs.)'],
                data: List.generate(items.length, (index) {
                  final item = items[index];
                  return [
                    (index + 1).toString(),
                    item['ProductName'] ?? 'Product',
                    item['Quantity'].toString(),
                    (item['UnitPrice'] as num).toStringAsFixed(2),
                    (item['SubTotal'] as num).toStringAsFixed(2),
                  ];
                }),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blue),
                cellAlignment: pw.Alignment.centerLeft,
              ),
              pw.SizedBox(height: 15),

              // Summary
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Total Amount: Rs. ${(sale['TotalAmount'] as num).toStringAsFixed(2)}',
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text('Discount: Rs. ${(sale['TotalDiscount'] as num).toStringAsFixed(2)}'),
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