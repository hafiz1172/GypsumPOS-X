import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import '../models/invoice.dart';
import '../models/customer.dart';
import '../services/database_helper.dart';

class BillScreen extends StatefulWidget {
  const BillScreen({super.key});

  @override
  State<BillScreen> createState() => _BillScreenState();
}

class _BillScreenState extends State<BillScreen> {
  final TextEditingController _customerController = TextEditingController();
  final TextEditingController _cashController = TextEditingController();
  
  List<Product> _availableProducts = [];
  List<InvoiceItem> _cartItems = [];
  
  double _subTotal = 0.0;
  double _previousDue = 0.0;
  bool _isFullCash = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _cashController.text = "0";
    _cashController.addListener(_updateTotals);
  }

  @override
  void dispose() {
    _customerController.dispose();
    _cashController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    final products = await DatabaseHelper.instance.getProducts();
    setState(() {
      _availableProducts = products;
    });
  }

  // Customer ka pichla khata check karne ki logic
  Future<void> _checkCustomerDue(String name) async {
    if (name.isEmpty || name == "Walk-in") {
      setState(() => _previousDue = 0.0);
      return;
    }
    Customer? customer = await DatabaseHelper.instance.getCustomerByName(name);
    setState(() {
      _previousDue = customer?.totalDue ?? 0.0;
    });
  }

  void _addToCart(Product product) {
    setState(() {
      // Check agar item pehle se cart me hai
      int index = _cartItems.indexWhere((item) => item.productId == product.id);
      if (index != -1) {
        // Quantity barha dein
        int newQty = _cartItems[index].quantity + 1;
        _cartItems[index] = InvoiceItem(
          productId: product.id,
          productName: product.name,
          rate: product.rate,
          quantity: newQty,
          total: product.rate * newQty,
        );
      } else {
        // Nayi item add karein
        _cartItems.add(InvoiceItem(
          productId: product.id,
          productName: product.name,
          rate: product.rate,
          quantity: 1,
          total: product.rate,
        ));
      }
      _updateTotals();
    });
  }

  void _updateQuantity(int index, int delta) {
    setState(() {
      int newQty = _cartItems[index].quantity + delta;
      if (newQty > 0) {
        _cartItems[index] = InvoiceItem(
          productId: _cartItems[index].productId,
          productName: _cartItems[index].productName,
          rate: _cartItems[index].rate,
          quantity: newQty,
          total: _cartItems[index].rate * newQty,
        );
      } else {
        _cartItems.removeAt(index);
      }
      _updateTotals();
    });
  }

  void _updateTotals() {
    double tempTotal = 0;
    for (var item in _cartItems) {
      tempTotal += item.total;
    }
    
    setState(() {
      _subTotal = tempTotal;
      if (_isFullCash) {
        _cashController.text = _subTotal.toStringAsFixed(0);
      }
    });
  }

  Future<void> _saveBill() async {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cart khali hai!')));
      return;
    }

    String custName = _customerController.text.trim().isEmpty ? "Walk-in" : _customerController.text.trim();
    double cashRcvd = double.tryParse(_cashController.text) ?? 0.0;
    double udharAmt = _subTotal - cashRcvd;
    
    // Safety check: Agar full cash toggle on hai
    if (_isFullCash) {
      cashRcvd = _subTotal;
      udharAmt = 0.0;
    }

    String invoiceNo = await DatabaseHelper.instance.generateNextInvoiceNumber();
    String todayDate = DateTime.now().toIso8601String();

    Invoice newInvoice = Invoice(
      invoiceNumber: invoiceNo,
      customerName: custName,
      date: todayDate,
      subTotal: _subTotal,
      cashReceived: cashRcvd,
      udharAmount: udharAmt,
      items: _cartItems,
      isSynced: 0, // Sync logic run honi baqi hai
    );

    int id = await DatabaseHelper.instance.insertInvoiceAndUpdateLedger(newInvoice);
    
    if (id > 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Bill $invoiceNo save ho gaya!'),
        backgroundColor: Colors.green,
      ));
      
      // Share / Print option popup (Isay baad me expand karenge)
      _showSharePrintDialog(newInvoice);

      // Reset Screen
      setState(() {
        _cartItems.clear();
        _customerController.clear();
        _previousDue = 0.0;
        _isFullCash = true;
        _updateTotals();
      });
    }
  }

  void _showSharePrintDialog(Invoice invoice) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bill Ban Gaya!'),
        content: const Text('Aap isay print ya share karna chahte hain?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), // Close
            child: const Text('Baad Me'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              // TODO: RawBT Thermal Print ya PDF Share logic yahan call hogi
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Printing/Sharing module jaldi aa raha hai...')));
            },
            icon: const Icon(Icons.share),
            label: const Text('Share / Print'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double currentUdhar = _subTotal - (double.tryParse(_cashController.text) ?? 0.0);
    if (_isFullCash) currentUdhar = 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Naya Bill'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 1. Customer Section
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _customerController,
                        onChanged: (val) => _checkCustomerDue(val),
                        decoration: const InputDecoration(
                          labelText: 'Customer Name',
                          hintText: 'Naam likhein ya Walk-in chunein',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Lightning Button for Walk-in
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        _customerController.text = "Walk-in";
                        _checkCustomerDue("Walk-in");
                      },
                      child: const Icon(Icons.flash_on),
                    ),
                  ],
                ),
                if (_previousDue > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Pichla Baqaya: Rs. ${_previousDue.toStringAsFixed(0)}',
                          style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  )
              ],
            ),
          ),
          
          // 2. Cart Items Section (Flexible)
          Expanded(
            flex: 4,
            child: Container(
              color: Colors.grey[100],
              child: _cartItems.isEmpty
                  ? const Center(child: Text('Neeche se items select karein 👇', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: _cartItems.length,
                      itemBuilder: (context, index) {
                        final item = _cartItems[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: ListTile(
                            title: Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Rs. ${item.rate} x ${item.quantity}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red), onPressed: () => _updateQuantity(index, -1)),
                                Text('${item.quantity}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.green), onPressed: () => _updateQuantity(index, 1)),
                                const SizedBox(width: 8),
                                Text('Rs. ${item.total}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),

          // 3. Product Grid (Visual Picker)
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.9,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _availableProducts.length,
                itemBuilder: (context, index) {
                  final p = _availableProducts[index];
                  return InkWell(
                    onTap: () => _addToCart(p),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.05),
                        border: Border.all(color: Colors.teal.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (p.imagePath != null)
                            Expanded(child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(8)), child: Image.file(File(p.imagePath!), fit: BoxFit.cover, width: double.infinity)))
                          else if (p.emoji != null && p.emoji!.isNotEmpty)
                            Expanded(child: Center(child: Text(p.emoji!, style: const TextStyle(fontSize: 32))))
                          else
                            const Expanded(child: Center(child: Icon(Icons.category, size: 32, color: Colors.teal))),
                          
                          Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Text(
                              p.name,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // 4. Totals & Save Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Bill:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('Rs. ${_subTotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal)),
                  ],
                ),
                const Divider(),
                Row(
                  children: [
                    Expanded(
                      child: CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Full Cash'),
                        value: _isFullCash,
                        activeColor: Colors.teal,
                        onChanged: (val) {
                          setState(() {
                            _isFullCash = val ?? true;
                            if (_isFullCash) {
                              _cashController.text = _subTotal.toStringAsFixed(0);
                            } else {
                              _cashController.text = "0";
                            }
                          });
                        },
                      ),
                    ),
                    if (!_isFullCash)
                      Expanded(
                        child: TextField(
                          controller: _cashController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Cash Received',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                          ),
                        ),
                      ),
                  ],
                ),
                if (!_isFullCash && currentUdhar > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Text('Udhar (Due): ', style: TextStyle(color: Colors.redAccent)),
                        Text('Rs. ${currentUdhar.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 16)),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _saveBill,
                    child: const Text('SAVE BILL & SHARE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
