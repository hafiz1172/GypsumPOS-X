import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/models.dart';

class DBHelper {
  static final DBHelper instance = DBHelper._init();
  static Database? _database;

  DBHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('workshop_pos.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Products Table
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        rate REAL NOT NULL,
        emoji TEXT NOT NULL,
        stock INTEGER NOT NULL
      )
    ''');

    // Customers Table
    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        balance REAL NOT NULL
      )
    ''');

    // Bills Table
    await db.execute('''
      CREATE TABLE bills (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER,
        customer_name TEXT NOT NULL,
        total_amount REAL NOT NULL,
        cash_paid REAL NOT NULL,
        udhar_amount REAL NOT NULL,
        type TEXT NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');

    // Bill Items Table
    await db.execute('''
      CREATE TABLE bill_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bill_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        rate REAL NOT NULL,
        quantity INTEGER NOT NULL,
        total REAL NOT NULL,
        FOREIGN KEY (bill_id) REFERENCES bills (id) ON DELETE CASCADE
      )
    ''');

    // Default Seed Products
    await db.insert('products', {'name': 'POP Bag (Standard)', 'rate': 450.0, 'emoji': '🏗️', 'stock': 100});
    await db.insert('products', {'name': 'Ceiling Bracket L-Patti', 'rate': 35.0, 'emoji': '🔧', 'stock': 500});
    await db.insert('products', {'name': 'Wire Gauge Coil', 'rate': 1200.0, 'emoji': '🪢', 'stock': 40});
    await db.insert('products', {'name': 'Screws & Rawal Plug Box', 'rate': 280.0, 'emoji': '🔩', 'stock': 80});
  }

  // --- Product Methods ---
  Future<List<Product>> getProducts() async {
    final db = await instance.database;
    final maps = await db.query('products', orderBy: 'id DESC');
    return maps.map((m) => Product.fromMap(m)).toList();
  }

  Future<int> insertProduct(Product product) async {
    final db = await instance.database;
    return await db.insert('products', product.toMap());
  }

  // --- Customer & Ledger Methods ---
  Future<List<Customer>> getCustomers() async {
    final db = await instance.database;
    final maps = await db.query('customers', orderBy: 'balance DESC');
    return maps.map((m) => Customer.fromMap(m)).toList();
  }

  Future<int> insertCustomer(Customer customer) async {
    final db = await instance.database;
    return await db.insert('customers', customer.toMap());
  }

  Future<double> getMarketBaqaya() async {
    final db = await instance.database;
    final res = await db.rawQuery('SELECT SUM(balance) as total FROM customers WHERE balance > 0');
    return (res.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  // Wasooli Payment (Deduct customer's udhar balance)
  Future<void> recordPaymentCollection(int customerId, double amountPaid) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      final res = await txn.query('customers', where: 'id = ?', whereArgs: [customerId]);
      if (res.isNotEmpty) {
        double currentBal = (res.first['balance'] as num).toDouble();
        double updatedBal = (currentBal - amountPaid).clamp(0.0, double.infinity);
        await txn.update(
          'customers',
          {'balance': updatedBal},
          where: 'id = ?',
          whereArgs: [customerId],
        );
      }
    });
  }

  // --- Billing & Sales Return Transaction ---
  Future<int> createBill({
    required Bill bill,
    required List<CartItem> cartItems,
  }) async {
    final db = await instance.database;
    return await db.transaction((txn) async {
      final billId = await txn.insert('bills', bill.toMap());

      for (var item in cartItems) {
        await txn.insert('bill_items', {
          'bill_id': billId,
          'product_name': item.product.name,
          'rate': item.product.rate,
          'quantity': item.quantity,
          'total': item.total,
        });

        // Update Stock (+ on return, - on sale)
        int stockChange = bill.type == 'RETURN' ? item.quantity : -item.quantity;
        await txn.rawUpdate(
          'UPDATE products SET stock = stock + ? WHERE id = ?',
          [stockChange, item.product.id],
        );
      }

      // Update Customer Ledger Balance
      if (bill.customerId != null) {
        if (bill.type == 'SALE' && bill.udharAmount > 0) {
          await txn.rawUpdate(
            'UPDATE customers SET balance = balance + ? WHERE id = ?',
            [bill.udharAmount, bill.customerId],
          );
        } else if (bill.type == 'RETURN') {
          // Subtract return value from customer balance
          await txn.rawUpdate(
            'UPDATE customers SET balance = balance - ? WHERE id = ?',
            [bill.totalAmount, bill.customerId],
          );
        }
      }

      return billId;
    });
  }

  // --- Invoices & History ---
  Future<List<Bill>> getBills() async {
    final db = await instance.database;
    final billMaps = await db.query('bills', orderBy: 'id DESC');

    List<Bill> list = [];
    for (var b in billMaps) {
      final itemMaps = await db.query('bill_items', where: 'bill_id = ?', whereArgs: [b['id']]);
      final items = itemMaps.map((i) => BillItem.fromMap(i)).toList();
      list.add(Bill.fromMap(b, items));
    }
    return list;
  }

  Future<List<Bill>> getCustomerBills(int customerId) async {
    final db = await instance.database;
    final billMaps = await db.query('bills', where: 'customer_id = ?', whereArgs: [customerId], orderBy: 'id DESC');

    List<Bill> list = [];
    for (var b in billMaps) {
      final itemMaps = await db.query('bill_items', where: 'bill_id = ?', whereArgs: [b['id']]);
      final items = itemMaps.map((i) => BillItem.fromMap(i)).toList();
      list.add(Bill.fromMap(b, items));
    }
    return list;
  }

  // --- Aaj Ka Hisaab (Today's Counters) ---
  Future<Map<String, double>> getTodaySummary() async {
    final db = await instance.database;
    final today = DateTime.now().toIso8601String().substring(0, 10);

    final res = await db.rawQuery('''
      SELECT 
        SUM(CASE WHEN type = 'SALE' THEN cash_paid ELSE -cash_paid END) as today_cash,
        SUM(CASE WHEN type = 'SALE' THEN udhar_amount ELSE 0 END) as today_udhar,
        COUNT(id) as total_bills
      FROM bills
      WHERE timestamp LIKE '$today%'
    ''');

    return {
      'cash': (res.first['today_cash'] as num?)?.toDouble() ?? 0.0,
      'udhar': (res.first['today_udhar'] as num?)?.toDouble() ?? 0.0,
      'bills': ((res.first['total_bills'] as num?)?.toDouble() ?? 0.0),
    };
  }
}
