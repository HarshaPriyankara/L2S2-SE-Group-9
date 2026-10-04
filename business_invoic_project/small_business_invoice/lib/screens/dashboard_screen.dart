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

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  bool _openExpenseForm = false; // set by the "Add Expense" quick action

  // Sidebar: default = collapsed (icons only)
  bool _isExpanded = false;
  static const double _collapsedWidth = 72;
  static const double _expandedWidth = 220;

  static const List<_NavItem> _navItems = [
    _NavItem(Icons.dashboard, 'Dashboard'),
    _NavItem(Icons.inventory, 'Inventory'),
    _NavItem(Icons.people, 'Customers'),
    _NavItem(Icons.local_shipping, 'Suppliers'),
    _NavItem(Icons.receipt_long, 'Invoices'),
    _NavItem(Icons.money_off, 'Expenses'),
    _NavItem(Icons.manage_accounts, 'Users'),
  ];

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
    // Back to the smaller, centered login window
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      await windowManager.unmaximize();
      await windowManager.setSize(const Size(1000, 640));
      await windowManager.setMinimumSize(const Size(800, 600));
      await windowManager.center();
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  void _toggleSidebar() => setState(() => _isExpanded = !_isExpanded);

  // ---------------- Sidebar ----------------

  Widget _sidebarTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool selected = false,
    Color? color,
  }) {
    final cs = Theme.of(context).colorScheme;
    final Color fg = color ?? (selected ? cs.primary : cs.onSurfaceVariant);

    return Tooltip(
      message: _isExpanded ? '' : label,
      waitDuration: const Duration(milliseconds: 400),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Material(
          color: selected ? cs.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: SizedBox(
              height: 48,
              child: Row(
                children: [
                  // (72 - 16 padding - 24 icon) / 2 = 16 -> icon stays centered when collapsed
                  const SizedBox(width: 16),
                  Icon(icon, color: fg),
                  const SizedBox(width: 16),
                  if (_isExpanded)
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        softWrap: false,
                        style: TextStyle(
                          color: fg,
                          fontWeight:
                              selected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    final cs = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      width: _isExpanded ? _expandedWidth : _collapsedWidth,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(right: BorderSide(color: cs.outlineVariant)),
      ),
      child: OverflowBox(
        alignment: Alignment.centerLeft,
        minWidth: 0,
        maxWidth: _expandedWidth,
        child: SizedBox(
          width: _expandedWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header - click to toggle
              InkWell(
                onTap: _toggleSidebar,
                child: SizedBox(
                  height: 64,
                  child: Row(
                    children: [
                      const SizedBox(width: 24),
                      Icon(
                        _isExpanded ? Icons.menu_open : Icons.menu,
                        color: cs.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 16),
                      if (_isExpanded)
                        const Expanded(
                          child: Text(
                            'EasyBill',
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.clip,
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Menu items
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    for (int i = 0; i < _navItems.length; i++)
                      _sidebarTile(
                        icon: _navItems[i].icon,
                        label: _navItems[i].label,
                        selected: _selectedIndex == i,
                        onTap: () => setState(() {
                          _selectedIndex = i;
                          _openExpenseForm = false;
                        }),
                      ),
                  ],
                ),
              ),

              const Divider(height: 1),
              const SizedBox(height: 8),
              _sidebarTile(
                icon: Icons.logout,
                label: 'Logout',
                color: Colors.red,
                onTap: _handleLogout,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- Dashboard overview ----------------

  Widget _buildDashboardOverview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
              _summaryCard(
                  'Net Profit', 'Rs. 0.00', Icons.account_balance_wallet),
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
                  // Invoices page opens on the "New Sale" form
                  onPressed: () => setState(() {
                    _selectedIndex = 4;
                    _openExpenseForm = false;
                  }),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 52),
                  ),
                  icon: const Icon(Icons.add, size: 22),
                  label: const Text(
                    'Create Invoice',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  // Opens Expenses page + the "Add New Expense" form
                  onPressed: () => setState(() {
                    _selectedIndex = 5;
                    _openExpenseForm = true;
                  }),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 52),
                  ),
                  icon: const Icon(Icons.add, size: 22),
                  label: const Text(
                    'Add Expense',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
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
        return ExpenseScreen(openAddOnStart: _openExpenseForm);
      case 6:
        return const UserScreen();
      default:
        return _buildDashboardOverview();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(
            child: Column(
              children: [
                _buildPageHeader(),
                Expanded(child: _getSelectedScreen()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Page title shown at the top of every page
  Widget _buildPageHeader() {
    final item = _navItems[_selectedIndex];

    return Container(
      width: double.infinity,
      height: 64, // same height as the sidebar header
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text(
            item.label,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ],
      ),
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
              Text(value,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}