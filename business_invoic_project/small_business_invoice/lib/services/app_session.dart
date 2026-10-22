import 'package:flutter/foundation.dart';

/// Title bar ekata pennanna ona data (page name, logged-in user)
class AppSession {
  static final ValueNotifier<String> pageTitle = ValueNotifier('');
  static final ValueNotifier<String> userName = ValueNotifier('');
  static final ValueNotifier<String> userRole = ValueNotifier('');

  /// Dashboard set karanawa; title bar eke Logout button eka call karanawa
  static VoidCallback? onLogout;

  static void clear() {
    pageTitle.value = '';
    userName.value = '';
    userRole.value = '';
  }
}