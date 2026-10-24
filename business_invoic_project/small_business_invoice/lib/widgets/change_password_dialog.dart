import 'package:flutter/material.dart';
import '../services/app_session.dart';
import '../services/database_helper.dart';

/// Lets the logged-in user (Admin or Cashier) change their OWN password.
Future<void> showChangePasswordDialog(BuildContext context) async {
  final int? userId = AppSession.userId;
  if (userId == null) return;

  final messenger = ScaffoldMessenger.of(context);
  final currentController = TextEditingController();
  final newController = TextEditingController();
  final confirmController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  bool showPasswords = false;
  bool saving = false;
  String? currentError; // "Current password is incorrect"

  final bool? changed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        Future<void> submit() async {
          if (saving) return;
          setDialogState(() => currentError = null);
          if (!formKey.currentState!.validate()) return;

          setDialogState(() => saving = true);
          final ok = await DatabaseHelper.instance.changePassword(
            userId,
            currentController.text.trim(),
            newController.text.trim(),
          );

          if (ok) {
            if (dialogContext.mounted) Navigator.of(dialogContext).pop(true);
          } else {
            setDialogState(() {
              saving = false;
              currentError = 'Current password is incorrect';
            });
            formKey.currentState!.validate();
          }
        }

        return AlertDialog(
          title: const Text('Change Password'),
          content: SizedBox(
            width: 380,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: currentController,
                      obscureText: !showPasswords,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Current Password *',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter your current password';
                        }
                        return currentError;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: newController,
                      obscureText: !showPasswords,
                      decoration: const InputDecoration(
                        labelText: 'New Password *',
                        prefixIcon: Icon(Icons.lock),
                      ),
                      validator: (val) {
                        final v = (val ?? '').trim();
                        if (v.isEmpty) return 'Please enter a new password';
                        if (v.length < 4) {
                          return 'Password must be at least 4 characters';
                        }
                        if (v == currentController.text.trim()) {
                          return 'New password must be different';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: confirmController,
                      obscureText: !showPasswords,
                      onFieldSubmitted: (_) => submit(),
                      decoration: const InputDecoration(
                        labelText: 'Confirm New Password *',
                        prefixIcon: Icon(Icons.lock),
                      ),
                      validator: (val) {
                        if ((val ?? '').trim() != newController.text.trim()) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 4),
                    CheckboxListTile(
                      value: showPasswords,
                      onChanged: (v) =>
                          setDialogState(() => showPasswords = v ?? false),
                      title: const Text('Show passwords'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: saving ? null : submit,
              child: const Text('Change'),
            ),
          ],
        );
      },
    ),
  );

  currentController.dispose();
  newController.dispose();
  confirmController.dispose();

  if (changed == true) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Password changed successfully.'),
        backgroundColor: Colors.green,
      ),
    );
  }
}