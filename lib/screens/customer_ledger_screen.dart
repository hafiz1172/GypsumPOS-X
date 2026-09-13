import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/customer.dart';
import '../models/invoice.dart';
import '../services/database_helper.dart';
import '../services/export_service.dart';

class CustomerLedgerScreen extends StatefulWidget {
  const CustomerLedgerScreen({super.key});

  @override
  State<CustomerLedgerScreen> createState() => _CustomerLedgerScreenState();
}

class _CustomerLedgerScreenState extends State<CustomerLedgerScreen> {
  List<Customer> _customers = [];
  List<Customer> _filteredCustomers = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper.instance.getCustomers();
    setState(() {
      _customers = data;
      _filteredCustomers = data;
      _isLoading = false;
    });
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredCustomers = _customers;
      } else {
        _filteredCustomers = _customers.where((customer) {
          return customer.name.toLowerCase().contains(query) ||
              customer.phone.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  // Udhar Wasooli Dialog (Payment Collection)
  void _showPaymentDialog(Customer customer) {
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Wasooli: ${customer.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kul Baqaya (Total Due): Rs. ${customer.totalDue.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Mili Hui Raqam (Received Amount)',
                prefixText: 'Rs. ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            onPressed: () async {
              double received = double.tryParse(amountController.text) ?? 0.0;
              if (received <= 0) return;

              double newDue = customer.totalDue - received;
              if (newDue < 0) newDue = 0.0;

              await DatabaseHelper.instance.updateCustomerDue(customer.id!, newDue);
              Navigator.pop(ctx);
              _loadCustomers();

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${customer.name} ka baqaya update ho gaya: Rs. ${newDue.toStringAsFixed(0)}'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Wasool Karein'),
          ),
        ],
      ),
    );
  }

  // Customer Invoices History Modal
  void _showCustomerInvoicesModal(Customer customer) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return FutureBuilder<List<Invoice>>(
          future: DatabaseHelper.instance.getInvoicesByCustomer(customer.name),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 250, child: Center(child: CircularProgressIndicator()));
            }

            final invoices = snapshot.data ?? [];

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(customer.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          Text('Baqaya: Rs. ${customer.totalDue.toStringAsFixed(0)}',
                              style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                        onPressed: () {
                          Navigator.pop(context);
                          _showPaymentDialog(customer);
                        },
                        icon: const Icon(Icons.payment, size: 18),
                        label: const Text('Wasooli'),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  const Text('Tammam Invoices (History):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: invoices.isEmpty
                        ? const Center(child: Text('Koi invoice nahi mili.'))
                        : ListView.builder(
                            itemCount: invoices.length,
                            itemBuilder: (context, index) {
                              final inv = invoices[index];
                              String dateFormatted = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(inv.date));

                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(inv.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal)),
                                          Text(dateFormatted, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Items: ${inv.items.length}'),
                                          Text('Total: Rs. ${inv.subTotal.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Cash: Rs. ${inv.cashReceived.toStringAsFixed(0)}', style: const TextStyle(color: Colors.green)),
                                          Text('Udhar: Rs. ${inv.udharAmount.toStringAsFixed(0)}', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.print, color: Colors.blueGrey, size: 20),
                                            tooltip: 'Thermal Print',
                                            onPressed: () => ExportService.shareAsTextForThermal(inv),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 20),
                                            tooltip: 'PDF Export',
                                            onPressed: () => ExportService.shareAsPdf(inv),
                                          ),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double totalMarketUdhar = _customers.fold(0.0, (sum, c) => sum + c.totalDue);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Customer Ledger (Khata)'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Total Market Udhar Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.orange.withOpacity(0.15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Kul Market Baqaya:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.brown)),
                Text(
                  'Rs. ${totalMarketUdhar.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.redAccent),
                ),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Customer ka naam ya phone search karein...',
                prefixIcon: const Icon(Icons.search, color: Colors.teal),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
          ),

          // Customer List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCustomers.isEmpty
                    ? Center(
                        child: Text(
                          _searchController.text.isEmpty
                              ? 'Mashallah! Kisi customer ka udhar baqaya nahi hai.'
                              : 'Is naam se koi customer nahi mila.',
                          style: TextStyle(color: Colors.grey[600], fontSize: 15),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _filteredCustomers.length,
                        itemBuilder: (context, index) {
                          final customer = _filteredCustomers[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            elevation: 1,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              onTap: () => _showCustomerInvoicesModal(customer),
                              leading: CircleAvatar(
                                backgroundColor: Colors.teal.withOpacity(0.15),
                                child: Text(
                                  customer.name.isNotEmpty ? customer.name[0].toUpperCase() : 'C',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
                                ),
                              ),
                              title: Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              subtitle: Text(
                                customer.phone.isNotEmpty ? customer.phone : 'Invoices dekhne ke liye tap karein',
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Baqaya', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                  Text(
                                    'Rs. ${customer.totalDue.toStringAsFixed(0)}',
                                    style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
