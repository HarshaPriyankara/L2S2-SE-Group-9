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
  final nameController = TextEditingController(text: customer?['CustomerName']?.toString() ?? '');
  final emailController = TextEditingController(text: customer?['Email']?.toString() ?? '');
  final phoneController = TextEditingController(text: customer?['ContactNumber']?.toString() ?? '');
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
              final String name = nameController.text.trim();
              final String? email = emailController.text.trim().isEmpty ? null : emailController.text.trim();
              final String? phone = phoneController.text.trim().isEmpty ? null : phoneController.text.trim();

             final Map<String, dynamic> customerData = {
              'CustomerName': name,
              'Email': email,
              'ContactNumber': phone,
            };

              try {
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
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Update failed: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            }
          },
          child: Text(customer == null ? 'Save' : 'Update'),
        ),
      ],
    ),
  );
}
  void _deleteCustomer(int id) async {
    await DatabaseHelper.instance.deleteCustomer(id);
    _refreshCustomers();
  }

 @override
Widget build(BuildContext context) {
  return Scaffold(
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