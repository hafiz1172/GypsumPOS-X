import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/invoice.dart';

class ExportService {
  
  // Settings se workshop ka naam aur details nikalne ka function
  static Future<Map<String, String>> _getWorkshopDetails() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'shopName': prefs.getString('shopName') ?? 'ROYAL POP WORKSHOP',
      'tagline': prefs.getString('tagline') ?? 'Plaster & False Ceiling Works',
      'phone': prefs.getString('phone') ?? '',
      'address': prefs.getString('address') ?? '',
    };
  }

  // RawBT ya Print apps ke liye 32-column text format share karna
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

    // Header Details
    sb.writeln(centerText(details['shopName']!));
    if (details['tagline']!.isNotEmpty) sb.writeln(centerText(details['tagline']!));
    if (details['address']!.isNotEmpty) sb.writeln(centerText(details['address']!));
    if (details['phone']!.isNotEmpty) sb.writeln(centerText("Ph: ${details['phone']}"));
    sb.writeln("-" * 32);
    
    // Invoice Info
    String formattedDate = DateFormat('dd-MM-yy hh:mm a').format(DateTime.parse(invoice.date));
    sb.writeln("Bill No: ${invoice.invoiceNumber}");
    sb.writeln("Date: $formattedDate");
    sb.writeln("Customer: ${invoice.customerName}");
    sb.writeln("-" * 32);

    // Items List
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

    // Share text via Android Sharesheet (RawBT / Bluetooth Print select karne ke liye)
    await Share.share(sb.toString(), subject: 'Invoice ${invoice.invoiceNumber}');
  }
}
