import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/pos_provider.dart';

class SalesReturnScreen extends StatelessWidget {
  const SalesReturnScreen({super.key});

  void _showReturnConfirmDialog(BuildContext context, PosProvider provider) {
    final total = provider.cartTotal;
    final refundCashController = TextEditingController(text: '0');
    double cashRefunded = 0.0;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: const Text('Confirm Maal Wapsi'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Wapsi Total: Rs ${total.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                ),
                const SizedBox(height: 8),
                Text(
                  'Customer: ${provider.selectedCustomer?.name ?? "Walk-in"}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                if (!provider.isWalkIn)
                  Text(
                    'Yeh raqam (${total.toStringAsFixed(0)}) customer ke ledger balance se khud ba khud minus ho jayegi.',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: refundCashController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Cash Wapsi Diya (Refund)',
                    prefixText: 'Rs ',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    setState(() {
                      cashRefunded = double.tryParse(val) ?? 0.0;
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  Navigator.pop(dialogCtx);
                  await provider.submitBill(
                    cashPaid: cashRefunded,
                    udharAmount: 0.0,
                    type: 'RETURN',
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Maal wapsi record update ho gaya!')),
                    );
                    Navigator.pop(context);
                  }
                },
                child: const Text('Confirm Wapsi'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PosProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Maal Wapsi (Sales Return)'),
        backgroundColor: Colors.deepOrange.shade700,
        foregroundColor: Colors.white,
        actions: [
          if (provider.cart.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => provider.clearCart(),
            ),
        ],
      ),
      body: Column(
        children: [
          // Customer Selection Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.deepOrange.shade50,
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<Customer?>(
                    value: provider.selectedCustomer,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    hint: const Text('Select Customer for Return'),
                    items: [
                      const DropdownMenuItem<Customer?>(
                        value: null,
                        child: Text('Walk-in Customer'),
                      ),
                      ...provider.customers.map(
                        (c) => DropdownMenuItem<Customer?>(
                          value: c,
                          child: Text('${c.name} (${c.phone})'),
                        ),
                      ),
                    ],
                    onChanged: (c) => provider.selectCustomer(c),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => provider.setWalkIn(),
                  icon: const Icon(Icons.flash_on, size: 16),
                  label: const Text('Walk-in'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: provider.isWalkIn ? Colors.deepOrange : Colors.grey.shade300,
                    foregroundColor: provider.isWalkIn ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          // Return Items Grid
          Expanded(
            child: provider.products.isEmpty
                ? const Center(child: Text('Koi item mojood nahi hai'))
                : GridView.builder(
                    padding: const EdgeInsets.all(10),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.1,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: provider.products.length,
                    itemBuilder: (ctx, i) {
                      final product = provider.products[i];
                      final cartItem = provider.cart.firstWhere(
                        (item) => item.product.id == product.id,
                        orElse: () => CartItem(product: product, quantity: 0),
                      );

                      return Card(
                        elevation: 1.5,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: InkWell(
                          onTap: () => provider.addToCart(product),
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Text(product.emoji, style: const TextStyle(fontSize: 28)),
                                Text(
                                  product.name,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                Text(
                                  'Rs ${product.rate.toStringAsFixed(0)}',
                                  style: TextStyle(color: Colors.deepOrange.shade800, fontWeight: FontWeight.bold),
                                ),
                                if (cartItem.quantity > 0)
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.deepOrange.shade50,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove, size: 16),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () => provider.decrementQuantity(product),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                          child: Text(
                                            '${cartItem.quantity}',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add, size: 16),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () => provider.addToCart(product),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  const Icon(Icons.keyboard_return, size: 18, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Bottom Wapsi Summary Bar
          if (provider.cart.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${provider.cart.length} Items Return',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      Text(
                        'Rs ${provider.cartTotal.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                      ),
                    ],
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () => _showReturnConfirmDialog(context, provider),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Process Wapsi'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
