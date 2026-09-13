import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/product.dart';
import '../models/customer.dart';
import '../models/invoice.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('pop_khata.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    // Products Table
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        rate REAL NOT NULL,
        emoji TEXT,
        imagePath TEXT
      )
    ''');

    // Customers Table (Ledger ke liye)
    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        totalDue REAL NOT NULL
      )
    ''');

    // Invoices Table
    await db.execute('''
      CREATE TABLE invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoiceNumber TEXT NOT NULL,
        customerName TEXT NOT NULL,
        date TEXT NOT NULL,
        subTotal REAL NOT NULL,
        cashReceived REAL NOT NULL,
        udharAmount REAL NOT NULL,
        items TEXT NOT NULL,
        isSynced INTEGER NOT NULL
      )
    ''');
  }

  // ==========================================
  // PRODUCTS CRUD
  // ==========================================
  Future<int> insertProduct(Product product) async {
    final db = await instance.database;
    return await db.insert('products', product.toMap());
  }

  Future<List<Product>> getProducts() async {
    final db = await instance.database;
    final result = await db.query('products');
    return result.map((map) => Product.fromMap(map)).toList();
  }

  Future<int> updateProduct(Product product) async {
    final db = await instance.database;
    return await db.update('products', product.toMap(), where: 'id = ?', whereArgs: [product.id]);
  }

  Future<int> deleteProduct(int id) async {
    final db = await instance.database;
    return await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  // ==========================================
  // CUSTOMERS (LEDGER) CRUD
  // ==========================================
  Future<int> insertCustomer(Customer customer) async {
    final db = await instance.database;
    return await db.insert('customers', customer.toMap());
  }

  Future<List<Customer>> getCustomers() async {
    final db = await instance.database;
    final result = await db.query('customers', where: 'totalDue > 0'); // Sirf udhar walay
    return result.map((map) => Customer.fromMap(map)).toList();
  }

  Future<Customer?> getCustomerByName(String name) async {
    final db = await instance.database;
    final result = await db.query('customers', where: 'name = ?', whereArgs: [name]);
    if (result.isNotEmpty) {
      return Customer.fromMap(result.first);
    }
    return null;
  }

  Future<int> updateCustomerDue(int id, double newDue) async {
    final db = await instance.database;
    return await db.update('customers', {'totalDue': newDue}, where: 'id = ?', whereArgs: [id]);
  }

  // ==========================================
  // INVOICES CRUD
  // ==========================================
  // Bill save karna aur sath hi Customer ka Khata update karna
  Future<int> insertInvoiceAndUpdateLedger(Invoice invoice) async {
    final db = await instance.database;
    int invoiceId = 0;
    
    // Transaction use kar rahay hain taake dono kaam aik sath hon, ya koi na ho
    await db.transaction((txn) async {
      invoiceId = await txn.insert('invoices', invoice.toMap());

      // Agar bill me udhar hai, toh customer ka khata check aur update karein
      if (invoice.udharAmount > 0 || invoice.customerName != "Walk-in") {
        final customerResult = await txn.query('customers', where: 'name = ?', whereArgs: [invoice.customerName]);
        
        if (customerResult.isNotEmpty) {
          double previousDue = (customerResult.first['totalDue'] as num).toDouble();
          double newDue = previousDue + invoice.udharAmount;
          await txn.update('customers', {'totalDue': newDue}, where: 'name = ?', whereArgs: [invoice.customerName]);
        } else {
          // Naya customer hai
          await txn.insert('customers', {
            'name': invoice.customerName,
            'phone': '',
            'totalDue': invoice.udharAmount
          });
        }
      }
    });
    return invoiceId;
  }

  Future<List<Invoice>> getAllInvoices() async {
    final db = await instance.database;
    final result = await db.query('invoices', orderBy: 'id DESC');
    return result.map((map) => Invoice.fromMap(map)).toList();
  }

  // Ledger Filter: Kisi khaas customer ki history nikalne ke liye
  Future<List<Invoice>> getInvoicesByCustomer(String customerName) async {
    final db = await instance.database;
    final result = await db.query('invoices', where: 'customerName = ?', whereArgs: [customerName], orderBy: 'id DESC');
    return result.map((map) => Invoice.fromMap(map)).toList();
  }

  // Invoice Update Logic (Edit Invoice feature ke liye)
  Future<int> updateInvoice(Invoice invoice) async {
    final db = await instance.database;
    return await db.update('invoices', invoice.toMap(), where: 'id = ?', whereArgs: [invoice.id]);
  }

  // Automatic Invoice Number Generator (INV-000001)
  Future<String> generateNextInvoiceNumber() async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM invoices');
    int count = Sqflite.firstIntValue(result) ?? 0;
    int nextId = count + 1;
    return 'INV-${nextId.toString().padLeft(6, '0')}';
  }
}
