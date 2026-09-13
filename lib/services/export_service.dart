import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/invoice.dart';

class ExportService {
  
  // Settings se data nikalne ka helper function
  static Future<Map<String, String>> _getWorkshopDetails() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'shopName': prefs.getString('shopName') ?? 'ROYAL POP WORKSHOP',
      'tagline': prefs.getString('tagline') ?? 'Plaster & False Ceiling Works',
      'phone': prefs.getString('phone') ?? '0300-0000000',
      'address': prefs.getString('address') ?? '',
    };
  }

  // ==========================================
  // 1. RAWBT THERMAL TEXT FORMAT (32-Column)
  // ==========================================
  static Future<void> shareAsTextForThermal(Invoice invoice) async {
    final details = await _getWorkshopDetails();
    StringBuffer sb = StringBuffer();

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

    // Dynamic Header
    sb.writeln(centerText(details['shopName']!));
    if (details['tagline']!.isNotEmpty) sb.writeln(centerText(details['tagline']!));
    if (details['address']!.isNotEmpty) sb.writeln(centerText(details['address']!));
    if (details['phone']!.isNotEmpty) sb.writeln(centerText("Ph: ${details['phone']}"));
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
      String itemName = item.productName.length > 32 ? item.productName.substring(0, 32) : item.productName;
      sb.writeln(itemName);
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
    sb.writeln("\n\n\n");

    await Share.share(sb.toString(), subject: 'Invoice ${invoice.invoiceNumber}');
  }

  // ==========================================
  // 2. WHATSAPP PDF FORMAT
  // ==========================================
  static Future<void> shareAsPdf(Invoice invoice) async {
    final details = await _getWorkshopDetails();
    final pdf = pw.Document();
    String formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(invoice.date));

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Dynamic PDF Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(details['shopName']!, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    if (details['tagline']!.isNotEmpty) pw.Text(details['tagline']!, style: const pw.TextStyle(fontSize: 14)),
                    if (details['address']!.isNotEmpty) pw.Text(details['address']!, style: const pw.TextStyle(fontSize: 14)),
                    if (details['phone']!.isNotEmpty) pw.Text("Ph: ${details['phone']}", style: const pw.TextStyle(fontSize: 14)),
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

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: '${invoice.invoiceNumber}_${invoice.customerName}.pdf',
    );
  }
}
