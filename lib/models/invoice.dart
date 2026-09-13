import 'dart:convert';

class InvoiceItem {
  final int? productId;
  final String productName;
  final double rate;
  final int quantity;
  final double total;

  InvoiceItem({
    this.productId,
    required this.productName,
    required this.rate,
    required this.quantity,
    required this.total,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'rate': rate,
      'quantity': quantity,
      'total': total,
    };
  }

  factory InvoiceItem.fromMap(Map<String, dynamic> map) {
    return InvoiceItem(
      productId: map['productId'],
      productName: map['productName'],
      rate: (map['rate'] ?? 0.0).toDouble(),
      quantity: map['quantity'] ?? 1,
      total: (map['total'] ?? 0.0).toDouble(),
    );
  }
}

class Invoice {
  final int? id;
  final String invoiceNumber; // e.g. INV-000001
  final String customerName;
  final String date; // DateTime ko String bana kar save karein ge
  final double subTotal;
  final double cashReceived;
  final double udharAmount;
  final List<InvoiceItem> items;
  final int isSynced; // 0 = Sync nahi hua (Offline), 1 = Sync ho gya

  Invoice({
    this.id,
    required this.invoiceNumber,
    required this.customerName,
    required this.date,
    required this.subTotal,
    required this.cashReceived,
    required this.udharAmount,
    required this.items,
    this.isSynced = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoiceNumber': invoiceNumber,
      'customerName': customerName,
      'date': date,
      'subTotal': subTotal,
      'cashReceived': cashReceived,
      'udharAmount': udharAmount,
      // SQLite list save ni krta, isliye JSON text me convert kar rahay hain
      'items': jsonEncode(items.map((i) => i.toMap()).toList()),
      'isSynced': isSynced,
    };
  }

  factory Invoice.fromMap(Map<String, dynamic> map) {
    var itemsList = jsonDecode(map['items']) as List;
    return Invoice(
      id: map['id'],
      invoiceNumber: map['invoiceNumber'],
      customerName: map['customerName'],
      date: map['date'],
      subTotal: (map['subTotal'] ?? 0.0).toDouble(),
      cashReceived: (map['cashReceived'] ?? 0.0).toDouble(),
      udharAmount: (map['udharAmount'] ?? 0.0).toDouble(),
      items: itemsList.map((i) => InvoiceItem.fromMap(i)).toList(),
      isSynced: map['isSynced'] ?? 0,
    );
  }
}
