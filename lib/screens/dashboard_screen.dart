import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_helper.dart';
import '../models/invoice.dart';

// Tamam screens ko import kar rahay hain
import 'bill_screen.dart';
import 'return_screen.dart';
import 'customer_ledger_screen.dart';
import 'products_screen.dart';
import 'invoice_history_screen.dart';
import 'settings_screen.dart'; // Settings screen ki nayi import

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int todayBillsCount = 0;
  double todayCash = 0.0;
  double todayUdhar = 0.0;
  int unSyncedCount = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  // Dashboard counters load karne ka function
  Future<void> _loadDashboardData() async {
    setState(() => isLoading = true);
    
    String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    List<Invoice> allInvoices = await DatabaseHelper.instance.getAllInvoices();
    
    int count = 0;
    double cash = 0.0;
    double udhar = 0.0;
    int unsynced = 0;

    for (var invoice in allInvoices) {
      if (invoice.isSynced == 0) unsynced++;
      
      // Aaj ki date filter
      if (invoice.date.startsWith(todayDate)) {
        // Return Invoices negative hoty hain, wo automatically net amount theek kar denge
        count++;
        cash += invoice.cashReceived;
        udhar += invoice.udharAmount;
      }
    }

    setState(() {
      todayBillsCount = count;
      todayCash = cash;
      todayUdhar = udhar;
      unSyncedCount = unsynced;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('POP Khata', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1565C0), // Thora professional blue color
        foregroundColor: Colors.white,
        actions: [
          // Naya Settings Button
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              ).then((_) => _loadDashboardData());
            },
          ),
          // Cloud Sync Badge
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Badge(
                label: Text(unSyncedCount.toString()),
                isLabelVisible: unSyncedCount > 0,
                backgroundColor: Colors.redAccent,
                child: IconButton(
                  icon: const Icon(Icons.cloud_sync),
                  tooltip: 'Sync Data',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Syncing data to Google Sheets... (Coming Soon)')),
                    );
                  },
                ),
              ),
            ),
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Aaj Ka Hisaab',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 16),
                    
                    // Daily Summary Counters
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCard(
                            title: 'Cash (Naqad)',
                            amount: 'Rs. ${todayCash.toStringAsFixed(0)}',
                            color: Colors.green,
                            icon: Icons.payments,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSummaryCard(
                            title: 'Udhar (Credit)',
                            amount: 'Rs. ${todayUdhar.toStringAsFixed(0)}',
                            color: Colors.redAccent,
                            icon: Icons.money_off,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildSummaryCard(
                      title: 'Kul Bills Aaj (Wapsi Samet)',
                      amount: todayBillsCount.toString(),
                      color: Colors.blueGrey,
                      icon: Icons.receipt_long,
                      isFullWidth: true,
                    ),
                    
                    const SizedBox(height: 32),
                    const Text(
                      'Main Menu',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 16),
                    
                    // Navigation Buttons Grid
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.1,
                      children: [
                        _buildNavButton(
                          title: 'New Bill\n(Naya Khata)',
                          icon: Icons.add_shopping_cart,
                          color: Colors.teal,
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const BillScreen())).then((_) => _loadDashboardData());
                          },
                        ),
                        _buildNavButton(
                          title: 'Maal Wapsi\n(Return)',
                          icon: Icons.assignment_return,
                          color: Colors.blueAccent,
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const ReturnScreen())).then((_) => _loadDashboardData());
                          },
                        ),
                        _buildNavButton(
                          title: 'Udhar Ledger\n(Khata)',
                          icon: Icons.menu_book,
                          color: Colors.orange,
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const CustomerLedgerScreen())).then((_) => _loadDashboardData());
                          },
                        ),
                        _buildNavButton(
                          title: 'History\n(Purane Bills)',
                          icon: Icons.history,
                          color: Colors.indigo,
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const InvoiceHistoryScreen())).then((_) => _loadDashboardData());
                          },
                        ),
                        _buildNavButton(
                          title: 'Products\n(Stock List)',
                          icon: Icons.inventory_2,
                          color: Colors.purple,
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const ProductsScreen())).then((_) => _loadDashboardData());
                          },
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryCard({required String title, required String amount, required Color color, required IconData icon, bool isFullWidth = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: color.withOpacity(0.8), fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            amount,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: isFullWidth ? 24 : 20),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton({required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }
}
