import 'package:flutter/foundation.dart';

/// Title bar ekata pennanna ona data (page name, logged-in user)
/// + settings that every screen needs (currency, invoice prefix, ...)
class AppSession {
  static final ValueNotifier<String> pageTitle = ValueNotifier('');
  static final ValueNotifier<String> userName = ValueNotifier('');
  static final ValueNotifier<String> userRole = ValueNotifier('');

  /// Logged-in user's UserID (used for "Change Password")
  static int? userId;

  /// Auto logout after this many idle minutes (0 = off)
  static final ValueNotifier<int> autoLogoutMinutes = ValueNotifier(10);

  // ---- Settings page values (loaded at login, updated when settings are saved)
  static String currency = 'Rs.';
  static String invoicePrefix = 'INV-';
  static int lowStockLimit = 5;
  static bool autoPrint = false;

  /// Dashboard set karanawa; title bar / idle watcher call karanawa
  static VoidCallback? onLogout;

  /// Load the values from the Store row (DatabaseHelper.getStore())
  static void applyStore(Map<String, dynamic> store) {
    currency = (store['CurrencySymbol'] ?? 'Rs.').toString();
    invoicePrefix = (store['InvoicePrefix'] ?? 'INV-').toString();
    lowStockLimit = (store['LowStockLimit'] as num?)?.toInt() ?? 5;
    autoPrint = ((store['AutoPrint'] as num?)?.toInt() ?? 0) == 1;
    autoLogoutMinutes.value = (store['AutoLogoutMinutes'] as num?)?.toInt() ?? 10;
  }

  /// 1 -> INV-0001
  static String formatInvoiceNo(int id, [String? prefix]) =>
      '${prefix ?? invoicePrefix}${id.toString().padLeft(4, '0')}';

  static void clear() {
    pageTitle.value = '';
    userName.value = '';
    userRole.value = '';
    userId = null;
  }
}