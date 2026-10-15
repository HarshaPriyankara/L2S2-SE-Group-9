import 'package:flutter/material.dart';

import 'expenses/add_expense_screen.dart';
import 'expenses/expense_categories_screen.dart';
import 'expenses/expense_list_screen.dart';
import '../services/expense_repository.dart';
import '../utils/formatters.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Small Business Management'),
      ),

      // Side navigation menu
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.business,
                    size: 45,
                  ),

                  SizedBox(height: 10),

                  Text(
                    'Small Business',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  Text(
                    'Invoice & Expense Management',
                  ),
                ],
              ),
            ),

            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              onTap: () {
                Navigator.pop(context);
              },
            ),

            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Customers'),
              onTap: () {
                Navigator.pop(context);
              },
            ),

            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text('Invoices'),
              onTap: () {
                Navigator.pop(context);
              },
            ),

            ExpansionTile(
              leading: const Icon(Icons.money_off),
              title: const Text('Expenses'),
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.only(left: 40, right: 16),
                  leading: const Icon(Icons.add_circle_outline),
                  title: const Text('Add Expense'),
                  onTap: () => _go(context, const AddExpenseScreen()),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.only(left: 40, right: 16),
                  leading: const Icon(Icons.list_alt),
                  title: const Text('Expense List'),
                  onTap: () => _go(context, const ExpenseListScreen()),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.only(left: 40, right: 16),
                  leading: const Icon(Icons.category_outlined),
                  title: const Text('Expense Categories'),
                  onTap: () => _go(context, const ExpenseCategoriesScreen()),
                ),
              ],
            ),

            ListTile(
              leading: const Icon(Icons.account_balance),
              title: const Text('Financial Summary'),
              onTap: () {
                Navigator.pop(context);
              },
            ),

            const Divider(),

            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),

      // Dashboard content
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Financial Dashboard',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Overview of your business finances',
              style: TextStyle(
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 25),

            // Financial summary cards
            Wrap(
              spacing: 15,
              runSpacing: 15,
              children: [
                _summaryCard(
                  'Total Income',
                  'Rs. 0.00',
                  Icons.trending_up,
                ),

                // Live total from the database (updates when expenses change)
                ListenableBuilder(
                  listenable: ExpenseRepository.instance,
                  builder: (context, _) => _summaryCard(
                    'Total Expenses',
                    formatMoney(ExpenseRepository.instance.totalExpenses),
                    Icons.money_off,
                  ),
                ),

                _summaryCard(
                  'Net Profit',
                  'Rs. 0.00',
                  Icons.account_balance_wallet,
                ),

                _summaryCard(
                  'Outstanding',
                  'Rs. 0.00',
                  Icons.pending_actions,
                ),
              ],
            ),

            const SizedBox(height: 35),

            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
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
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AddExpenseScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Expense'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 35),

            const Text(
              'Recent Invoices',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 15),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.receipt_long,
                        size: 55,
                      ),

                      const SizedBox(height: 12),

                      const Text(
                        'No invoices yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 5),

                      const Text(
                        'Create your first invoice to get started.',
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),

            const Text(
              'Recent Expenses',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 15),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.money_off,
                        size: 55,
                      ),

                      const SizedBox(height: 12),

                      const Text(
                        'No expenses yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 5),

                      const Text(
                        'Your recent expenses will appear here.',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Close the drawer, then open a screen
  static void _go(BuildContext context, Widget screen) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  // Reusable financial summary card
  static Widget _summaryCard(
    String title,
    String value,
    IconData icon,
  ) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 32,
              ),

              const SizedBox(height: 15),

              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                ),
              ),

              const SizedBox(height: 5),

              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}