import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';
import 'screens/login_screen.dart';
import 'services/database_helper.dart';
import 'widgets/custom_title_bar.dart';
import 'widgets/idle_watcher.dart';

bool get _isDesktop =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (_isDesktop) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      size: Size(1000, 640), // login window size (centered)
      minimumSize: Size(800, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden, // hide the default title bar
      title: 'EasyBill POS',
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  await DatabaseHelper.instance.database;

  runApp(const InvoiceExpenseApp());
}

class InvoiceExpenseApp extends StatelessWidget {
  const InvoiceExpenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Small Business Invoice & Expense Management System',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      // Custom title bar on top of every screen (desktop only)
      // IdleWatcher: auto logout when nobody touches the app for a while
      builder: (context, child) {
        final Widget page = child ?? const SizedBox.shrink();
        if (!_isDesktop) return IdleWatcher(child: page);
        return IdleWatcher(
          child: Column(
            children: [
              const CustomTitleBar(),
              Expanded(child: page),
            ],
          ),
        );
      },
      home: const LoginScreen(),
    );
  }
}