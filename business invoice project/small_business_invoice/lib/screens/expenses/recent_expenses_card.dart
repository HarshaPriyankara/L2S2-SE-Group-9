import 'package:flutter/material.dart';

import '../../models/expense.dart';
import '../../services/expense_repository.dart';
import '../../utils/formatters.dart';
import 'expense_details_screen.dart';
import 'expense_list_screen.dart';

/// "Recent Expenses" section for the Dashboard: shows the latest 5 expenses.
class RecentExpensesCard extends StatelessWidget {
  const RecentExpensesCard({super.key});

  static const int _maxItems = 5;

  @override
  Widget build(BuildContext context) {
    final repo = ExpenseRepository.instance;

    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        if (repo.isLoading && repo.expenses.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(30),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (repo.loadError != null && repo.expenses.isEmpty) {
          return _messageCard(
            icon: Icons.cloud_off,
            title: 'Could not load expenses',
            message: repo.loadError!,
          );
        }

        if (repo.expenses.isEmpty) {
          return _messageCard(
            icon: Icons.money_off,
            title: 'No expenses yet',
            message: 'Your recent expenses will appear here.',
          );
        }

        // Newest first (by date, then by id)
        final sorted = [...repo.expenses]..sort((a, b) {
            final byDate = b.date.compareTo(a.date);
            return byDate != 0 ? byDate : b.id.compareTo(a.id);
          });
        final recent = sorted.take(_maxItems).toList();

        return Card(
          child: Column(
            children: [
              for (var i = 0; i < recent.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _tile(context, repo, recent[i]),
              ],
              const Divider(height: 1),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ExpenseListScreen(),
                    ),
                  ),
                  child: const Text('View all expenses'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tile(BuildContext context, ExpenseRepository repo, Expense e) {
    final category = repo.categoryById(e.categoryId);

    return ListTile(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ExpenseDetailsScreen(expenseId: e.id),
        ),
      ),
      leading: CircleAvatar(
        backgroundColor: category.color.shade100,
        child: Icon(category.icon, color: category.color.shade700),
      ),
      title: Text(
        e.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text('${category.name} • ${formatDate(e.date)}'),
      trailing: Text(
        formatMoney(e.amount),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _messageCard({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Center(
          child: Column(
            children: [
              Icon(icon, size: 55),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
