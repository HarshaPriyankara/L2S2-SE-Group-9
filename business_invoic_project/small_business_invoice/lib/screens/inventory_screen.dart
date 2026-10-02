import 'package:flutter/material.dart';
import '../services/database_helper.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _suppliers = [];
  bool _isLoading = true;

  final TextEditingController _searchController = TextEditingController();
  int? _categoryFilter; // null = all categories
  String _statusFilter = 'all'; // all | low | out

  static const int _defaultCategoryId = 1;
  static const int _defaultSupplierId = 1;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- helpers
  double _num(dynamic v) => (v as num?)?.toDouble() ?? 0;

  String _fmtQty(dynamic v) {
    final d = _num(v);
    return d == d.roundToDouble() ? d.toInt().toString() : d.toString();
  }

  String _fmtPrice(dynamic v) => _num(v).toStringAsFixed(2);

  /// ok | low | out
  String _statusOf(Map<String, dynamic> p) {
    final stock = _num(p['StockQuantity']);
    final min = _num(p['MinimumStock']);
    if (stock <= 0) return 'out';
    if (stock <= min) return 'low';
    return 'ok';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'out':
        return Colors.red;
      case 'low':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'out':
        return 'Out of Stock';
      case 'low':
        return 'Low Stock';
      default:
        return 'In Stock';
    }
  }

  void _showMessage(String msg, {Color color = Colors.red}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  // ---------------------------------------------------------------- data
  void _refresh() async {
    setState(() => _isLoading = true);
    final products = await DatabaseHelper.instance.getProducts();
    final categories = await DatabaseHelper.instance.getCategories();
    final suppliers = await DatabaseHelper.instance.getSuppliers();
    if (!mounted) return;
    setState(() {
      _products = products;
      _categories = categories;
      _suppliers = suppliers;
      // Category filter eka delete wela nam reset karanawa
      if (_categoryFilter != null &&
          !_categories.any((c) => c['CategoryID'] == _categoryFilter)) {
        _categoryFilter = null;
      }
      _isLoading = false;
    });
    _applyFilters();
  }

  void _applyFilters() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredProducts = _products.where((p) {
        if (_categoryFilter != null && p['CategoryID'] != _categoryFilter) {
          return false;
        }
        if (_statusFilter == 'low' && _statusOf(p) != 'low') return false;
        if (_statusFilter == 'out' && _statusOf(p) != 'out') return false;
        if (q.isEmpty) return true;
        final name = (p['ProductName'] ?? '').toString().toLowerCase();
        final cat = (p['CategoryName'] ?? '').toString().toLowerCase();
        final sup = (p['SupplierName'] ?? '').toString().toLowerCase();
        return name.contains(q) || cat.contains(q) || sup.contains(q);
      }).toList();
    });
  }

  // ---------------------------------------------------------------- product dialog
  String? _requiredNumber(String? val, String label) {
    if (val == null || val.trim().isEmpty) return 'Enter $label';
    final n = double.tryParse(val.trim());
    if (n == null) return 'Enter a valid number';
    if (n < 0) return 'Cannot be negative';
    return null;
  }

  void _showProductDialog({Map<String, dynamic>? product}) {
    final nameController =
        TextEditingController(text: product?['ProductName']?.toString() ?? '');
    final stockController = TextEditingController(
        text: product == null ? '0' : _fmtQty(product['StockQuantity']));
    final minController = TextEditingController(
        text: product == null ? '5' : _fmtQty(product['MinimumStock']));
    final supplierPriceController = TextEditingController(
        text: product == null ? '' : _fmtPrice(product['SupplierPrice']));
    final normalPriceController = TextEditingController(
        text: product == null ? '' : _fmtPrice(product['NormalPrice']));
    final ourPriceController = TextEditingController(
        text: product == null ? '' : _fmtPrice(product['OurPrice']));
    final formKey = GlobalKey<FormState>();

    int? selectedCategoryId = product == null
        ? _defaultCategoryId
        : product['CategoryID'] as int?;
    int? selectedSupplierId = product == null
        ? _defaultSupplierId
        : product['SupplierID'] as int?;
    if (!_categories.any((c) => c['CategoryID'] == selectedCategoryId)) {
      selectedCategoryId = null;
    }
    if (!_suppliers.any((s) => s['SupplierID'] == selectedSupplierId)) {
      selectedSupplierId = null;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(product == null ? 'Add New Product' : 'Edit Product'),
        content: SizedBox(
          width: 460,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Product Name *',
                      prefixIcon: Icon(Icons.inventory_2),
                    ),
                    validator: (val) => (val == null || val.trim().isEmpty)
                        ? 'Please enter product name'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    initialValue: selectedCategoryId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: _categories
                        .map((c) => DropdownMenuItem<int>(
                              value: c['CategoryID'] as int,
                              child: Text(c['CategoryName'].toString()),
                            ))
                        .toList(),
                    onChanged: (val) => selectedCategoryId = val,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    initialValue: selectedSupplierId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Supplier',
                      prefixIcon: Icon(Icons.local_shipping),
                    ),
                    items: _suppliers
                        .map((s) => DropdownMenuItem<int>(
                              value: s['SupplierID'] as int,
                              child: Text(s['SupplierName'].toString()),
                            ))
                        .toList(),
                    onChanged: (val) => selectedSupplierId = val,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: stockController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Stock Quantity *',
                            prefixIcon: Icon(Icons.warehouse),
                          ),
                          validator: (val) => _requiredNumber(val, 'quantity'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: minController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Minimum Stock *',
                            prefixIcon: Icon(Icons.warning_amber),
                          ),
                          validator: (val) =>
                              _requiredNumber(val, 'minimum stock'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: supplierPriceController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Supplier Price (Rs.) *',
                            prefixIcon: Icon(Icons.shopping_cart),
                          ),
                          validator: (val) => _requiredNumber(val, 'price'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: normalPriceController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Normal Price (Rs.) *',
                            prefixIcon: Icon(Icons.sell),
                          ),
                          validator: (val) => _requiredNumber(val, 'price'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: ourPriceController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Our Price (Rs.) *',
                      prefixIcon: Icon(Icons.price_check),
                    ),
                    validator: (val) => _requiredNumber(val, 'price'),
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
                final Map<String, dynamic> data = {
                  'ProductName': nameController.text.trim(),
                  'CategoryID': selectedCategoryId,
                  'SupplierID': selectedSupplierId,
                  'StockQuantity':
                      double.parse(stockController.text.trim()),
                  'MinimumStock': double.parse(minController.text.trim()),
                  'SupplierPrice':
                      double.parse(supplierPriceController.text.trim()),
                  'NormalPrice':
                      double.parse(normalPriceController.text.trim()),
                  'OurPrice': double.parse(ourPriceController.text.trim()),
                };

                try {
                  if (product == null) {
                    await DatabaseHelper.instance.insertProduct(data);
                  } else {
                    data['ProductID'] = product['ProductID'];
                    await DatabaseHelper.instance.updateProduct(data);
                  }

                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                  if (mounted) {
                    _refresh();
                  }
                } catch (e) {
                  _showMessage('Error: ${e.toString()}');
                }
              }
            },
            child: Text(product == null ? 'Save' : 'Update'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- stock adjust
  void _showAdjustStockDialog(Map<String, dynamic> product) {
    final qtyController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final double current = _num(product['StockQuantity']);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Adjust Stock'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(product['ProductName'].toString(),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Current stock: ${_fmtQty(current)}'),
              const SizedBox(height: 12),
              TextFormField(
                controller: qtyController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: true),
                decoration: const InputDecoration(
                  labelText: 'Quantity (+ add / - remove)',
                  prefixIcon: Icon(Icons.add_box),
                  hintText: 'e.g. 10 or -3',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Enter a quantity';
                  }
                  final n = double.tryParse(val.trim());
                  if (n == null) return 'Enter a valid number';
                  if (n == 0) return 'Quantity cannot be 0';
                  if (current + n < 0) return 'Stock cannot go below 0';
                  return null;
                },
              ),
            ],
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
                final qty = double.parse(qtyController.text.trim());
                try {
                  await DatabaseHelper.instance
                      .adjustStock(product['ProductID'] as int, qty);
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                  if (mounted) _refresh();
                } catch (e) {
                  _showMessage('Error: ${e.toString()}');
                }
              }
            },
            child: const Text('Update Stock'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- delete
  void _confirmDelete(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text(
            'Are you sure you want to delete "${product['ProductName']}"?'),
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
              try {
                await DatabaseHelper.instance
                    .deleteProduct(product['ProductID'] as int);
                if (mounted) _refresh();
              } catch (e) {
                // SaleItems wala use wela nam (FK RESTRICT)
                _showMessage(
                    'Cannot delete: this product is used in sales records.');
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- categories dialog
  void _showCategoriesDialog() {
    final nameController = TextEditingController();
    String? errorText;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> addCategory() async {
            final name = nameController.text.trim();
            if (name.isEmpty) {
              setDialogState(() => errorText = 'Enter a category name');
              return;
            }
            try {
              await DatabaseHelper.instance.insertCategory(name);
              nameController.clear();
              final cats = await DatabaseHelper.instance.getCategories();
              _categories = cats;
              setDialogState(() => errorText = null);
            } catch (e) {
              setDialogState(() => errorText = 'This category already exists');
            }
          }

          Future<void> removeCategory(int id) async {
            await DatabaseHelper.instance.deleteCategory(id);
            final cats = await DatabaseHelper.instance.getCategories();
            _categories = cats;
            setDialogState(() => errorText = null);
          }

          return AlertDialog(
            title: const Text('Manage Categories'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: nameController,
                          onSubmitted: (_) => addCategory(),
                          decoration: InputDecoration(
                            labelText: 'New category name',
                            prefixIcon: const Icon(Icons.category),
                            errorText: errorText,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: FilledButton(
                          onPressed: addCategory,
                          child: const Text('Add'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: _categories.map((c) {
                        final int id = c['CategoryID'] as int;
                        final bool isDefault = id == _defaultCategoryId;
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.label_outline),
                          title: Text(c['CategoryName'].toString()),
                          trailing: IconButton(
                            icon: Icon(Icons.delete,
                                color: isDefault ? Colors.grey : Colors.red),
                            tooltip: isDefault
                                ? 'Default category cannot be deleted'
                                : 'Delete',
                            onPressed:
                                isDefault ? null : () => removeCategory(id),
                          ),
                        );
                      }).toList(),
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
          );
        },
      ),
    ).then((_) {
      if (mounted) _refresh();
    });
  }

  // ---------------------------------------------------------------- UI
  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => _applyFilters(),
                  decoration: InputDecoration(
                    hintText: 'Search by product, category or supplier...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _applyFilters();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<int?>(
                  key: ValueKey(_categoryFilter),
                  initialValue: _categoryFilter,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                        value: null, child: Text('All Categories')),
                    ..._categories.map((c) => DropdownMenuItem<int?>(
                          value: c['CategoryID'] as int,
                          child: Text(c['CategoryName'].toString()),
                        )),
                  ],
                  onChanged: (val) {
                    _categoryFilter = val;
                    _applyFilters();
                  },
                ),
              ),
              const SizedBox(width: 12),
              IconButton.outlined(
                tooltip: 'Manage Categories',
                icon: const Icon(Icons.category),
                onPressed: _showCategoriesDialog,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              children: [
                _statusChip('all', 'All (${_products.length})'),
                _statusChip('low',
                    'Low Stock (${_products.where((p) => _statusOf(p) == 'low').length})'),
                _statusChip('out',
                    'Out of Stock (${_products.where((p) => _statusOf(p) == 'out').length})'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String value, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _statusFilter == value,
      onSelected: (_) {
        _statusFilter = value;
        _applyFilters();
      },
    );
  }

  Widget _buildList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_products.isEmpty) {
      return const Center(child: Text('No products found.'));
    }
    if (_filteredProducts.isEmpty) {
      return const Center(child: Text('No results found.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      itemCount: _filteredProducts.length,
      itemBuilder: (context, index) {
        final product = _filteredProducts[index];
        final String status = _statusOf(product);
        final Color color = _statusColor(status);

        return Card(
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: color,
              child: const Icon(Icons.inventory_2, color: Colors.white),
            ),
            title: Text(
              product['ProductName'].toString(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'Category: ${product['CategoryName'] ?? 'N/A'} | Supplier: ${product['SupplierName'] ?? 'N/A'}'),
                Text(
                    'Stock: ${_fmtQty(product['StockQuantity'])} (Min: ${_fmtQty(product['MinimumStock'])})'),
                Text(
                    'Cost: Rs. ${_fmtPrice(product['SupplierPrice'])} | Normal: Rs. ${_fmtPrice(product['NormalPrice'])} | Our: Rs. ${_fmtPrice(product['OurPrice'])}'),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.add_box, color: Colors.green),
                  tooltip: 'Adjust Stock',
                  onPressed: () => _showAdjustStockDialog(product),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  tooltip: 'Edit',
                  onPressed: () => _showProductDialog(product: product),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: 'Delete',
                  onPressed: () => _confirmDelete(product),
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
          _buildToolbar(),
          Expanded(child: _buildList()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProductDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
    );
  }
}