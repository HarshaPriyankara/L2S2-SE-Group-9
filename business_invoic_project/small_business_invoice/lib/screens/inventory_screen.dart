import 'package:flutter/material.dart';
import '../services/database_helper.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshInventory();
  }

  void _refreshInventory() async {
    setState(() => _isLoading = true);
    final productsData = await DatabaseHelper.instance.getProducts();
    final categoriesData = await DatabaseHelper.instance.getCategories();
    setState(() {
      _products = productsData;
      _categories = categoriesData;
      _isLoading = false;
    });
  }

  void _showProductDialog({Map<String, dynamic>? product}) {
    final messenger = ScaffoldMessenger.of(context);
    final nameController = TextEditingController(text: product?['ProductName']?.toString() ?? '');
    final stockController = TextEditingController(text: product?['StockQuantity']?.toString() ?? '0');
    final minStockController = TextEditingController(text: product?['MinimumStock']?.toString() ?? '5');
    final supplierPriceController = TextEditingController(text: product?['SupplierPrice']?.toString() ?? '0.00');
    final normalPriceController = TextEditingController(text: product?['NormalPrice']?.toString() ?? '0.00');
    final ourPriceController = TextEditingController(text: product?['OurPrice']?.toString() ?? '0.00');

    int? selectedCategoryId = product?['CategoryID'] as int?;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (builderContext, setDialogState) => AlertDialog(
          title: Text(product == null ? 'Add New Product' : 'Edit Product'),
          content: Form(
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
                    validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter product name' : null,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    initialValue: selectedCategoryId,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: _categories.map((cat) {
                      return DropdownMenuItem<int>(
                        value: cat['CategoryID'] as int,
                        child: Text(cat['CategoryName'].toString()),
                      );
                    }).toList(),
                    onChanged: (val) => setDialogState(() => selectedCategoryId = val),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: stockController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Stock Qty *'),
                          validator: (val) => (val == null || val.isEmpty) ? 'Enter qty' : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: minStockController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Min Stock Alert'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: supplierPriceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Supplier Price (Cost) *',
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    validator: (val) => (val == null || val.isEmpty) ? 'Enter cost price' : null,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: normalPriceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Normal Price'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: ourPriceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Our Price (Selling) *'),
                          validator: (val) => (val == null || val.isEmpty) ? 'Enter selling price' : null,
                        ),
                      ),
                    ],
                  ),
                ],
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
                  final productData = {
                    'ProductName': nameController.text.trim(),
                    'CategoryID': selectedCategoryId,
                    'StockQuantity': double.tryParse(stockController.text.trim()) ?? 0.0,
                    'MinimumStock': double.tryParse(minStockController.text.trim()) ?? 0.0,
                    'SupplierPrice': double.tryParse(supplierPriceController.text.trim()) ?? 0.00,
                    'NormalPrice': double.tryParse(normalPriceController.text.trim()) ?? 0.00,
                    'OurPrice': double.tryParse(ourPriceController.text.trim()) ?? 0.00,
                  };

                  try {
                    if (product == null) {
                      await DatabaseHelper.instance.insertProduct(productData);
                    } else {
                      productData['ProductID'] = product['ProductID'];
                      await DatabaseHelper.instance.updateProduct(productData);
                    }

                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }

                    if (mounted) {
                      _refreshInventory();
                    }
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Error: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: Text(product == null ? 'Save' : 'Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteProduct(int id) async {
    await DatabaseHelper.instance.deleteProduct(id);
    _refreshInventory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
              ? const Center(child: Text('No products found in inventory.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final item = _products[index];
                    final double stock = (item['StockQuantity'] as num?)?.toDouble() ?? 0.0;
                    final double minStock = (item['MinimumStock'] as num?)?.toDouble() ?? 0.0;
                    final bool isLowStock = stock <= minStock;

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isLowStock ? Colors.orange.shade100 : Colors.green.shade100,
                          child: Icon(
                            isLowStock ? Icons.warning_amber : Icons.inventory,
                            color: isLowStock ? Colors.orange.shade800 : Colors.green.shade800,
                          ),
                        ),
                        title: Text(
                          item['ProductName'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Category: ${item['CategoryName'] ?? 'Uncategorized'}\n'
                          'Stock: $stock | Selling Price: Rs.${item['OurPrice'] ?? '0.00'}',
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _showProductDialog(product: item),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteProduct(item['ProductID']),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProductDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
    );
  }
}