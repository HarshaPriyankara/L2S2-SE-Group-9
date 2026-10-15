import 'package:flutter/material.dart';

import '../../models/expense.dart';
import '../../services/expense_repository.dart';
import '../../utils/formatters.dart';
import 'add_expense_screen.dart';

/// Shows every detail of one expense, with Edit and Delete actions.
class ExpenseDetailsScreen extends StatefulWidget {
  final int expenseId;

  const ExpenseDetailsScreen({super.key, required this.expenseId});

  @override
  State<ExpenseDetailsScreen> createState() => _ExpenseDetailsScreenState();
}

class _ExpenseDetailsScreenState extends State<ExpenseDetailsScreen> {
  final _repo = ExpenseRepository.instance;

  Expense? _find() {
    for (final e in _repo.expenses) {
      if (e.id == widget.expenseId) return e;
    }
    return null;
  }

  void _edit(Expense expense) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddExpenseScreen(expense: expense)),
    );
  }

  Future<void> _delete(Expense expense) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete expense?'),
        content: Text(
          '"${expense.title}" (${formatMoney(expense.amount)}) will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await _repo.deleteExpense(expense.id);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Expense deleted')),
    );
    Navigator.pop(context);
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _repo,
      builder: (context, _) {
        final expense = _find();

        if (expense == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Expense Details')),
            body: const Center(child: Text('This expense no longer exists.')),
          );
        }

        final category = _repo.categoryById(expense.categoryId);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Expense Details'),
            actions: [
              IconButton(
                tooltip: 'Edit',
                icon: const Icon(Icons.edit),
                onPressed: () => _edit(expense),
              ),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _delete(expense),
              ),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: icon, title and amount
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 32,
                              backgroundColor: category.color.shade100,
                              child: Icon(
                                category.icon,
                                size: 32,
                                color: category.color.shade700,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              expense.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              formatMoney(expense.amount),
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Details
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        child: Column(
                          children: [
                            _infoRow(Icons.category, 'Category', category.name),
                            const Divider(height: 1),
                            _infoRow(
                              Icons.calendar_today,
                              'Date',
                              formatDate(expense.date),
                            ),
                            const Divider(height: 1),
                            _infoRow(
                              Icons.payments,
                              'Payment method',
                              expense.paymentMethod,
                            ),
                            const Divider(height: 1),
                            _infoRow(
                              Icons.notes,
                              'Note',
                              expense.note.isEmpty ? '—' : expense.note,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _delete(expense),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Delete'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _edit(expense),
                            icon: const Icon(Icons.edit),
                            label: const Text('Edit'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
