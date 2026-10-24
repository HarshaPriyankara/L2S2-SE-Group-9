import 'package:flutter/foundation.dart';

/// Title bar ekata pennanna ona data (page name, logged-in user)
class AppSession {
  static final ValueNotifier<String> pageTitle = ValueNotifier('');
  static final ValueNotifier<String> userName = ValueNotifier('');
  static final ValueNotifier<String> userRole = ValueNotifier('');

  /// Logged-in user's UserID (used for "Change Password")
  static int? userId;

  /// Auto logout after this many idle minutes (0 = off)
  static final ValueNotifier<int> autoLogoutMinutes = ValueNotifier(10);

  /// Dashboard set karanawa; title bar / idle watcher call karanawa
  static VoidCallback? onLogout;

  static void clear() {
    pageTitle.value = '';
    userName.value = '';
    userRole.value = '';
    userId = null;
  }
}