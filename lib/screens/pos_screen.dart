import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/pos_provider.dart';

class PosScreen extends StatelessWidget {
  const PosScreen({super.key});

  void _showCheckoutDialog(BuildContext context, PosProvider provider) {
    final total = provider.cartTotal;
    final cashController = TextEditingController(text: total.toStringAsFixed(0));
    double cashPaid = total;
    double udhar = 0.0;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: Text(
              provider.isWalkIn ? 'Bill Checkout (Walk-in)' : 'Bill Checkout (${provider.selectedCustomer?.name})',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kul Total: Rs ${total.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: cashController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Naqad Mila (Cash)',
                    prefixText: 'Rs ',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    setState(() {
                      cashPaid = double.tryParse(val) ?? 0.0;
                      if (cashPaid > total) cashPaid = total;
                      udhar = (total - cashPaid).clamp(0.0, double.infinity);
                    });
                  },
                ),
                const SizedBox(height: 12),
                if (!provider.isWalkIn)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Baqaya Udhar:'),
                        Text(
                          'Rs ${udhar.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (cashPaid < total)
                  const Text(
                    'Note: Walk-in customer par udhar allow nahi hai. Customer select karein.',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: (provider.isWalkIn && cashPaid < total)
                    ? null
                    : () async {
                        Navigator.pop(dialogCtx);
                        await provider.submitBill(
                          cashPaid: cashPaid,
                          udharAmount: udhar,
                          type: 'SALE',
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Bill save aur print intent send ho gaya!')),
                          );
                        }
                      },
                child: const Text('Confirm & Print'),
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
        title: const Text('Naya Bill (POS)'),
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
          // Customer Selection Bar with Flash Walk-in Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.grey.shade100,
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
                    hint: const Text('Select Regular Customer'),
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
                    backgroundColor: provider.isWalkIn ? Colors.indigo : Colors.grey.shade300,
                    foregroundColor: provider.isWalkIn ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          // Main View: Products Grid & Bottom Cart Summary
          Expanded(
            child: provider.products.isEmpty
                ? const Center(child: Text('Koi product nahi mila'))
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
                                  style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold),
                                ),
                                if (cartItem.quantity > 0)
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.indigo.shade50,
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
                                  const Icon(Icons.add_shopping_cart, size: 18, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Bottom Cart Summary & Checkout Bar
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
                        '${provider.cart.length} Items Selected',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      Text(
                        'Rs ${provider.cartTotal.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo),
                      ),
                    ],
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () => _showCheckoutDialog(context, provider),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Checkout & Save'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
