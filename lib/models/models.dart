class Product {
  final int? id;
  final String name;
  final double rate;
  final String emoji;
  final int stock;

  Product({
    this.id,
    required this.name,
    required this.rate,
    this.emoji = '📦',
    this.stock = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'rate': rate,
      'emoji': emoji,
      'stock': stock,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      name: map['name'],
      rate: (map['rate'] as num).toDouble(),
      emoji: map['emoji'] ?? '📦',
      stock: map['stock'] ?? 0,
    );
  }
}

class Customer {
  final int? id;
  final String name;
  final String phone;
  final double balance;

  Customer({
    this.id,
    required this.name,
    required this.phone,
    this.balance = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'balance': balance,
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'],
      name: map['name'],
      phone: map['phone'] ?? '',
      balance: (map['balance'] as num).toDouble(),
    );
  }
}

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});

  double get total => product.rate * quantity;
}

class Bill {
  final int? id;
  final int? customerId;
  final String customerName;
  final double totalAmount;
  final double cashPaid;
  final double udharAmount;
  final String type; // 'SALE' ya 'RETURN'
  final String timestamp;
  final List<BillItem> items;

  Bill({
    this.id,
    this.customerId,
    required this.customerName,
    required this.totalAmount,
    required this.cashPaid,
    required this.udharAmount,
    required this.type,
    required this.timestamp,
    this.items = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'customer_name': customerName,
      'total_amount': totalAmount,
      'cash_paid': cashPaid,
      'udhar_amount': udharAmount,
      'type': type,
      'timestamp': timestamp,
    };
  }

  factory Bill.fromMap(Map<String, dynamic> map, [List<BillItem> items = const []]) {
    return Bill(
      id: map['id'],
      customerId: map['customer_id'],
      customerName: map['customer_name'] ?? 'Walk-in',
      totalAmount: (map['total_amount'] as num).toDouble(),
      cashPaid: (map['cash_paid'] as num).toDouble(),
      udharAmount: (map['udhar_amount'] as num).toDouble(),
      type: map['type'] ?? 'SALE',
      timestamp: map['timestamp'] ?? '',
      items: items,
    );
  }
}

class BillItem {
  final int? id;
  final int billId;
  final String productName;
  final double rate;
  final int quantity;
  final double total;

  BillItem({
    this.id,
    required this.billId,
    required this.productName,
    required this.rate,
    required this.quantity,
    required this.total,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bill_id': billId,
      'product_name': productName,
      'rate': rate,
      'quantity': quantity,
      'total': total,
    };
  }

  factory BillItem.fromMap(Map<String, dynamic> map) {
    return BillItem(
      id: map['id'],
      billId: map['bill_id'],
      productName: map['product_name'],
      rate: (map['rate'] as num).toDouble(),
      quantity: map['quantity'],
      total: (map['total'] as num).toDouble(),
    );
  }
}
