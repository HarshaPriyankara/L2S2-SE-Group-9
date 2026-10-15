import 'package:flutter/material.dart';

import '../../models/expense.dart';
import '../../services/expense_repository.dart';
import '../../utils/formatters.dart';
import 'add_expense_screen.dart';
import 'connection_error_view.dart';

class ExpenseListScreen extends StatefulWidget {
  const ExpenseListScreen({super.key});

  @override
  State<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends State<ExpenseListScreen> {
  final _repo = ExpenseRepository.instance;

  String _query = '';
  int? _categoryFilter; // null = all categories

  List<Expense> _filtered() {
    final q = _query.trim().toLowerCase();

    final list = _repo.expenses.where((e) {
      if (_categoryFilter != null && e.categoryId != _categoryFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return e.title.toLowerCase().contains(q) ||
          e.note.toLowerCase().contains(q);
    }).toList();

    list.sort((a, b) => b.date.compareTo(a.date)); // newest first
    return list;
  }

  void _openAdd() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
    );
  }

  void _openEdit(Expense expense) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddExpenseScreen(expense: expense)),
    );
  }

  Future<void> _confirmDelete(Expense expense) async {
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

    if (ok == true) {
      var message = 'Expense deleted';
      try {
        await _repo.deleteExpense(expense.id);
      } on ApiException catch (e) {
        message = e.message;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Expense List')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAdd,
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
      body: ListenableBuilder(
        listenable: _repo,
        builder: (context, _) {
          if (_repo.isLoading && _repo.expenses.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_repo.loadError != null &&
              _repo.expenses.isEmpty &&
              _repo.categories.isEmpty) {
            return ConnectionErrorView(
              message: _repo.loadError!,
              onRetry: _repo.load,
            );
          }

          final items = _filtered();
          final total = items.fold(0.0, (sum, e) => sum + e.amount);
          final categories = _repo.categories;

          return Column(
            children: [
              // Search box
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  onChanged: (value) => setState(() => _query = value),
                  decoration: const InputDecoration(
                    hintText: 'Search expenses...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),

              // Category filter chips
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    ChoiceChip(
                      label: const Text('All'),
                      selected: _categoryFilter == null,
                      onSelected: (_) =>
                          setState(() => _categoryFilter = null),
                    ),
                    for (final c in categories)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: ChoiceChip(
                          label: Text(c.name),
                          selected: _categoryFilter == c.id,
                          onSelected: (_) =>
                              setState(() => _categoryFilter = c.id),
                        ),
                      ),
                  ],
                ),
              ),

              // Total summary
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.money_off, size: 32),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _categoryFilter == null && _query.isEmpty
                                    ? 'Total Expenses'
                                    : 'Filtered Total',
                              ),
                              Text(
                                formatMoney(total),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text('${items.length} item(s)'),
                      ],
                    ),
                  ),
                ),
              ),

              // List
              Expanded(
                child: items.isEmpty
                    ? _emptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                        itemCount: items.length,
                        itemBuilder: (context, index) =>
                            _expenseCard(items[index]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _emptyState() {
    final hasData = _repo.expenses.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.money_off, size: 55),
            const SizedBox(height: 12),
            Text(
              hasData ? 'No matching expenses' : 'No expenses yet',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text(
              hasData
                  ? 'Try a different search or category.'
                  : 'Tap "Add Expense" to record your first expense.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _expenseCard(Expense e) {
    final category = _repo.categoryById(e.categoryId);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () => _openEdit(e),
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
        subtitle: Text(
          '${category.name} • ${formatDate(e.date)}\n${e.paymentMethod}',
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formatMoney(e.amount),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _openEdit(e);
                } else {
                  _confirmDelete(e);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
