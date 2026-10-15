import 'package:flutter/material.dart';

import '../../models/expense.dart';
import '../../services/expense_repository.dart';
import '../../utils/formatters.dart';
import 'connection_error_view.dart';

class ExpenseCategoriesScreen extends StatefulWidget {
  const ExpenseCategoriesScreen({super.key});

  @override
  State<ExpenseCategoriesScreen> createState() =>
      _ExpenseCategoriesScreenState();
}

class _ExpenseCategoriesScreenState extends State<ExpenseCategoriesScreen> {
  final _repo = ExpenseRepository.instance;

  void _openDialog({ExpenseCategory? existing}) {
    showDialog<void>(
      context: context,
      builder: (_) => _CategoryDialog(existing: existing),
    );
  }

  Future<void> _confirmDelete(ExpenseCategory category) async {
    // A category that still has expenses cannot be deleted.
    if (_repo.expenseCountFor(category.id) > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '"${category.name}" is used by '
            '${_repo.expenseCountFor(category.id)} expense(s) and cannot be deleted.',
          ),
        ),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text('"${category.name}" will be removed.'),
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
      var message = 'Category deleted';
      try {
        await _repo.deleteCategory(category.id);
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
      appBar: AppBar(title: const Text('Expense Categories')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Category'),
      ),
      body: ListenableBuilder(
        listenable: _repo,
        builder: (context, _) {
          final categories = _repo.categories;

          if (_repo.isLoading && categories.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_repo.loadError != null && categories.isEmpty) {
            return ConnectionErrorView(
              message: _repo.loadError!,
              onRetry: _repo.load,
            );
          }

          if (categories.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.category, size: 55),
                    SizedBox(height: 12),
                    Text(
                      'No categories yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text('Tap "Add Category" to create one.'),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final c = categories[index];
              final count = _repo.expenseCountFor(c.id);
              final total = _repo.totalFor(c.id);

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  onTap: () => _openDialog(existing: c),
                  leading: CircleAvatar(
                    backgroundColor: c.color.shade100,
                    child: Icon(c.icon, color: c.color.shade700),
                  ),
                  title: Text(
                    c.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text('$count expense(s) • ${formatMoney(total)}'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _openDialog(existing: c);
                      } else {
                        _confirmDelete(c);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Dialog used for both adding and editing a category.
class _CategoryDialog extends StatefulWidget {
  final ExpenseCategory? existing;

  const _CategoryDialog({this.existing});

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  final _repo = ExpenseRepository.instance;

  late final TextEditingController _nameController;
  late int _iconIndex;
  late int _colorIndex;
  String? _error;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _iconIndex = widget.existing?.iconIndex ?? 0;
    _colorIndex = widget.existing?.colorIndex ?? 0;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      setState(() => _error = 'Please enter a category name');
      return;
    }
    if (_repo.categoryNameExists(name, exceptId: widget.existing?.id)) {
      setState(() => _error = 'This category already exists');
      return;
    }

    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await _repo.updateCategory(
          ExpenseCategory(
            id: widget.existing!.id,
            name: name,
            iconIndex: _iconIndex,
            colorIndex: _colorIndex,
          ),
        );
      } else {
        await _repo.addCategory(
          name: name,
          iconIndex: _iconIndex,
          colorIndex: _colorIndex,
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
      return;
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final previewColor = ExpenseCategory.categoryColors[_colorIndex];

    return AlertDialog(
      title: Text(_isEdit ? 'Edit Category' : 'Add Category'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Category name',
                border: const OutlineInputBorder(),
                errorText: _error,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),

            const SizedBox(height: 18),
            const Text('Icon', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < ExpenseCategory.categoryIcons.length; i++)
                  InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => setState(() => _iconIndex = i),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: i == _iconIndex
                          ? previewColor.shade100
                          : scheme.surfaceContainerHighest,
                      child: Icon(
                        ExpenseCategory.categoryIcons[i],
                        size: 20,
                        color: i == _iconIndex ? previewColor.shade700 : null,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 18),
            const Text('Colour', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < ExpenseCategory.categoryColors.length; i++)
                  InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => setState(() => _colorIndex = i),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: ExpenseCategory.categoryColors[i],
                      child: i == _colorIndex
                          ? const Icon(Icons.check,
                              size: 18, color: Colors.white)
                          : null,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving...' : 'Save'),
        ),
      ],
    );
  }
}
