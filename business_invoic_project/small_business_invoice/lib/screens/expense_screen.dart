import 'package:flutter/material.dart';
import '../services/database_helper.dart';

class ExpenseScreen extends StatefulWidget {
  /// true -> open the "Add New Expense" dialog as soon as the screen loads
  final bool openAddOnStart;

  const ExpenseScreen({super.key, this.openAddOnStart = false});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  List<Map<String, dynamic>> _expenses = [];
  List<Map<String, dynamic>> _filteredExpenses = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _suppliers = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  // Default expense category (ID 1) delete karanna denne naha
  static const int _defaultCategoryId = 1;

  // DB eke CHECK constraint ekata hari values (CASH, CARD, BANK_TRANSFER, CHEQUE)
  // Key = DB value, Value = screen eke pennanna label
  static const Map<String, String> _paymentTypes = {
    'CASH': 'Cash',
    'CARD': 'Card',
    'BANK_TRANSFER': 'Bank Transfer',
    'CHEQUE': 'Cheque',
  };

  @override
  void initState() {
    super.initState();
    _refreshExpenses().then((_) {
      // Dashboard "Add Expense" quick action -> open the form straight away
      if (widget.openAddOnStart && mounted) _showExpenseDialog();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshExpenses() async {
    setState(() => _isLoading = true);
    final expenses = await DatabaseHelper.instance.getExpenses();
    final categories = await DatabaseHelper.instance.getExpenseCategories();
    final suppliers = await DatabaseHelper.instance.getSuppliers();
    if (!mounted) return;
    setState(() {
      _expenses = expenses;
      _categories = categories;
      _suppliers = suppliers;
      _isLoading = false;
    });
    _applySearch(_searchController.text);
  }

  // Search filter
  void _applySearch(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredExpenses = List.from(_expenses);
      } else {
        _filteredExpenses = _expenses.where((e) {
          final cat = (e['ExCatName'] ?? '').toString().toLowerCase();
          final supplier = (e['SupplierName'] ?? '').toString().toLowerCase();
          final notes = (e['Notes'] ?? '').toString().toLowerCase();
          final pay = _paymentLabel(e['PaymentType']).toLowerCase();
          final amount = (e['Amount'] ?? '').toString();
          return cat.contains(q) ||
              supplier.contains(q) ||
              notes.contains(q) ||
              pay.contains(q) ||
              amount.contains(q);
        }).toList();
      }
    });
  }

