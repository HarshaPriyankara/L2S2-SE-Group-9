import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/app_session.dart';

/// Logs the user out when the app has been idle (no mouse / keyboard use)
/// for the number of minutes set in Settings (0 = off).
/// Sits above the Navigator, so dialogs count as activity too.
class IdleWatcher extends StatefulWidget {
  final Widget child;

  const IdleWatcher({super.key, required this.child});

  @override
  State<IdleWatcher> createState() => _IdleWatcherState();
}

class _IdleWatcherState extends State<IdleWatcher> {
  DateTime _lastActivity = DateTime.now();
  Timer? _timer;

  void _touch() => _lastActivity = DateTime.now();

  bool _onKey(KeyEvent event) {
    _touch();
    return false; // never swallow the key
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _check());
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _timer?.cancel();
    super.dispose();
  }

  void _check() {
    final minutes = AppSession.autoLogoutMinutes.value;
    final logout = AppSession.onLogout; // only set while someone is logged in
    if (minutes <= 0 || logout == null) return;

    if (DateTime.now().difference(_lastActivity) >= Duration(minutes: minutes)) {
      _touch();
      logout();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Logged out after $minutes minutes of inactivity.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _touch(),
      onPointerMove: (_) => _touch(),
      onPointerHover: (_) => _touch(),
      onPointerSignal: (_) => _touch(),
      child: widget.child,
    );
  }
}