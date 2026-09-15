import 'package:flutter/material.dart';

void main() {
  runApp(const InvoiceApp());
}

class InvoiceApp extends StatelessWidget {
  const InvoiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Small Business Invoice',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Dashboard'),
      ),

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
                  Text(
                    'Small Business',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text('Invoice & Expense Management'),
                ],
              ),
            ),

            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              onTap: () {},
            ),

            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text('Invoices'),
              onTap: () {},
            ),

            ListTile(
              leading: const Icon(Icons.money_off),
              title: const Text('Expenses'),
              onTap: () {},
            ),

            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Customers'),
              onTap: () {},
            ),

            ListTile(
              leading: const Icon(Icons.bar_chart),
              title: const Text('Reports'),
              onTap: () {},
            ),
          ],
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Overview',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            Wrap(
              spacing: 15,
              runSpacing: 15,
              children: [
                _summaryCard(
                  'Total Sales',
                  'Rs. 0.00',
                  Icons.trending_up,
                ),
                _summaryCard(
                  'Expenses',
                  'Rs. 0.00',
                  Icons.money_off,
                ),
                _summaryCard(
                  'Profit',
                  'Rs. 0.00',
                  Icons.account_balance_wallet,
                ),
                _summaryCard(
                  'Invoices',
                  '0',
                  Icons.receipt_long,
                ),
              ],
            ),

            const SizedBox(height: 30),

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
                    onPressed: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const CreateInvoiceScreen(),
    ),
  );
},,
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

            const SizedBox(height: 30),

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
                padding: const EdgeInsets.all(25),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.receipt_long,
                        size: 50,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'No invoices yet',
                        style: TextStyle(fontSize: 18),
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
          ],
        ),
      ),
    );
  }

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
              Icon(icon, size: 32),
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