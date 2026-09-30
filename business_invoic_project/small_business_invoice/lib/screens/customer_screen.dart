import 'package:flutter/material.dart';
import '../services/database_helper.dart';

class CustomerScreen extends StatefulWidget {
  const CustomerScreen({super.key});

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  List<Map<String, dynamic>> _customers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshCustomers();
  }

  void _refreshCustomers() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper.instance.getCustomers();
    setState(() {
      _customers = data;
      _isLoading = false;
    });
  }
void _showCustomerDialog({Map<String, dynamic>? customer}) {
  final nameController = TextEditingController(text: customer?['CustomerName'] ?? '');
  final emailController = TextEditingController(text: customer?['Email'] ?? '');
  final phoneController = TextEditingController(text: customer?['ContactNumber'] ?? '');
  final formKey = GlobalKey<FormState>();

  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(customer == null ? 'Add New Customer' : 'Edit Customer'),
      content: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Customer Name Input
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Customer Name *',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter customer name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),

              // Email Input with Validation
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                  hintText: 'example@mail.com',
                ),
                validator: (val) {
                  if (val != null && val.trim().isNotEmpty) {
                    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                    if (!emailRegex.hasMatch(val.trim())) {
                      return 'Enter a valid email address';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),

              // Contact Number Input with Validation
              // Contact Number Input with Validation
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
                    // Unused phoneRegex variable kadhun fakt simplePhoneRegex vaparla ahe
                    final simplePhoneRegex = RegExp(r'^\d{10}$');

                    if (!simplePhoneRegex.hasMatch(val.trim())) {
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
              final customerData = {
                'CustomerName': nameController.text.trim(),
                'Email': emailController.text.trim(),
                'ContactNumber': phoneController.text.trim(),
              };

              if (customer == null) {
                await DatabaseHelper.instance.insertCustomer(customerData);
              } else {
                customerData['CustomerID'] = customer['CustomerID'];
                await DatabaseHelper.instance.updateCustomer(customerData);
              }

              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }

              if (mounted) {
                _refreshCustomers();
              }
            }
          },
          child: Text(customer == null ? 'Save' : 'Update'),
        ),
      ],
    ),
  );
}

  // Customer ඉවත් කිරීම
  void _deleteCustomer(int id) async {
    await DatabaseHelper.instance.deleteCustomer(id);
    _refreshCustomers();
  }

 @override
Widget build(BuildContext context) {
  return Scaffold(
    // AppBar එකක් අවශ්‍ය නොවේ, මන්ද Dashboard එකෙහි දැනටමත් AppBar එකක් ඇත
    body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _customers.isEmpty
            ? const Center(child: Text('No customers found.'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _customers.length,
                itemBuilder: (context, index) {
                  final customer = _customers[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(customer['CustomerName'][0].toUpperCase()),
                      ),
                      title: Text(customer['CustomerName'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        'Phone: ${customer['ContactNumber'] ?? 'N/A'} | Email: ${customer['Email'] ?? 'N/A'}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _showCustomerDialog(customer: customer),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteCustomer(customer['CustomerID']),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _showCustomerDialog(),
      icon: const Icon(Icons.add),
      label: const Text('Add Customer'),
    ),
  );
}
}