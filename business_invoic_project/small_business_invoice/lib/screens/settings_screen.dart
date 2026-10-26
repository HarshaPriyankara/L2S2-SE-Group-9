import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/app_session.dart';
import '../services/database_helper.dart';
import '../widgets/change_password_dialog.dart';

/// Settings
///  - everyone: change own password
///  - Admin only: business details + logo, invoice & receipt, POS & stock,
///    auto logout, database backup / restore
class SettingsScreen extends StatefulWidget {
  final bool isAdmin;

  const SettingsScreen({super.key, this.isAdmin = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _businessKey = GlobalKey<FormState>();
  final _invoiceKey = GlobalKey<FormState>();
  final _posKey = GlobalKey<FormState>();

  // Business details
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _addressController = TextEditingController();
  final _emailController = TextEditingController();
  String? _logoBase64; // PNG / JPG as base64 (saved in Store.StoreLogo)

  // Invoice & receipt
  final _prefixController = TextEditingController();
  final _currencyController = TextEditingController();
  final _footerController = TextEditingController();
  String _receiptSize = 'A4'; // 'A4' or '80mm'

  // POS & stock
  final _lowStockController = TextEditingController();
  bool _autoPrint = false;

  // Security
  static const List<int> _autoLogoutOptions = [0, 5, 10, 15, 30, 60];
  int _autoLogoutMinutes = 10; // 0 = off

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isBusy = false; // backup / restore running

  @override
  void initState() {
    super.initState();
    if (widget.isAdmin) {
      _load();
    } else {
      _isLoading = false; // Cashier only sees "My Account"
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _prefixController.dispose();
    _currencyController.dispose();
    _footerController.dispose();
    _lowStockController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final store = await DatabaseHelper.instance.getStore();
    if (!mounted) return;

    String t(String key) => (store[key] ?? '').toString();
    final minutes = (store['AutoLogoutMinutes'] as num?)?.toInt() ?? 10;
    final logo = t('StoreLogo');

    setState(() {
      _nameController.text = t('StoreName');
      _contactController.text = t('StoreContact');
      _addressController.text = t('StoreAddress');
      _emailController.text = t('StoreEmail');
      _logoBase64 = logo.isEmpty ? null : logo;

      _prefixController.text = t('InvoicePrefix');
      _currencyController.text = t('CurrencySymbol');
      _footerController.text = t('FooterMessage');
      _receiptSize = t('ReceiptSize') == '80mm' ? '80mm' : 'A4';

      _lowStockController.text = t('LowStockLimit');
      _autoPrint = ((store['AutoPrint'] as num?)?.toInt() ?? 0) == 1;

      _autoLogoutMinutes =
          _autoLogoutOptions.contains(minutes) ? minutes : 10;
      _isLoading = false;
    });
  }

  void _snack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  /// Validate [formKey], save [fields] to the Store row, refresh AppSession
  Future<void> _saveFields(
      GlobalKey<FormState> formKey, Map<String, Object?> fields) async {
    if (_isSaving) return;
    if (!formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await DatabaseHelper.instance.saveStoreFields(fields);
      AppSession.applyStore(await DatabaseHelper.instance.getStore());
      _snack('Settings saved.', Colors.green);
    } catch (e) {
      _snack('Save failed: ${e.toString()}', Colors.red);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String? _orNull(TextEditingController c) {
    final v = c.text.trim();
    return v.isEmpty ? null : v;
  }

  // ---------------- Business details ----------------

  Future<void> _saveBusiness() => _saveFields(_businessKey, {
        'StoreName': _nameController.text.trim(),
        'StoreContact': _orNull(_contactController),
        'StoreAddress': _orNull(_addressController),
        'StoreEmail': _orNull(_emailController),
        'StoreLogo': _logoBase64,
      });

  Future<void> _pickLogo() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select Logo (PNG or JPG)',
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg'],
      withData: true,
    );
    final Uint8List? bytes = result?.files.single.bytes;
    if (bytes == null) return; // cancelled

    if (bytes.length > 300 * 1024) {
      _snack('Logo is too large. Please use an image under 300 KB.',
          Colors.red);
      return;
    }
    setState(() => _logoBase64 = base64Encode(bytes));
    _snack('Logo selected. Press Save to apply it.', Colors.blue);
  }

  // ---------------- Invoice & receipt ----------------

  Future<void> _saveInvoice() => _saveFields(_invoiceKey, {
        'InvoicePrefix': _prefixController.text.trim(),
        'CurrencySymbol': _currencyController.text.trim(),
        'FooterMessage': _footerController.text.trim(), // empty = no footer
        'ReceiptSize': _receiptSize,
      });

  // ---------------- POS & stock ----------------

  Future<void> _savePos() => _saveFields(_posKey, {
        'LowStockLimit': int.parse(_lowStockController.text.trim()),
        'AutoPrint': _autoPrint ? 1 : 0,
      });

  // ---------------- Auto logout ----------------

  Future<void> _changeAutoLogout(int minutes) async {
    setState(() => _autoLogoutMinutes = minutes);
    try {
      await DatabaseHelper.instance.setAutoLogoutMinutes(minutes);
      AppSession.autoLogoutMinutes.value = minutes; // applies immediately
      _snack(
        minutes == 0
            ? 'Auto logout turned off.'
            : 'Auto logout set to $minutes minutes.',
        Colors.green,
      );
    } catch (e) {
      _snack('Save failed: ${e.toString()}', Colors.red);
    }
  }

  // ---------------- Backup / Restore ----------------

  String _stamp() {
    String two(int v) => v.toString().padLeft(2, '0');
    final n = DateTime.now();
    return '${n.year}-${two(n.month)}-${two(n.day)}_${two(n.hour)}${two(n.minute)}';
  }

  Future<void> _backup() async {
    if (_isBusy) return;

    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Database Backup',
      fileName: 'EasyBill_Backup_${_stamp()}.db',
      type: FileType.custom,
      allowedExtensions: ['db'],
    );
    if (path == null) return; // user cancelled

    final finalPath = path.toLowerCase().endsWith('.db') ? path : '$path.db';

    setState(() => _isBusy = true);
    try {
      await DatabaseHelper.instance.backupTo(finalPath);
      _snack('Backup saved: $finalPath', Colors.green);
    } catch (e) {
      _snack('Backup failed: ${e.toString()}', Colors.red);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _restore() async {
    if (_isBusy) return;

    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select Backup File',
      type: FileType.custom,
      allowedExtensions: ['db'],
    );
    final path = result?.files.single.path;
    if (path == null) return; // user cancelled
    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore Backup'),
        content: const Text(
          'All current data (invoices, products, customers, expenses, users) '
          'will be REPLACED with the data in the selected backup file.\n\n'
          'You will be logged out after the restore.\n\n'
          'Do you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isBusy = true);
    final error = await DatabaseHelper.instance.restoreFrom(path);
    if (!mounted) return;
    setState(() => _isBusy = false);

    if (error != null) {
      _snack(error, Colors.red);
      return;
    }

    // Restored data may have different users / settings -> log in again
    _snack('Backup restored. Please log in again.', Colors.green);
    AppSession.onLogout?.call();
  }

  // ---------------- UI helpers ----------------

  Widget _section({
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _saveButton(VoidCallback onPressed) {
    return FilledButton.icon(
      onPressed: _isSaving ? null : onPressed,
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
    );
  }

  Widget _logoPreview() {
    final data = _logoBase64;
    Widget content;
    if (data == null) {
      content = Icon(Icons.image_outlined, size: 32, color: Colors.grey.shade500);
    } else {
      content = Image.memory(
        base64Decode(data),
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) =>
            const Icon(Icons.broken_image, color: Colors.red),
      );
    }
    return Container(
      width: 72,
      height: 72,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Center(child: content),
    );
  }

  // ---------------- Sections ----------------

  Widget _businessSection() {
    return _section(
      title: 'Business Details',
      subtitle: 'These details are printed at the top of every invoice.',
      children: [
        Form(
          key: _businessKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                controller: _addressController,
                textInputAction: TextInputAction.next,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  prefixIcon: Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contactController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
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
                  final ok =
                      RegExp(r'^[0-9+\-\s/,()]{7,40}$').hasMatch(val.trim());
                  return ok ? null : 'Enter a valid telephone number';
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                  hintText: 'shop@example.com',
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return null;
                  final ok = RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,}$')
                      .hasMatch(val.trim());
                  return ok ? null : 'Enter a valid email address';
                },
              ),
              const SizedBox(height: 20),
              const Text('Logo',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _logoPreview(),
                  const SizedBox(width: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickLogo,
                        icon: const Icon(Icons.upload_file),
                        label: Text(_logoBase64 == null
                            ? 'Choose Logo'
                            : 'Change Logo'),
                      ),
                      if (_logoBase64 != null)
                        TextButton.icon(
                          onPressed: () => setState(() => _logoBase64 = null),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Remove'),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('PNG or JPG, under 300 KB. Press Save to apply.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(height: 24),
              _saveButton(_saveBusiness),
            ],
          ),
        ),
      ],
    );
  }

  Widget _invoiceSection() {
    final prefix = _prefixController.text.trim();
    return _section(
      title: 'Invoice & Receipt',
      subtitle: 'How invoices look when printed or saved as PDF.',
      children: [
        Form(
          key: _invoiceKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _prefixController,
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Invoice Number Prefix',
                  prefixIcon: const Icon(Icons.tag),
                  hintText: 'INV-',
                  helperText:
                      'Example: ${AppSession.formatInvoiceNo(1, prefix)}, ${AppSession.formatInvoiceNo(125, prefix)}',
                  border: const OutlineInputBorder(),
                ),
                validator: (val) {
                  if ((val ?? '').trim().length > 10) {
                    return 'Maximum 10 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _currencyController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Currency Symbol *',
                  prefixIcon: Icon(Icons.payments_outlined),
                  hintText: 'Rs.',
                  helperText: 'Letters / symbols only, e.g. Rs.  LKR  \$',
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  final v = (val ?? '').trim();
                  if (v.isEmpty) return 'Please enter a currency symbol';
                  // The PDF font only supports basic Latin characters
                  if (!RegExp(r'^[\x20-\x7E]{1,6}$').hasMatch(v)) {
                    return 'Use up to 6 English letters or symbols';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _footerController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Footer Message',
                  prefixIcon: Icon(Icons.notes),
                  hintText: 'Thank you for your business!',
                  helperText:
                      'Printed at the bottom, e.g. return policy or warranty note. Leave empty for no footer.',
                  helperMaxLines: 2,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _receiptSize,
                decoration: const InputDecoration(
                  labelText: 'Receipt Size',
                  prefixIcon: Icon(Icons.receipt_long),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'A4', child: Text('A4 paper')),
                  DropdownMenuItem(
                      value: '80mm', child: Text('80mm thermal receipt')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _receiptSize = val);
                },
              ),
              const SizedBox(height: 24),
              _saveButton(_saveInvoice),
            ],
          ),
        ),
      ],
    );
  }

