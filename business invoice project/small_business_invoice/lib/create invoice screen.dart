import 'package:flutter/material.dart';

class CreateInvoiceScreen extends StatefulWidget {
  const CreateInvoiceScreen({super.key});

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  final customerNameController = TextEditingController();
  final customerPhoneController = TextEditingController();
  final customerEmailController = TextEditingController();

  final productController = TextEditingController();
  final quantityController = TextEditingController();
  final priceController = TextEditingController();

  final List<Map<String, dynamic>> items = [];

  void addItem() {
    final product = productController.text.trim();
    final quantity = int.tryParse(quantityController.text) ?? 0;
    final price = double.tryParse(priceController.text) ?? 0;

    if (product.isEmpty || quantity <= 0 || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter valid item details'),
        ),
      );
      return;
    }

    setState(() {
      items.add({
        'product': product,
        'quantity': quantity,
        'price': price,
        'total': quantity * price,
      });

      productController.clear();
      quantityController.clear();
      priceController.clear();
    });
  }

  double get subtotal {
    double total = 0;

    for (final item in items) {
      total += item['total'];
    }

    return total;
  }

  @override
  void dispose() {
    customerNameController.dispose();
    customerPhoneController.dispose();
    customerEmailController.dispose();
    productController.dispose();
    quantityController.dispose();
    priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Invoice'),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const Text(
              'Customer Details',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: customerNameController,
              decoration: const InputDecoration(
                labelText: 'Customer Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: customerPhoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: customerEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
            ),

            const SizedBox(height: 30),

            const Text(
              'Invoice Items',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: productController,
              decoration: const InputDecoration(
                labelText: 'Product / Service',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Unit Price',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 15),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: addItem,
                icon: const Icon(Icons.add),
                label: const Text('Add Item'),
              ),
            ),

            const SizedBox(height: 20),

            if (items.isNotEmpty)
              Card(
                child: Column(
                  children: items.map((item) {
                    return ListTile(
                      title: Text(item['product']),
                      subtitle: Text(
                        '${item['quantity']} × Rs. ${item['price'].toStringAsFixed(2)}',
                      ),
                      trailing: Text(
                        'Rs. ${item['total'].toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

            const SizedBox(height: 20),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Subtotal',
                          style: TextStyle(fontSize: 18),
                        ),
                        Text(
                          'Rs. ${subtotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: items.isEmpty
                            ? null
                            : () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Invoice will be saved later with database',
                                    ),
                                  ),
                                );
                              },
                        child: const Text('Save Invoice'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}