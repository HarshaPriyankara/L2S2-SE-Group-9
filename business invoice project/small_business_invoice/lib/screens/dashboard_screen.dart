import 'package:flutter/material.dart';

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

            ListTile(
              leading: const Icon(Icons.money_off),
              title: const Text('Expenses'),
              onTap: () {
                Navigator.pop(context);
              },
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

                _summaryCard(
                  'Total Expenses',
                  'Rs. 0.00',
                  Icons.money_off,
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
                    onPressed: () {},
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