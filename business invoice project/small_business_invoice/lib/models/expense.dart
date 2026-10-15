import 'package:flutter/material.dart';

/// Maps to the MySQL table `expense_categories`.
class ExpenseCategory {
  final int id; // category_id
  final String name; // name
  final int iconIndex; // icon_index  (index into [categoryIcons])
  final int colorIndex; // color_index (index into [categoryColors])

  const ExpenseCategory({
    required this.id,
    required this.name,
    required this.iconIndex,
    required this.colorIndex,
  });

  /// Icons the user can pick from when creating a category.
  static const List<IconData> categoryIcons = [
    Icons.home_work,
    Icons.bolt,
    Icons.groups,
    Icons.inventory_2,
    Icons.local_shipping,
    Icons.campaign,
    Icons.category,
    Icons.restaurant,
    Icons.build,
    Icons.phone_android,
  ];

  /// Colours the user can pick from when creating a category.
  static const List<MaterialColor> categoryColors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.red,
    Colors.teal,
    Colors.pink,
    Colors.brown,
  ];

  IconData get icon => categoryIcons[iconIndex % categoryIcons.length];
  MaterialColor get color => categoryColors[colorIndex % categoryColors.length];

  /// Used if an expense points to a category that no longer exists.
  static const ExpenseCategory uncategorized = ExpenseCategory(
    id: 0,
    name: 'Uncategorized',
    iconIndex: 6,
    colorIndex: 7,
  );
}

/// Maps to the MySQL table `expenses`.
class Expense {
  final int id; // expense_id
  final String title; // title
  final int categoryId; // category_id
  final double amount; // amount
  final DateTime date; // expense_date
  final String paymentMethod; // payment_method
  final String note; // note

  const Expense({
    required this.id,
    required this.title,
    required this.categoryId,
    required this.amount,
    required this.date,
    required this.paymentMethod,
    required this.note,
  });

  static const List<String> paymentMethods = [
    'Cash',
    'Card',
    'Bank Transfer',
    'Online',
  ];
}
