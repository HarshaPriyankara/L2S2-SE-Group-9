import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/expense.dart';
import '../../services/expense_repository.dart';
import '../../utils/formatters.dart';

/// Used for both "Add Expense" and (when [expense] is given) "Edit Expense".
class AddExpenseScreen extends StatefulWidget {
  final Expense? expense;

  const AddExpenseScreen({super.key, this.expense});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _repo = ExpenseRepository.instance;
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;

  int? _categoryId;
  late DateTime _date;
  late String _paymentMethod;
  bool _categoryError = false;
  bool _saving = false;

  bool get _isEdit => widget.expense != null;

  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    _titleController = TextEditingController(text: e?.title ?? '');
    _amountController = TextEditingController(
      text: e == null ? '' : e.amount.toStringAsFixed(2),
    );
    _noteController = TextEditingController(text: e?.note ?? '');
    _categoryId = e?.categoryId;
    _date = e?.date ?? DateTime.now();
    _paymentMethod = e?.paymentMethod ?? Expense.paymentMethods.first;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _save() async {
    final formOk = _formKey.currentState!.validate();
    if (_categoryId == null) {
      setState(() => _categoryError = true);
    }
    if (!formOk || _categoryId == null) return;

    final amount = double.parse(_amountController.text.trim().replaceAll(',', ''));
    final title = _titleController.text.trim();
    final note = _noteController.text.trim();

    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await _repo.updateExpense(
          Expense(
            id: widget.expense!.id,
            title: title,
            categoryId: _categoryId!,
            amount: amount,
            date: _date,
            paymentMethod: _paymentMethod,
            note: note,
          ),
        );
      } else {
        await _repo.addExpense(
          title: title,
          categoryId: _categoryId!,
          amount: amount,
          date: _date,
          paymentMethod: _paymentMethod,
          note: note,
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isEdit ? 'Expense updated' : 'Expense added'),
      ),
    );
    Navigator.pop(context);
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = _repo.categories;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Expense' : 'Add Expense'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _titleController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Expense title',
                      hintText: 'e.g. Electricity bill',
                      prefixIcon: Icon(Icons.edit_note),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a title';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 18),

                  TextFormField(
                    controller: _amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixText: 'Rs. ',
                      prefixIcon: Icon(Icons.payments),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final parsed = double.tryParse(
                        (value ?? '').trim().replaceAll(',', ''),
                      );
                      if (parsed == null) {
                        return 'Enter a valid amount';
                      }
                      if (parsed <= 0) {
                        return 'Amount must be greater than 0';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 22),

                  _label('Category'),
                  if (categories.isEmpty)
                    const Text(
                      'No categories yet. Add one from "Expense Categories" first.',
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in categories)
                          ChoiceChip(
                            avatar: Icon(c.icon, size: 18, color: c.color),
                            label: Text(c.name),
                            selected: _categoryId == c.id,
                            onSelected: (_) {
                              setState(() {
                                _categoryId = c.id;
                                _categoryError = false;
                              });
                            },
                          ),
                      ],
                    ),
                  if (_categoryError)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 4),
                      child: Text(
                        'Please select a category',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),

                  const SizedBox(height: 22),

                  _label('Date'),
                  InkWell(
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(formatDate(_date)),
                    ),
                  ),

                  const SizedBox(height: 22),

                  _label('Payment method'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final m in Expense.paymentMethods)
                        ChoiceChip(
                          label: Text(m),
                          selected: _paymentMethod == m,
                          onSelected: (_) {
                            setState(() => _paymentMethod = m);
                          },
                        ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  TextFormField(
                    controller: _noteController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Note (optional)',
                      alignLabelWithHint: true,
                      prefixIcon: Padding(
                        padding: EdgeInsets.only(bottom: 44),
                        child: Icon(Icons.notes),
                      ),
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 28),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: const Icon(Icons.save),
                          label: Text(
                            _saving
                                ? 'Saving...'
                                : (_isEdit ? 'Update' : 'Save Expense'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
