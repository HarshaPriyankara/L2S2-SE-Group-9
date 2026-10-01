import 'package:flutter/material.dart';
import '../services/database_helper.dart';

class SupplierScreen extends StatefulWidget {
  const SupplierScreen({super.key});

  @override
  State<SupplierScreen> createState() => _SupplierScreenState();
}

class _SupplierScreenState extends State<SupplierScreen> {
  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> _filteredSuppliers = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  // Default supplier (ID 1) delete karanna denne naha
  static const int _defaultSupplierId = 1;

  @override
  void initState() {
    super.initState();
    _refreshSuppliers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refreshSuppliers() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper.instance.getSuppliers();
    if (!mounted) return;
    setState(() {
      _suppliers = data;
      _isLoading = false;
    });
    _applySearch(_searchController.text);
  }

  void _applySearch(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredSuppliers = List.from(_suppliers);
      } else {
        _filteredSuppliers = _suppliers.where((s) {
          final name = (s['SupplierName'] ?? '').toString().toLowerCase();
          final company = (s['SupplierCompany'] ?? '').toString().toLowerCase();
          final phone = (s['ContactNumber'] ?? '').toString().toLowerCase();
          return name.contains(q) || company.contains(q) || phone.contains(q);
        }).toList();
      }
    });
  }

  void _showSupplierDialog({Map<String, dynamic>? supplier}) {
    final nameController =
        TextEditingController(text: supplier?['SupplierName']?.toString() ?? '');
    final companyController = TextEditingController(
        text: supplier?['SupplierCompany']?.toString() ?? '');
    final phoneController = TextEditingController(
        text: supplier?['ContactNumber']?.toString() ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(supplier == null ? 'Add New Supplier' : 'Edit Supplier'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Supplier Name *',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (val) => (val == null || val.trim().isEmpty)
                      ? 'Please enter supplier name'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: companyController,
                  decoration: const InputDecoration(
                    labelText: 'Company',
                    prefixIcon: Icon(Icons.business),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Contact Number',
                    prefixIcon: Icon(Icons.phone),
                    hintText: '0712345678',
                  ),
                  validator: (val) {
                    if (val != null && val.trim().isNotEmpty) {
                      if (!RegExp(r'^\d{10}$').hasMatch(val.trim())) {
                        return 'Enter a valid 10-digit phone number';
                      }
                    }
                    return null;
                  },
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
                final Map<String, dynamic> supplierData = {
                  'SupplierName': nameController.text.trim(),
                  'SupplierCompany': companyController.text.trim(),
                  'ContactNumber': phoneController.text.trim(),
                };

                try {
                  if (supplier == null) {
                    await DatabaseHelper.instance.insertSupplier(supplierData);
                  } else {
                    supplierData['SupplierID'] = supplier['SupplierID'];
                    await DatabaseHelper.instance.updateSupplier(supplierData);
                  }

                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                  if (mounted) {
                    _refreshSuppliers();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            child: Text(supplier == null ? 'Save' : 'Update'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> supplier) {
    final int id = supplier['SupplierID'];

    if (id == _defaultSupplierId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Default supplier cannot be deleted.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Supplier'),
        content: Text(
            'Are you sure you want to delete "${supplier['SupplierName']}"?\n\n'
            'Products linked to this supplier will be left without a supplier.'),
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
              await DatabaseHelper.instance.deleteSupplier(id);
              if (mounted) _refreshSuppliers();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: TextField(
        controller: _searchController,
        onChanged: _applySearch,
        decoration: InputDecoration(
          hintText: 'Search by name, company or phone...',
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
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_suppliers.isEmpty) {
      return const Center(child: Text('No suppliers found.'));
    }
    if (_filteredSuppliers.isEmpty) {
      return const Center(child: Text('No results found.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredSuppliers.length,
      itemBuilder: (context, index) {
        final supplier = _filteredSuppliers[index];
        final String name = supplier['SupplierName'] ?? '';
        final String company = (supplier['SupplierCompany'] ?? '').toString();
        final String phone = (supplier['ContactNumber'] ?? '').toString();
        final bool isDefault = supplier['SupplierID'] == _defaultSupplierId;

        return Card(
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.teal,
              child: Icon(Icons.local_shipping, color: Colors.white),
            ),
            title: Text(name,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              'Company: ${company.isEmpty ? 'N/A' : company} | '
              'Phone: ${phone.isEmpty ? 'N/A' : phone}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _showSupplierDialog(supplier: supplier),
                ),
                IconButton(
                  icon: Icon(Icons.delete,
                      color: isDefault ? Colors.grey : Colors.red),
                  onPressed: () => _confirmDelete(supplier),
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
        onPressed: () => _showSupplierDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Supplier'),
      ),
    );
  }
}