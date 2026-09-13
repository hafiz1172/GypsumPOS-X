import 'dart:io';
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/invoice.dart';
import '../models/customer.dart';
import '../services/database_helper.dart';

class ReturnScreen extends StatefulWidget {
  const ReturnScreen({super.key});

  @override
  State<ReturnScreen> createState() => _ReturnScreenState();
}

class _ReturnScreenState extends State<ReturnScreen> {
  final TextEditingController _customerController = TextEditingController();
  final TextEditingController _refundCashController = TextEditingController();
  
  List<Product> _availableProducts = [];
  List<InvoiceItem> _returnItems = [];
  
  double _totalRefund = 0.0;
  double _previousDue = 0.0;
  bool _isFullCashRefund = true; // Agar true, toh munshi ne cash wapis de diya

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _refundCashController.text = "0";
    _refundCashController.addListener(_updateTotals);
  }

  @override
  void dispose() {
    _customerController.dispose();
    _refundCashController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    final products = await DatabaseHelper.instance.getProducts();
    setState(() {
      _availableProducts = products;
    });
  }

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

  void _addToReturnCart(Product product) {
    setState(() {
      int index = _returnItems.indexWhere((item) => item.productId == product.id);
      if (index != -1) {
        int newQty = _returnItems[index].quantity + 1;
        _returnItems[index] = InvoiceItem(
          productId: product.id,
          productName: product.name,
          rate: product.rate,
          quantity: newQty,
          total: product.rate * newQty,
        );
      } else {
        _returnItems.add(InvoiceItem(
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
      int newQty = _returnItems[index].quantity + delta;
      if (newQty > 0) {
        _returnItems[index] = InvoiceItem(
          productId: _returnItems[index].productId,
          productName: _returnItems[index].productName,
          rate: _returnItems[index].rate,
          quantity: newQty,
          total: _returnItems[index].rate * newQty,
        );
      } else {
        _returnItems.removeAt(index);
      }
      _updateTotals();
    });
  }

  void _updateTotals() {
    double tempTotal = 0;
    for (var item in _returnItems) {
      tempTotal += item.total;
    }
    
    setState(() {
      _totalRefund = tempTotal;
      if (_isFullCashRefund) {
        _refundCashController.text = _totalRefund.toStringAsFixed(0);
      }
    });
  }

  Future<void> _saveReturn() async {
    if (_returnItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Koi item select nahi ki!')));
      return;
    }

    String custName = _customerController.text.trim().isEmpty ? "Walk-in" : _customerController.text.trim();
    double cashRefunded = double.tryParse(_refundCashController.text) ?? 0.0;
    double udharAdjusted = _totalRefund - cashRefunded;
    
    if (_isFullCashRefund) {
      cashRefunded = _totalRefund;
      udharAdjusted = 0.0;
    }

    // Database me Return entry ko alag pehchanne ke liye number 'RET-' se shuru karein
    String returnNo = 'RET-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    String todayDate = DateTime.now().toIso8601String();

    // Hum Return ko bhi as an Invoice save kar rahay hain, lekin amounts negative me taake dashboard me theek calculation ho
    Invoice returnInvoice = Invoice(
      invoiceNumber: returnNo,
      customerName: custName,
      date: todayDate,
      subTotal: -_totalRefund, // Negative 
      cashReceived: -cashRefunded, // Cash wapis gaya
      udharAmount: -udharAdjusted, // Udhar me kami aayi
      items: List.from(_returnItems),
      isSynced: 0,
    );

    int id = await DatabaseHelper.instance.insertInvoiceAndUpdateLedger(returnInvoice);
    
    if (id > 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Maal Wapsi ($returnNo) darj ho gayi!'),
        backgroundColor: Colors.blueAccent,
      ));
      
      setState(() {
        _returnItems.clear();
        _customerController.clear();
        _previousDue = 0.0;
        _isFullCashRefund = true;
        _updateTotals();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    double currentUdharDeduction = _totalRefund - (double.tryParse(_refundCashController.text) ?? 0.0);
    if (_isFullCashRefund) currentUdharDeduction = 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Maal Wapsi (Return)'),
        backgroundColor: Colors.blueAccent,
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
                          hintText: 'Walk-in ya naam likhein',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, padding: const EdgeInsets.all(14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
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
                        const Icon(Icons.account_balance_wallet, color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        Text('Customer ka Baqaya Udhar: Rs. ${_previousDue.toStringAsFixed(0)}', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )
              ],
            ),
          ),
          
          // 2. Return Items Section
          Expanded(
            flex: 4,
            child: Container(
              color: Colors.red.withOpacity(0.05), // Wapsi ka feel dene ke liye light red bg
              child: _returnItems.isEmpty
                  ? const Center(child: Text('Jo item wapis aayi hai usey neeche se select karein 👇', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: _returnItems.length,
                      itemBuilder: (context, index) {
                        final item = _returnItems[index];
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
                                Text('- Rs. ${item.total}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),

          // 3. Product Grid
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade300))),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.9, crossAxisSpacing: 8, mainAxisSpacing: 8),
                itemCount: _availableProducts.length,
                itemBuilder: (context, index) {
                  final p = _availableProducts[index];
                  return InkWell(
                    onTap: () => _addToReturnCart(p),
                    child: Container(
                      decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.05), border: Border.all(color: Colors.blueAccent.withOpacity(0.3)), borderRadius: BorderRadius.circular(8)),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (p.imagePath != null)
                            Expanded(child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(8)), child: Image.file(File(p.imagePath!), fit: BoxFit.cover, width: double.infinity)))
                          else if (p.emoji != null && p.emoji!.isNotEmpty)
                            Expanded(child: Center(child: Text(p.emoji!, style: const TextStyle(fontSize: 32))))
                          else
                            const Expanded(child: Center(child: Icon(Icons.category, size: 32, color: Colors.blueAccent))),
                          
                          Padding(padding: const EdgeInsets.all(4.0), child: Text(p.name, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
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
            decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Wapsi (Refund):', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('Rs. ${_totalRefund.toStringAsFixed(0)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                  ],
                ),
                const Divider(),
                Row(
                  children: [
                    Expanded(
                      child: CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Full Cash Wapis Kiya', style: TextStyle(fontSize: 13)),
                        value: _isFullCashRefund,
                        activeColor: Colors.blueAccent,
                        onChanged: (val) {
                          setState(() {
                            _isFullCashRefund = val ?? true;
                            if (_isFullCashRefund) _refundCashController.text = _totalRefund.toStringAsFixed(0);
                            else _refundCashController.text = "0";
                          });
                        },
                      ),
                    ),
                    if (!_isFullCashRefund)
                      Expanded(
                        child: TextField(
                          controller: _refundCashController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Cash Wapis Diya', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0)),
                        ),
                      ),
                  ],
                ),
                if (!_isFullCashRefund && currentUdharDeduction > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Text('Udhar me Katoti: ', style: TextStyle(color: Colors.blue)),
                        Text('Rs. ${currentUdharDeduction.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 16)),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    onPressed: _saveReturn,
                    child: const Text('SAVE RETURN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
