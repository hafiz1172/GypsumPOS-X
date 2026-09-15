import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/models.dart';
import '../services/print_service.dart';

class PosProvider extends ChangeNotifier {
  final DBHelper _db = DBHelper.instance;

  // State Variables
  List<Product> products = [];
  List<Customer> customers = [];
  List<Customer> filteredCustomers = [];
  List<Bill> recentBills = [];
  List<CartItem> cart = [];

  Customer? selectedCustomer;
  bool isWalkIn = true;

  // Real-time Counters
  double todayCash = 0.0;
  double todayUdhar = 0.0;
  int todayBillsCount = 0;
  double marketBaqaya = 0.0;

  bool isLoading = false;

  PosProvider() {
    loadInitialData();
  }

  // --- Initial Load & Refresh ---
  Future<void> loadInitialData() async {
    isLoading = true;
    notifyListeners();

    products = await _db.getProducts();
    customers = await _db.getCustomers();
    filteredCustomers = List.from(customers);
    recentBills = await _db.getBills();

    await refreshCounters();

    isLoading = false;
    notifyListeners();
  }

  Future<void> refreshCounters() async {
    final summary = await _db.getTodaySummary();
    todayCash = summary['cash'] ?? 0.0;
    todayUdhar = summary['udhar'] ?? 0.0;
    todayBillsCount = (summary['bills'] ?? 0.0).toInt();

    marketBaqaya = await _db.getMarketBaqaya();
    notifyListeners();
  }

  // --- Cart Management ---
  void addToCart(Product product) {
    final index = cart.indexWhere((item) => item.product.id == product.id);
    if (index >= 0) {
      cart[index].quantity += 1;
    } else {
      cart.add(CartItem(product: product, quantity: 1));
    }
    notifyListeners();
  }

  void decrementQuantity(Product product) {
    final index = cart.indexWhere((item) => item.product.id == product.id);
    if (index >= 0) {
      if (cart[index].quantity > 1) {
        cart[index].quantity -= 1;
      } else {
        cart.removeAt(index);
      }
      notifyListeners();
    }
  }

  void removeFromCart(Product product) {
    cart.removeWhere((item) => item.product.id == product.id);
    notifyListeners();
  }

  void clearCart() {
    cart.clear();
    selectedCustomer = null;
    isWalkIn = true;
    notifyListeners();
  }

  double get cartTotal => cart.fold(0.0, (sum, item) => sum + item.total);

  // --- Customer Selection ---
  void selectCustomer(Customer? customer) {
    selectedCustomer = customer;
    isWalkIn = customer == null;
    notifyListeners();
  }

  void setWalkIn() {
    selectedCustomer = null;
    isWalkIn = true;
    notifyListeners();
  }

  void searchCustomers(String query) {
    if (query.trim().isEmpty) {
      filteredCustomers = List.from(customers);
    } else {
      filteredCustomers = customers.where((c) {
        return c.name.toLowerCase().contains(query.toLowerCase()) ||
            c.phone.contains(query);
      }).toList();
    }
    notifyListeners();
  }

  // --- Complete Sale or Return ---
  Future<int?> submitBill({
    required double cashPaid,
    required double udharAmount,
    required String type, // 'SALE' ya 'RETURN'
  }) async {
    if (cart.isEmpty) return null;

    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final customerName = isWalkIn || selectedCustomer == null
        ? 'Walk-in'
        : selectedCustomer!.name;

    final newBill = Bill(
      customerId: selectedCustomer?.id,
      customerName: customerName,
      totalAmount: cartTotal,
      cashPaid: cashPaid,
      udharAmount: udharAmount,
      type: type,
      timestamp: timestamp,
      items: cart
          .map((c) => BillItem(
                billId: 0,
                productName: c.product.name,
                rate: c.product.rate,
                quantity: c.quantity,
                total: c.total,
              ))
          .toList(),
    );

    final billId = await _db.createBill(bill: newBill, cartItems: cart);

    // Bill print data construct karna
    final createdBill = Bill(
      id: billId,
      customerId: newBill.customerId,
      customerName: newBill.customerName,
      totalAmount: newBill.totalAmount,
      cashPaid: newBill.cashPaid,
      udharAmount: newBill.udharAmount,
      type: newBill.type,
      timestamp: newBill.timestamp,
      items: newBill.items,
    );

    // Print receipt
    await PrintService.printBill(createdBill);

    clearCart();
    await loadInitialData();
    return billId;
  }

  // --- Wasooli / Ledger Collection ---
  Future<void> collectPayment(int customerId, double amount) async {
    await _db.recordPaymentCollection(customerId, amount);
    await loadInitialData();
  }

  // --- Add New Customer ---
  Future<void> addCustomer(String name, String phone, double balance) async {
    await _db.insertCustomer(Customer(name: name, phone: phone, balance: balance));
    await loadInitialData();
  }

  // --- Add New Product ---
  Future<void> addProduct(String name, double rate, String emoji, int stock) async {
    await _db.insertProduct(Product(name: name, rate: rate, emoji: emoji, stock: stock));
    await loadInitialData();
  }
}
