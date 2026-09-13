import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/invoice.dart';
import '../services/database_helper.dart';
import '../services/export_service.dart';

class InvoiceHistoryScreen extends StatefulWidget {
  const InvoiceHistoryScreen({super.key});

  @override
  State<InvoiceHistoryScreen> createState() => _InvoiceHistoryScreenState();
}

class _InvoiceHistoryScreenState extends State<InvoiceHistoryScreen> {
  List<Invoice> _invoices = [];
  List<Invoice> _filteredInvoices = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInvoices();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInvoices() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper.instance.getAllInvoices();
    setState(() {
      _invoices = data;
      _filteredInvoices = data;
      _isLoading = false;
    });
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredInvoices = _invoices;
      } else {
        _filteredInvoices = _invoices.where((inv) {
          return inv.customerName.toLowerCase().contains(query) ||
                 inv.invoiceNumber.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  // Invoice Details & Actions Modal
  void _showInvoiceDetails(Invoice invoice) {
    String dateFormatted = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(invoice.date));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            top: 24, left: 16, right: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Center(
                child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(invoice.invoiceNumber, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: invoice.isSynced == 1 ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(invoice.isSynced == 1 ? 'Synced' : 'Not Synced', style: TextStyle(color: invoice.isSynced == 1 ? Colors.green : Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
              Text('Customer: ${invoice.customerName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              Text('Date: $dateFormatted', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
              const Divider(height: 24),

              // Items List
              const Text('Items Detail:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.3),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: invoice.items.length,
                  itemBuilder: (context, index) {
                    final item = invoice.items[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text('${item.productName} (x${item.quantity})')),
                          Text('Rs. ${item.total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 24),

              // Totals
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('SubTotal:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('Rs. ${invoice.subTotal.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Cash Received:'),
                  Text('Rs. ${invoice.cashReceived.toStringAsFixed(0)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Udhar (Due):'),
                  Text('Rs. ${invoice.udharAmount.toStringAsFixed(0)}', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 24),

              // Actions (Print, PDF, Edit/Delete)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey[800], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        ExportService.shareAsTextForThermal(invoice);
                      },
                      icon: const Icon(Icons.receipt, size: 18),
                      label: const Text('Thermal Print'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        ExportService.shareAsPdf(invoice);
                      },
                      icon: const Icon(Icons.picture_as_pdf, size: 18),
                      label: const Text('PDF Share'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bill edit karne ke liye isay delete kar ke naya bill banayein taake khata theek rahay.')));
                  },
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Edit / Void Bill'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Purane Bills (History)'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search Field
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Bill No. ya Customer ka naam likhein...',
                prefixIcon: const Icon(Icons.search, color: Colors.teal),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _searchController.clear())
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
              ),
            ),
          ),

          // Invoices List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredInvoices.isEmpty
                    ? Center(child: Text('Koi purana bill nahi mila.', style: TextStyle(color: Colors.grey[600], fontSize: 16)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _filteredInvoices.length,
                        itemBuilder: (context, index) {
                          final invoice = _filteredInvoices[index];
                          String dateFormatted = DateFormat('dd MMM yyyy').format(DateTime.parse(invoice.date));

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            elevation: 1,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              onTap: () => _showInvoiceDetails(invoice),
                              leading: CircleAvatar(
                                backgroundColor: invoice.udharAmount > 0 ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                                child: Icon(
                                  invoice.udharAmount > 0 ? Icons.money_off : Icons.check_circle,
                                  color: invoice.udharAmount > 0 ? Colors.redAccent : Colors.green,
                                ),
                              ),
                              title: Text(invoice.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('${invoice.customerName} • $dateFormatted'),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('Rs. ${invoice.subTotal.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  Text(
                                    invoice.udharAmount > 0 ? 'Udhar: ${invoice.udharAmount.toStringAsFixed(0)}' : 'Paid',
                                    style: TextStyle(color: invoice.udharAmount > 0 ? Colors.redAccent : Colors.green, fontSize: 12, fontWeight: FontWeight.w600),
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
