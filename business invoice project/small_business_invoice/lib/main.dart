import 'package:flutter/material.dart';
import 'screens/dashboard_screen.dart';

void main() {
  runApp(const InvoiceExpenseApp());
}

class InvoiceExpenseApp extends StatelessWidget {
  const InvoiceExpenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title: 'Small Business Invoice & Expense Management System',

      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),

      home: const DashboardScreen(),
    );
  }
}