import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/app_session.dart';
import '../services/database_helper.dart';
import '../widgets/change_password_dialog.dart';

/// Settings
///  - everyone: change own password
///  - Admin only: business name + telephone (invoice PDF), auto logout,
///    database backup / restore
class SettingsScreen extends StatefulWidget {
  final bool isAdmin;

  const SettingsScreen({super.key, this.isAdmin = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();

  // 0 = off
  static const List<int> _autoLogoutOptions = [0, 5, 10, 15, 30, 60];
  int _autoLogoutMinutes = 10;

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
    super.dispose();
  }

  Future<void> _load() async {
    final store = await DatabaseHelper.instance.getStore();
    if (!mounted) return;

    final minutes = (store['AutoLogoutMinutes'] as num?)?.toInt() ?? 10;
    setState(() {
      _nameController.text = (store['StoreName'] ?? '').toString();
      _contactController.text = (store['StoreContact'] ?? '').toString();
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

  // ---------------- Business details ----------------

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
      _snack('Settings saved.', Colors.green);
    } catch (e) {
      _snack('Save failed: ${e.toString()}', Colors.red);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

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

    // Restored data may have different users -> log in again
    _snack('Backup restored. Please log in again.', Colors.green);
    AppSession.onLogout?.call();
  }

  // ---------------- UI ----------------

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

  Widget _businessSection() {
    return _section(
      title: 'Business Details',
      subtitle: 'These details are printed at the top of every invoice PDF.',
      children: [
        Form(
          key: _formKey,
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
                  final ok =
                      RegExp(r'^[0-9+\-\s/,()]{7,40}$').hasMatch(val.trim());
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
          'expenses, users) to a file. Keep it on a USB drive or cloud '
          'storage so you can recover if this computer fails.',
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
                        _accountSection(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Right column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
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