import 'package:flutter/material.dart';
import '../services/database_helper.dart';

/// Business settings (Admin only): name + telephone shown on the invoice PDF
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final store = await DatabaseHelper.instance.getStore();
    if (!mounted) return;
    setState(() {
      _nameController.text = (store['StoreName'] ?? '').toString();
      _contactController.text = (store['StoreContact'] ?? '').toString();
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final contact = _contactController.text.trim();

    try {
      await DatabaseHelper.instance.saveStore(
        name: _nameController.text.trim(),
        contact: contact.isEmpty ? null : contact,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Save failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Business Details',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'These details are printed at the top of every invoice PDF.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Business Name *',
                        prefixIcon: Icon(Icons.storefront),
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) => (val == null || val.trim().isEmpty)
                          ? 'Please enter the business name'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _contactController,
                      keyboardType: TextInputType.phone,
                      onFieldSubmitted: (_) => _save(),
                      decoration: const InputDecoration(
                        labelText: 'Telephone Number',
                        prefixIcon: Icon(Icons.phone),
                        hintText: '0112345678',
                        helperText:
                            'You can enter more than one number, e.g. 0112345678 / 0771234567',
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return null;
                        final ok = RegExp(r'^[0-9+\-\s/,()]{7,40}$')
                            .hasMatch(val.trim());
                        return ok ? null : 'Enter a valid telephone number';
                      },
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save),
                      label: const Text('Save'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}