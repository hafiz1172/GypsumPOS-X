import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../models/invoice.dart';

class ExportService {
  static const String workshopName = "POP KHATA WORKSHOP";
  static const String workshopAddress = "Main Market, Lahore";
  static const String workshopPhone = "0300-1234567";

  // ==========================================
  // 1. RAWBT THERMAL TEXT FORMAT (32-Column)
  // ==========================================
  static Future<void> shareAsTextForThermal(Invoice invoice) async {
    StringBuffer sb = StringBuffer();

    // Center alignment helper (32 columns max)
    String centerText(String text) {
      if (text.length >= 32) return text.substring(0, 32);
      int leftPad = ((32 - text.length) / 2).floor();
      return text.padLeft(leftPad + text.length).padRight(32);
    }

    String rightAlign(String left, String right) {
      int space = 32 - left.length - right.length;
      if (space < 1) space = 1;
      return left + (' ' * space) + right;
    }

    // Header
    sb.writeln(centerText(workshopName));
    sb.writeln(centerText(workshopAddress));
    sb.writeln(centerText("Ph: $workshopPhone"));
    sb.writeln("-" * 32);
    
    // Bill Info
    String formattedDate = DateFormat('dd-MM-yy hh:mm a').format(DateTime.parse(invoice.date));
    sb.writeln("Bill No: ${invoice.invoiceNumber}");
    sb.writeln("Date: $formattedDate");
    sb.writeln("Customer: ${invoice.customerName}");
    sb.writeln("-" * 32);

    // Items
    sb.writeln(rightAlign("Item", "Total"));
    for (var item in invoice.items) {
      // Line 1: Item Name (truncated if too long)
      String itemName = item.productName.length > 32 ? item.productName.substring(0, 32) : item.productName;
      sb.writeln(itemName);
      // Line 2: Qty x Rate             Total
      String qtyRate = "  ${item.quantity} x Rs.${item.rate.toStringAsFixed(0)}";
      String total = "Rs.${item.total.toStringAsFixed(0)}";
      sb.writeln(rightAlign(qtyRate, total));
    }
    sb.writeln("-" * 32);

    // Totals
    sb.writeln(rightAlign("SubTotal:", "Rs.${invoice.subTotal.toStringAsFixed(0)}"));
    sb.writeln(rightAlign("Cash Rcvd:", "Rs.${invoice.cashReceived.toStringAsFixed(0)}"));
    if (invoice.udharAmount > 0) {
      sb.writeln(rightAlign("Udhar Due:", "Rs.${invoice.udharAmount.toStringAsFixed(0)}"));
    }
    sb.writeln("-" * 32);
    sb.writeln(centerText("Thank You!"));
    sb.writeln("\n\n\n"); // Auto-feed for cutter

    // Share Text (RawBT isay intercept kar lega)
    await Share.share(sb.toString(), subject: 'Invoice ${invoice.invoiceNumber}');
  }

  // ==========================================
  // 2. WHATSAPP PDF FORMAT
  // ==========================================
  static Future<void> shareAsPdf(Invoice invoice) async {
    final pdf = pw.Document();
    String formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(invoice.date));

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // PDF Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(workshopName, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.Text(workshopAddress, style: const pw.TextStyle(fontSize: 14)),
                    pw.Text("Ph: $workshopPhone", style: const pw.TextStyle(fontSize: 14)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("Bill No: ${invoice.invoiceNumber}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text("Date: $formattedDate"),
                    ],
                  ),
                  pw.Text("Customer: ${invoice.customerName}", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Divider(),
              pw.SizedBox(height: 10),

              // Items Table
              pw.TableHelper.fromTextArray(
                context: context,
                border: pw.TableBorder.all(width: 0.5),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                data: <List<String>>[
                  ['Description', 'Qty', 'Rate', 'Total'],
                  ...invoice.items.map((item) => [
                        item.productName,
                        item.quantity.toString(),
                        item.rate.toStringAsFixed(0),
                        item.total.toStringAsFixed(0),
                      ]),
                ],
              ),
              pw.SizedBox(height: 20),

              // Totals Section
              pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text("SubTotal: Rs. ${invoice.subTotal.toStringAsFixed(0)}", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.Text("Cash Received: Rs. ${invoice.cashReceived.toStringAsFixed(0)}", style: const pw.TextStyle(fontSize: 14, color: PdfColors.green700)),
                    if (invoice.udharAmount > 0)
                      pw.Text("Udhar (Due): Rs. ${invoice.udharAmount.toStringAsFixed(0)}", style: pw.TextStyle(fontSize: 16, color: PdfColors.red700, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    // Save and Share PDF
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: '${invoice.invoiceNumber}_${invoice.customerName}.pdf',
    );
  }
}
