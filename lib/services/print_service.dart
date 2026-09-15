import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class PrintService {
  static const int lineWidth = 32;

  // Center alignment helper
  static String centerText(String text) {
    if (text.length >= lineWidth) return text.substring(0, lineWidth);
    int leftPadding = (lineWidth - text.length) ~/ 2;
    int rightPadding = lineWidth - text.length - leftPadding;
    return (' ' * leftPadding) + text + (' ' * rightPadding);
  }

  // Two-column row helper (e.g. Total:      Rs 1200)
  static String twoColumnRow(String left, String right) {
    int spaceCount = lineWidth - (left.length + right.length);
    if (spaceCount < 1) spaceCount = 1;
    return left + (' ' * spaceCount) + right;
  }

  // 3-Column item row helper (Item, Qty, Total)
  static String formatItemRow(String name, int qty, double total) {
    String qtyStr = 'x$qty';
    String totalStr = total.toStringAsFixed(0);
    int rightPartLen = qtyStr.length + totalStr.length + 1;
    int maxNameLen = lineWidth - rightPartLen - 1;

    String truncatedName = name.length > maxNameLen ? name.substring(0, maxNameLen) : name;
    int spaceBetween = lineWidth - (truncatedName.length + qtyStr.length + totalStr.length);
    int midSpace = spaceBetween > 2 ? spaceBetween ~/ 2 : 1;
    int endSpace = spaceBetween - midSpace;

    return truncatedName + (' ' * midSpace) + qtyStr + (' ' * endSpace) + totalStr;
  }

  // Divider line
  static String divider([String char = '-']) => char * lineWidth;

  // Generate & Share Bill Receipt
  static Future<void> printBill(Bill bill) async {
    final prefs = await SharedPreferences.getInstance();
    final shopName = prefs.getString('shop_name') ?? 'ROYAL POP WORKSHOP';
    final shopTagline = prefs.getString('shop_tagline') ?? 'Deals in All POP Materials';
    final shopPhone = prefs.getString('shop_phone') ?? '0300-0000000';
    final shopAddress = prefs.getString('shop_address') ?? 'Main Workshop Market';

    final StringBuffer buffer = StringBuffer();

    // Header
    buffer.writeln(centerText(shopName));
    if (shopTagline.isNotEmpty) buffer.writeln(centerText(shopTagline));
    if (shopPhone.isNotEmpty) buffer.writeln(centerText("Ph: $shopPhone"));
    if (shopAddress.isNotEmpty) buffer.writeln(centerText(shopAddress));
    buffer.writeln(divider('='));

    // Meta Info
    String billTypeStr = bill.type == 'RETURN' ? '*** MAAL WAPSI ***' : 'SALE INVOICE';
    buffer.writeln(centerText(billTypeStr));
    buffer.writeln(twoColumnRow("Bill #: ${bill.id ?? '---'}", bill.timestamp.substring(0, 16)));
    buffer.writeln(twoColumnRow("Customer:", bill.customerName));
    buffer.writeln(divider('-'));

    // Table Header
    buffer.writeln(twoColumnRow("Item (Qty)", "Total"));
    buffer.writeln(divider('-'));

    // Items List
    for (var item in bill.items) {
      buffer.writeln(formatItemRow(item.productName, item.quantity, item.total));
    }
    buffer.writeln(divider('-'));

    // Calculations & Split
    buffer.writeln(twoColumnRow("KUL RAQAM:", "Rs ${bill.totalAmount.toStringAsFixed(0)}"));
    if (bill.type == 'SALE') {
      buffer.writeln(twoColumnRow("Naqad Mila:", "Rs ${bill.cashPaid.toStringAsFixed(0)}"));
      buffer.writeln(twoColumnRow("Baqaya Udhar:", "Rs ${bill.udharAmount.toStringAsFixed(0)}"));
    }
    buffer.writeln(divider('='));

    // Footer
    buffer.writeln(centerText("Shukriya! Dobara Tashreef Layen"));
    buffer.writeln('\n\n'); // Paper feed space

    // Share via intent to RawBT or other thermal printer apps
    await Share.share(buffer.toString(), subject: 'Invoice #${bill.id}');
  }
}
