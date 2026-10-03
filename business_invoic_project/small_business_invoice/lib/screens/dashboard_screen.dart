import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'customer_screen.dart';
import 'supplier_screen.dart';
import 'user_screen.dart';
import 'inventory_screen.dart';
import 'invoice_screen.dart';
import 'expense_screen.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _maximizeWindow();
  }

  void _maximizeWindow() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      await windowManager.setMinimumSize(const Size(800, 600));
      await windowManager.maximize();
    }
  }

  void _handleLogout() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      await windowManager.unmaximize();
      await windowManager.setSize(const Size(450, 600));
      await windowManager.setMinimumSize(const Size(400, 550));
      await windowManager.center();
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  Widget _buildDashboardOverview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Financial Dashboard',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Overview of your business finances',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 25),

          // Financial summary cards
          Wrap(
            spacing: 15,
            runSpacing: 15,
            children: [
              _summaryCard('Total Income', 'Rs. 0.00', Icons.trending_up),
              _summaryCard('Total Expenses', 'Rs. 0.00', Icons.money_off),
              _summaryCard('Net Profit', 'Rs. 0.00', Icons.account_balance_wallet),
              _summaryCard('Outstanding', 'Rs. 0.00', Icons.pending_actions),
            ],
          ),
          const SizedBox(height: 35),
          const Text(
            'Quick Actions',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add),
                  label: const Text('Create Invoice'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add),
                  label: const Text('Add Expense'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _getSelectedScreen() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardOverview();
      case 1:
        return const InventoryScreen();
      case 2:
        return const CustomerScreen();
      case 3:
        return const SupplierScreen();
      case 4:
        return const InvoiceScreen();
      case 5:
        return const ExpenseScreen();
      case 6:
        return const UserScreen();
      default:
        return _buildDashboardOverview();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Small Business Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _handleLogout,
          ),
        ],
      ),

      // Side Navigation Menu (Drawer)
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.business, size: 45),
                  SizedBox(height: 10),
                  Text('EasyBill', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text('Invoice & Expense Management'),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              selected: _selectedIndex == 0,
              onTap: () {
                setState(() => _selectedIndex = 0);
                Navigator.pop(context); 
              },
            ),

            ListTile(
              leading: const Icon(Icons.inventory),
              title: const Text('Inventory'),
              selected: _selectedIndex == 1,
              onTap: () {
                setState(() => _selectedIndex = 1);
                Navigator.pop(context);
              },
            ),

            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Customers'),
              selected: _selectedIndex == 2,
              onTap: () {
                setState(() => _selectedIndex = 2);
                Navigator.pop(context); 
              },
            ),
            ListTile(
              leading: const Icon(Icons.local_shipping),
              title: const Text('Suppliers'),
              selected: _selectedIndex == 3,
              onTap: () {
                setState(() => _selectedIndex = 3);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text('Invoices'),
              selected: _selectedIndex == 4,
              onTap: () {
                setState(() => _selectedIndex = 4);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.money_off),
              title: const Text('Expenses'),
              selected: _selectedIndex == 5,
              onTap: () {
                setState(() => _selectedIndex = 5);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.manage_accounts),
              title: const Text('Users'),
              selected: _selectedIndex == 6,
              onTap: () {
                setState(() => _selectedIndex = 6);
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: _handleLogout,
            ),
          ],
        ),
      ),

      // Dynamic Body Content
      body: _getSelectedScreen(),
    );
  }

  Widget _summaryCard(String title, String value, IconData icon) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 32),
              const SizedBox(height: 15),
              Text(title, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 5),
              Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}