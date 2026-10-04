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
  /// 'Admin' or 'Cashier' (comes from the logged-in user's UserRole)
  final String userRole;

  const DashboardScreen({super.key, this.userRole = 'Cashier'});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _NavItem {
  final String key;
  final IconData icon;
  final String label;
  final bool adminOnly; // hidden for Cashier
  const _NavItem(this.key, this.icon, this.label, {this.adminOnly = false});
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  bool _openExpenseForm = false; // set by the "Add Expense" quick action

  // Sidebar: default = collapsed (icons only)
  bool _isExpanded = false;
  static const double _collapsedWidth = 72;
  static const double _expandedWidth = 220;

  static const List<_NavItem> _allItems = [
    _NavItem('dashboard', Icons.dashboard, 'Dashboard', adminOnly: true),
    _NavItem('inventory', Icons.inventory, 'Inventory'),
    _NavItem('customers', Icons.people, 'Customers'),
    _NavItem('suppliers', Icons.local_shipping, 'Suppliers'),
    _NavItem('invoices', Icons.receipt_long, 'Invoices'),
    _NavItem('expenses', Icons.money_off, 'Expenses'),
    _NavItem('users', Icons.manage_accounts, 'Users', adminOnly: true),
  ];

  bool get _isAdmin => widget.userRole.trim().toLowerCase() == 'admin';

  // Menu items this user is allowed to see
  late final List<_NavItem> _navItems =
      _allItems.where((item) => _isAdmin || !item.adminOnly).toList();

  @override
  void initState() {
    super.initState();
    // Admin starts on the Dashboard, Cashier starts on Invoices (new sale)
    final start = _isAdmin ? 'dashboard' : 'invoices';
    _selectedIndex = _navItems.indexWhere((item) => item.key == start);
    if (_selectedIndex < 0) _selectedIndex = 0;
    _maximizeWindow();
  }

  // Jump to a page by key (ignored if this user has no access to it)
  void _goTo(String key, {bool openExpenseForm = false}) {
    final index = _navItems.indexWhere((item) => item.key == key);
    if (index < 0) return;
    setState(() {
      _selectedIndex = index;
      _openExpenseForm = openExpenseForm;
    });
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
    const overviewText = Text(
      'Overview of your business finances',
      style: TextStyle(fontSize: 16),
    );

    // Financial summary cards
    final cards = Wrap(
      spacing: 15,
      runSpacing: 15,
      children: [
        _summaryCard('Total Income', 'Rs. 0.00', Icons.trending_up),
        _summaryCard('Total Expenses', 'Rs. 0.00', Icons.money_off),
        _summaryCard('Net Profit', 'Rs. 0.00', Icons.account_balance_wallet),
        _summaryCard('Outstanding', 'Rs. 0.00', Icons.pending_actions),
      ],
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Wide window: Quick Actions sit on the right, starting on the
          // same line as the "Overview..." text.
          // Narrow window: Quick Actions go below the cards.
          final bool sideBySide = constraints.maxWidth >= 1300;

          if (sideBySide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(
                        height: 30,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: overviewText,
                        ),
                      ),
                      const SizedBox(height: 15),
                      cards,
                    ],
                  ),
                ),
                const SizedBox(width: 32),
                SizedBox(
                  width: 340,
                  child: _buildQuickActions(vertical: true),
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              overviewText,
              const SizedBox(height: 25),
              cards,
              const SizedBox(height: 35),
              _buildQuickActions(vertical: false),
            ],
          );
        },
      ),
    );
  }

  Widget _buildQuickActions({required bool vertical}) {
    final createInvoice = FilledButton.icon(
      // Invoices page opens on the "New Sale" form
      onPressed: () => _goTo('invoices'),
      style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
      icon: const Icon(Icons.add, size: 22),
      label: const Text(
        'Create Invoice',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );

    final addExpense = OutlinedButton.icon(
      // Opens Expenses page + the "Add New Expense" form
      onPressed: () => _goTo('expenses', openExpenseForm: true),
      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
      icon: const Icon(Icons.add, size: 22),
      label: const Text(
        'Add Expense',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(
          height: 30,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Quick Actions',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 15),
        if (vertical) ...[
          SizedBox(width: double.infinity, child: createInvoice),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: addExpense),
        ] else
          Row(
            children: [
              Expanded(child: createInvoice),
              const SizedBox(width: 12),
              Expanded(child: addExpense),
            ],
          ),
      ],
    );
  }

  Widget _getSelectedScreen() {
    switch (_navItems[_selectedIndex].key) {
      case 'dashboard':
        return _buildDashboardOverview();
      case 'inventory':
        return const InventoryScreen();
      case 'customers':
        return const CustomerScreen();
      case 'suppliers':
        return const SupplierScreen();
      case 'invoices':
        return const InvoiceScreen();
      case 'expenses':
        return ExpenseScreen(openAddOnStart: _openExpenseForm);
      case 'users':
        return const UserScreen();
      default:
        return const InvoiceScreen();
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