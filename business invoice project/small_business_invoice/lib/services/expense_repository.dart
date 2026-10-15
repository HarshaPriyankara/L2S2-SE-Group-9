import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/expense.dart';

/// Error shown to the user when the server/database call fails.
class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => message;
}

/// Talks to the backend API (Node.js + MySQL) and keeps a local copy of the
/// data so the screens can rebuild instantly.
class ExpenseRepository extends ChangeNotifier {
  ExpenseRepository._();

  static final ExpenseRepository instance = ExpenseRepository._();

  /// Backend address.
  /// - Chrome / Windows / macOS : localhost
  /// - Android emulator         : 10.0.2.2 (the emulator's name for your PC)
  /// - Real phone               : use your PC's WiFi IP, e.g. http://192.168.1.10:3000/api
  static String get baseUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000/api';
    }
    return 'http://localhost:3000/api';
  }

  final List<ExpenseCategory> _categories = [];
  final List<Expense> _expenses = [];

  bool _isLoading = false;
  String? _loadError;

  bool get isLoading => _isLoading;
  String? get loadError => _loadError;

  List<ExpenseCategory> get categories => List.unmodifiable(_categories);
  List<Expense> get expenses => List.unmodifiable(_expenses);

  double get totalExpenses => _expenses.fold(0.0, (sum, e) => sum + e.amount);

  // ---------------------------------------------------------------- loading

  /// Loads everything from the database. Call at app start and on "Retry".
  Future<void> load() async {
    _isLoading = true;
    _loadError = null;
    notifyListeners();

    try {
      final cats = await _request('GET', '/categories') as List<dynamic>;
      final exps = await _request('GET', '/expenses') as List<dynamic>;

      _categories
        ..clear()
        ..addAll(cats.map((j) => _categoryFromJson(j as Map<String, dynamic>)));
      _expenses
        ..clear()
        ..addAll(exps.map((j) => _expenseFromJson(j as Map<String, dynamic>)));
    } on ApiException catch (e) {
      _loadError = e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------- lookups

  ExpenseCategory categoryById(int id) {
    for (final c in _categories) {
      if (c.id == id) return c;
    }
    return ExpenseCategory.uncategorized;
  }

  int expenseCountFor(int categoryId) =>
      _expenses.where((e) => e.categoryId == categoryId).length;

  double totalFor(int categoryId) => _expenses
      .where((e) => e.categoryId == categoryId)
      .fold(0.0, (sum, e) => sum + e.amount);

  bool categoryNameExists(String name, {int? exceptId}) {
    final lower = name.trim().toLowerCase();
    return _categories.any(
      (c) => c.id != exceptId && c.name.toLowerCase() == lower,
    );
  }

  // --------------------------------------------------------------- expenses

  Future<void> addExpense({
    required String title,
    required int categoryId,
    required double amount,
    required DateTime date,
    required String paymentMethod,
    required String note,
  }) async {
    final json = await _request('POST', '/expenses', body: {
      'title': title,
      'categoryId': categoryId,
      'amount': amount,
      'date': _dateToJson(date),
      'paymentMethod': paymentMethod,
      'note': note,
    });
    _expenses.add(_expenseFromJson(json as Map<String, dynamic>));
    notifyListeners();
  }

  Future<void> updateExpense(Expense updated) async {
    final json = await _request('PUT', '/expenses/${updated.id}', body: {
      'title': updated.title,
      'categoryId': updated.categoryId,
      'amount': updated.amount,
      'date': _dateToJson(updated.date),
      'paymentMethod': updated.paymentMethod,
      'note': updated.note,
    });
    final index = _expenses.indexWhere((e) => e.id == updated.id);
    final saved = _expenseFromJson(json as Map<String, dynamic>);
    if (index == -1) {
      _expenses.add(saved);
    } else {
      _expenses[index] = saved;
    }
    notifyListeners();
  }

  Future<void> deleteExpense(int id) async {
    await _request('DELETE', '/expenses/$id');
    _expenses.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  // ------------------------------------------------------------- categories

  Future<void> addCategory({
    required String name,
    required int iconIndex,
    required int colorIndex,
  }) async {
    final json = await _request('POST', '/categories', body: {
      'name': name.trim(),
      'iconIndex': iconIndex,
      'colorIndex': colorIndex,
    });
    _categories.add(_categoryFromJson(json as Map<String, dynamic>));
    notifyListeners();
  }

  Future<void> updateCategory(ExpenseCategory updated) async {
    final json = await _request('PUT', '/categories/${updated.id}', body: {
      'name': updated.name,
      'iconIndex': updated.iconIndex,
      'colorIndex': updated.colorIndex,
    });
    final index = _categories.indexWhere((c) => c.id == updated.id);
    final saved = _categoryFromJson(json as Map<String, dynamic>);
    if (index == -1) {
      _categories.add(saved);
    } else {
      _categories[index] = saved;
    }
    notifyListeners();
  }

  Future<void> deleteCategory(int id) async {
    if (expenseCountFor(id) > 0) {
      throw const ApiException(
        'This category is used by expenses and cannot be deleted',
      );
    }
    await _request('DELETE', '/categories/$id');
    _categories.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  // ------------------------------------------------------------- JSON <-> model

  ExpenseCategory _categoryFromJson(Map<String, dynamic> j) {
    return ExpenseCategory(
      id: j['id'] as int,
      name: j['name'] as String,
      iconIndex: j['iconIndex'] as int,
      colorIndex: j['colorIndex'] as int,
    );
  }

  Expense _expenseFromJson(Map<String, dynamic> j) {
    return Expense(
      id: j['id'] as int,
      title: j['title'] as String,
      categoryId: j['categoryId'] as int,
      amount: (j['amount'] as num).toDouble(),
      date: DateTime.parse(j['date'] as String),
      paymentMethod: j['paymentMethod'] as String,
      note: (j['note'] as String?) ?? '',
    );
  }

  /// DateTime -> "2026-10-14"
  String _dateToJson(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  // ------------------------------------------------------------ HTTP helper

  Future<http.Response> _dispatch(
    String method,
    Uri uri,
    Map<String, dynamic>? body,
  ) {
    const headers = {'Content-Type': 'application/json'};
    final encoded = body == null ? null : jsonEncode(body);

    return switch (method) {
      'GET' => http.get(uri),
      'POST' => http.post(uri, headers: headers, body: encoded),
      'PUT' => http.put(uri, headers: headers, body: encoded),
      'DELETE' => http.delete(uri),
      _ => throw ArgumentError('Unsupported method: $method'),
    };
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$baseUrl$path');

    http.Response response;
    try {
      response = await _dispatch(method, uri, body)
          .timeout(const Duration(seconds: 10));
    } on Exception {
      throw const ApiException(
        'Cannot reach the server. Make sure the backend is running.',
      );
    }

    final text = utf8.decode(response.bodyBytes);

    if (response.statusCode >= 400) {
      var message = 'Request failed (${response.statusCode})';
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map<String, dynamic> && decoded['error'] is String) {
          message = decoded['error'] as String;
        }
      } on FormatException {
        // keep the generic message
      }
      throw ApiException(message);
    }

    if (text.isEmpty) return null;
    try {
      return jsonDecode(text);
    } on FormatException {
      throw const ApiException('The server sent an unexpected response.');
    }
  }
}
