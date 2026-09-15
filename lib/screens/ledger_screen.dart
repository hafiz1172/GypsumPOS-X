import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/pos_provider.dart';
import '../database/db_helper.dart';

class LedgerScreen extends StatelessWidget {
  const LedgerScreen({super.key});

  void _showWasooliDialog(BuildContext context, Customer customer, PosProvider provider) {
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Wasooli - ${customer.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kul Baqaya Udhar: Rs ${customer.balance.toStringAsFixed(0)}'),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Mili hui Raqam (Wasooli)',
                prefixText: 'Rs ',
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
              final amount = double.tryParse(amountController.text) ?? 0.0;
              if (amount > 0 && customer.id != null) {
                await provider.collectPayment(customer.id!, amount);
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Wasooli Rs $amount record ho gayi!')),
                  );
                }
              }
            },
            child: const Text('Save Wasooli'),
          ),
        ],
      ),
    );
  }

  void _showAddCustomerDialog(BuildContext context, PosProvider provider) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final balanceCtrl = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Naya Customer / Khata'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Customer Naam', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: balanceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Pichla Baqaya (Optional)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isNotEmpty) {
                await provider.addCustomer(
                  nameCtrl.text.trim(),
                  phoneCtrl.text.trim(),
                  double.tryParse(balanceCtrl.text) ?? 0.0,
                );
                if (context.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Add Khata'),
          ),
        ],
      ),
    );
  }

  void _showCustomerInvoices(BuildContext context, Customer customer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        builder: (_, scrollController) => FutureBuilder<List<Bill>>(
          future: customer.id != null ? DBHelper.instance.getCustomerBills(customer.id!) : Future.value([]),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final bills = snapshot.data!;

            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.teal.shade50,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${customer.name} ki Invoices',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Baqaya: Rs ${customer.balance.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: bills.isEmpty
                      ? const Center(child: Text('Is customer ka koi purana bill nahi mila.'))
                      : ListView.separated(
                          controller: scrollController,
                          itemCount: bills.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final bill = bills[i];
                            final isReturn = bill.type == 'RETURN';
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isReturn ? Colors.deepOrange.shade100 : Colors.teal.shade100,
                                child: Icon(
                                  isReturn ? Icons.assignment_return : Icons.receipt,
                                  color: isReturn ? Colors.deepOrange : Colors.teal,
                                ),
                              ),
                              title: Text('Bill #${bill.id} - Rs ${bill.totalAmount.toStringAsFixed(0)}'),
                              subtitle: Text(
                                '${bill.timestamp.substring(0, 16)} | Udhar: Rs ${bill.udharAmount.toStringAsFixed(0)}',
                              ),
                              trailing: Text(
                                bill.type,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isReturn ? Colors.deepOrange : Colors.teal,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PosProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Udhar Ledger / Khata'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () => _showAddCustomerDialog(context, provider),
          ),
        ],
      ),
      body: Column(
        children: [
          // Market Baqaya Top Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            color: Colors.teal.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'KUL MARKET BAQAYA:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                ),
                Text(
                  'Rs ${provider.marketBaqaya.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
                ),
              ],
            ),
          ),

          // Live Search Bar
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: TextField(
              onChanged: (val) => provider.searchCustomers(val),
              decoration: InputDecoration(
                hintText: 'Customer ka naam ya phone likhein...',
                prefixIcon: const Icon(Icons.search),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),

          // Customers Ledger List
          Expanded(
            child: provider.filteredCustomers.isEmpty
                ? const Center(child: Text('Koi record nahi mila.'))
                : ListView.builder(
                    itemCount: provider.filteredCustomers.length,
                    itemBuilder: (ctx, i) {
                      final customer = provider.filteredCustomers[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        child: ListTile(
                          onTap: () => _showCustomerInvoices(context, customer),
                          leading: CircleAvatar(
                            backgroundColor: customer.balance > 0 ? Colors.red.shade100 : Colors.green.shade100,
                            child: Text(
                              customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: customer.balance > 0 ? Colors.red.shade900 : Colors.green.shade900,
                              ),
                            ),
                          ),
                          title: Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(customer.phone),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Baqaya Udhar', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                  Text(
                                    'Rs ${customer.balance.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: customer.balance > 0 ? Colors.red : Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 8),
                              if (customer.balance > 0)
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  onPressed: () => _showWasooliDialog(context, customer, provider),
                                  child: const Text('Wasooli', style: TextStyle(fontSize: 12)),
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