  Widget _posSection() {
    return _section(
      title: 'POS & Stock',
      subtitle: 'Billing and inventory behaviour.',
      children: [
        Form(
          key: _posKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                value: _autoPrint,
                onChanged: (v) => setState(() => _autoPrint = v),
                contentPadding: EdgeInsets.zero,
                title: const Text('Auto print after sale'),
                subtitle: const Text(
                    'Open the print preview automatically when an invoice is saved.'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _lowStockController,
                keyboardType: TextInputType.number,
                onFieldSubmitted: (_) => _savePos(),
                decoration: const InputDecoration(
                  labelText: 'Low Stock Limit',
                  prefixIcon: Icon(Icons.warning_amber_rounded),
                  helperText:
                      'Products with this much stock or less are marked "Low Stock" in Inventory. '
                      'A product that has its own Minimum Stock uses that instead.',
                  helperMaxLines: 3,
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  final n = int.tryParse((val ?? '').trim());
                  if (n == null) return 'Enter a whole number';
                  if (n < 0) return 'Cannot be negative';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              _saveButton(_savePos),
            ],
          ),
        ),
      ],
    );
  }

  Widget _accountSection() {
    return _section(
      title: 'My Account',
      subtitle: 'Change the password you use to log in.',
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => showChangePasswordDialog(context),
            icon: const Icon(Icons.key),
            label: const Text('Change Password'),
          ),
        ),
      ],
    );
  }

  Widget _securitySection() {
    return _section(
      title: 'Security',
      subtitle:
          'Log out automatically when the app is not used for a while. '
          'Applies to every user.',
      children: [
        DropdownButtonFormField<int>(
          initialValue: _autoLogoutMinutes,
          decoration: const InputDecoration(
            labelText: 'Auto logout after',
            prefixIcon: Icon(Icons.timer_outlined),
            border: OutlineInputBorder(),
          ),
          items: [
            for (final m in _autoLogoutOptions)
              DropdownMenuItem(
                value: m,
                child: Text(m == 0 ? 'Never (off)' : '$m minutes'),
              ),
          ],
          onChanged: (val) {
            if (val != null) _changeAutoLogout(val);
          },
        ),
      ],
    );
  }

  Widget _backupSection() {
    return _section(
      title: 'Backup & Restore',
      subtitle:
          'Save a copy of ALL your data (invoices, products, customers, '
          'expenses, users, settings) to a file. Keep it on a USB drive or '
          'cloud storage so you can recover if this computer fails.',
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: _isBusy ? null : _backup,
              icon: const Icon(Icons.backup),
              label: const Text('Backup Now'),
            ),
            OutlinedButton.icon(
              onPressed: _isBusy ? null : _restore,
              icon: const Icon(Icons.restore),
              label: const Text('Restore from Backup'),
            ),
            if (_isBusy)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Cashier: only "My Account"
    if (!widget.isAdmin) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: _accountSection(),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Wide window -> 2 columns, narrow window -> 1 column
              final bool twoColumns = constraints.maxWidth >= 800;

              if (!twoColumns) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _businessSection(),
                    const SizedBox(height: 16),
                    _invoiceSection(),
                    const SizedBox(height: 16),
                    _posSection(),
                    const SizedBox(height: 16),
                    _accountSection(),
                    const SizedBox(height: 16),
                    _securitySection(),
                    const SizedBox(height: 16),
                    _backupSection(),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _businessSection(),
                        const SizedBox(height: 16),
                        _invoiceSection(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Right column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _posSection(),
                        const SizedBox(height: 16),
                        _accountSection(),
                        const SizedBox(height: 16),
                        _securitySection(),
                        const SizedBox(height: 16),
                        _backupSection(),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}