  String _paymentLabel(dynamic dbValue) =>
      _paymentTypes[dbValue?.toString()] ?? (dbValue?.toString() ?? 'Cash');

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ------------------------------------------------------------------
  // Category manager
  // ------------------------------------------------------------------
  void _showCategoryManager() {
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Manage Categories'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: textController,
                        decoration: const InputDecoration(
                          labelText: 'New Category Name',
                          prefixIcon: Icon(Icons.category),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.blue),
                      onPressed: () async {
                        final name = textController.text.trim();
                        if (name.isEmpty) return;
                        await DatabaseHelper.instance.insertExpenseCategory(name);
                        textController.clear();
                        final cats =
                            await DatabaseHelper.instance.getExpenseCategories();
                        if (!mounted) return;
                        setState(() => _categories = cats);
                        setDialogState(() {});
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      final bool isDefault = cat['ExCatID'] == _defaultCategoryId;
                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.orange,
                          child: Icon(Icons.label, color: Colors.white),
                        ),
                        title: Text(cat['ExCatName']),
                        trailing: isDefault
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () async {
                                  await DatabaseHelper.instance
                                      .deleteExpenseCategory(cat['ExCatID']);
                                  if (!mounted) return;
                                  _refreshExpenses().then((_) {
                                    if (dialogContext.mounted) {
                                      setDialogState(() {});
                                    }
                                  });
                                },
                              ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Add / Edit expense dialog
  // ------------------------------------------------------------------
  void _showExpenseDialog({Map<String, dynamic>? expense}) {
    final amountController = TextEditingController(
        text: expense != null ? expense['Amount'].toString() : '');
    final notesController =
        TextEditingController(text: expense?['Notes']?.toString() ?? '');
    final formKey = GlobalKey<FormState>();

    int? selectedCategory = expense?['ExCatID'] as int? ?? _defaultCategoryId;
    int? selectedSupplier = expense?['SupplierID'] as int?;
    String paymentType = _paymentTypes.containsKey(expense?['PaymentType'])
        ? expense!['PaymentType']
        : 'CASH';

    DateTime selectedDate =
        DateTime.tryParse(expense?['ExpenseDate']?.toString() ?? '') ??
            DateTime.now();

    // Category eka delete wela thibunoth default ekata
    if (!_categories.any((c) => c['ExCatID'] == selectedCategory)) {
      selectedCategory = _categories.isNotEmpty
          ? _categories.first['ExCatID'] as int
          : null;
    }
    // Supplier eka delete wela thibunoth clear karanna
    if (!_suppliers.any((s) => s['SupplierID'] == selectedSupplier)) {
      selectedSupplier = null;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(expense == null ? 'Add New Expense' : 'Edit Expense'),
          content: Form(
            key: formKey,
            child: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Amount (Rs.) *',
                        prefixIcon: Icon(Icons.payments),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter amount';
                        }
                        final n = double.tryParse(val.trim());
                        if (n == null || n <= 0) {
                          return 'Enter a valid amount';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      initialValue: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category *',
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: _categories
                          .map((cat) => DropdownMenuItem<int>(
                                value: cat['ExCatID'] as int,
                                child: Text(cat['ExCatName']),
                              ))
                          .toList(),
                      validator: (val) =>
                          val == null ? 'Please select a category' : null,
                      onChanged: (val) =>
                          setDialogState(() => selectedCategory = val),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int?>(
                      initialValue: selectedSupplier,
                      decoration: const InputDecoration(
                        labelText: 'Supplier (optional)',
                        prefixIcon: Icon(Icons.local_shipping),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('None'),
                        ),
                        ..._suppliers.map((s) => DropdownMenuItem<int?>(
                              value: s['SupplierID'] as int,
                              child: Text(s['SupplierName']),
                            )),
                      ],
                      onChanged: (val) =>
                          setDialogState(() => selectedSupplier = val),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: paymentType,
                      decoration: const InputDecoration(
                        labelText: 'Payment Type',
                        prefixIcon: Icon(Icons.credit_card),
                      ),
                      items: _paymentTypes.entries
                          .map((e) => DropdownMenuItem<String>(
                                value: e.key,
                                child: Text(e.value),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => paymentType = val);
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: dialogContext,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setDialogState(() => selectedDate = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date',
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(_formatDate(selectedDate)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        prefixIcon: Icon(Icons.notes),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final String notes = notesController.text.trim();
                  final Map<String, dynamic> data = {
                    'Amount': double.parse(amountController.text.trim()),
                    'PaymentType': paymentType,
                    'Notes': notes.isEmpty ? null : notes,
                    'ExCatID': selectedCategory,
                    'SupplierID': selectedSupplier,
                    'ExpenseDate': _formatDate(selectedDate),
                  };

                  try {
                    if (expense == null) {
                      await DatabaseHelper.instance.insertExpense(data);
                    } else {
                      data['ExID'] = expense['ExID'];
                      await DatabaseHelper.instance.updateExpense(data);
                    }

                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                    if (mounted) {
                      _refreshExpenses();
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(
                          content: Text('Error: ${e.toString()}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              child: Text(expense == null ? 'Save' : 'Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> expense) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Expense'),
        content: Text(
            'Are you sure you want to delete this expense of Rs. ${expense['Amount']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await DatabaseHelper.instance.deleteExpense(expense['ExID']);
              if (mounted) _refreshExpenses();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // UI
  // ------------------------------------------------------------------
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: _applySearch,
              decoration: InputDecoration(
                hintText: 'Search by category, supplier, notes or amount...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _applySearch('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: _showCategoryManager,
            icon: const Icon(Icons.category),
            label: const Text('Categories'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_expenses.isEmpty) {
      return const Center(child: Text('No expenses found.'));
    }
    if (_filteredExpenses.isEmpty) {
      return const Center(child: Text('No results found.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredExpenses.length,
      itemBuilder: (context, index) {
        final item = _filteredExpenses[index];
        final String category = (item['ExCatName'] ?? 'General').toString();
        final String supplier = (item['SupplierName'] ?? '').toString();
        final String notes = (item['Notes'] ?? '').toString();
        final String date = (item['ExpenseDate'] ?? '').toString();
        final bool isCash = item['PaymentType'] == 'CASH';
        final double amount = (item['Amount'] as num?)?.toDouble() ?? 0;

        final List<String> parts = [
          category,
          _paymentLabel(item['PaymentType']),
          if (date.isNotEmpty) date,
          if (supplier.isNotEmpty) 'Supplier: $supplier',
          if (notes.isNotEmpty) notes,
        ];

        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange,
              child: Icon(
                isCash ? Icons.money : Icons.credit_card,
                color: Colors.white,
              ),
            ),
            title: Text(
              'Rs. ${amount.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(parts.join(' | ')),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _showExpenseDialog(expense: item),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _confirmDelete(item),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(child: _buildList()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showExpenseDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
    );
  }
}