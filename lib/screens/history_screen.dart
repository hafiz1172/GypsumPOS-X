import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/pos_provider.dart';
import '../services/print_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String searchQuery = '';

  void _showBillDetails(BuildContext context, Bill bill) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Bill #${bill.id} (${bill.type})',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.print, color: Colors.indigo),
                  tooltip: 'Thermal Print (RawBT)',
                  onPressed: () => PrintService.printBill(bill),
                ),
              ],
            ),
            Text('Customer: ${bill.customerName}', style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('Date: ${bill.timestamp}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const Divider(),
            const Text('Items Detail:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            ...bill.items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${item.productName} (x${item.quantity})'),
                      Text('Rs ${item.total.toStringAsFixed(0)}'),
                    ],
                  ),
                )),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Kul Raqam:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('Rs ${bill.totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Naqad Mila:'),
                Text('Rs ${bill.cashPaid.toStringAsFixed(0)}'),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Baqaya Udhar:'),
                Text('Rs ${bill.udharAmount.toStringAsFixed(0)}'),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.print),
                label: const Text('RawBT Thermal Print Send Karein'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => PrintService.printBill(bill),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PosProvider>();

    final filteredList = provider.recentBills.where((b) {
      final q = searchQuery.toLowerCase();
      return b.id.toString().contains(q) || b.customerName.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Purane Bills & History'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: TextField(
              onChanged: (val) => setState(() => searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Bill number ya customer name search karein...',
                prefixIcon: const Icon(Icons.search),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          Expanded(
            child: filteredList.isEmpty
                ? const Center(child: Text('Koi bill nahi mila.'))
                : ListView.builder(
                    itemCount: filteredList.length,
                    itemBuilder: (ctx, i) {
                      final bill = filteredList[i];
                      final isReturn = bill.type == 'RETURN';

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        child: ListTile(
                          onTap: () => _showBillDetails(context, bill),
                          leading: CircleAvatar(
                            backgroundColor: isReturn ? Colors.deepOrange.shade100 : Colors.purple.shade100,
                            child: Icon(
                              isReturn ? Icons.assignment_return : Icons.receipt,
                              color: isReturn ? Colors.deepOrange : Colors.purple,
                            ),
                          ),
                          title: Text('Bill #${bill.id} - ${bill.customerName}'),
                          subtitle: Text(
                            '${bill.timestamp.substring(0, 16)} | Udhar: Rs ${bill.udharAmount.toStringAsFixed(0)}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Rs ${bill.totalAmount.toStringAsFixed(0)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              IconButton(
                                icon: const Icon(Icons.print, size: 20, color: Colors.grey),
                                onPressed: () => PrintService.printBill(bill),
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
