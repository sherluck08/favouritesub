import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:favouritesub/services/session_http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:favouritesub/utils/api.dart';

class WalletSummaryItem {
  final String product;
  final double amount;
  final DateTime createdAt;
  final double previousBalance;
  final double afterBalance;

  WalletSummaryItem({
    required this.product,
    required this.amount,
    required this.createdAt,
    required this.previousBalance,
    required this.afterBalance,
  });

  factory WalletSummaryItem.fromJson(Map<String, dynamic> json) {
    return WalletSummaryItem(
      product: (json['product'] ?? '').toString(),
      amount: _asDouble(json['amount']),
      createdAt: _asDate(json['create_date']),
      previousBalance: _asDouble(json['previous_balance']),
      afterBalance: _asDouble(json['after_balance']),
    );
  }

  static double _asDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    final s = v.toString().trim();
    if (s.isEmpty) return 0;
    return double.tryParse(s.replaceAll(',', '')) ?? 0;
  }

  static DateTime _asDate(dynamic v) {
    if (v == null) return DateTime.now();
    final s = v.toString();
    final d = DateTime.tryParse(s);
    if (d != null) return d;

    try {
      final parts = s.split(RegExp(r'[ T]'));
      return DateTime.parse(parts.first);
    } catch (_) {
      return DateTime.now();
    }
  }
}

class WalletSummaryProvider extends ChangeNotifier {
  final List<WalletSummaryItem> _items = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  bool _hasMore = true;
  int _page = 1;
  String _query = '';

  List<WalletSummaryItem> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;
  String get query => _query;

  void setQuery(String query) {
    if (query == _query) return;
    _query = query;
    refresh();
  }

  Future<void> refresh() async {
    _items.clear();
    _page = 1;
    _hasMore = true;
    notifyListeners();
    await _fetch(page: 1, append: false);
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    await _fetch(page: _page + 1, append: true);
  }

  Future<void> _fetch({required int page, required bool append}) async {
    if ((_isLoading && !append) || (_isLoadingMore && append)) return;
    if (append) {
      _isLoadingMore = true;
    } else {
      _isLoading = true;
    }
    _error = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token == null || token.isEmpty) {
        _error = 'No access token';
        return;
      }
      final search = _query.isNotEmpty
          ? '&search=${Uri.encodeQueryComponent(_query)}'
          : '';
      final resp = await http.get(
        Uri.parse('${Api.base}/api/v1/wallet-summary/?page=$page$search'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final decoded = jsonDecode(resp.body);
        final list =
            (decoded is List ? decoded : (decoded['results'] as List? ?? []))
                .whereType<Map<String, dynamic>>()
                .map(WalletSummaryItem.fromJson)
                .toList();
        if (append) {
          _items.addAll(list);
        } else {
          _items
            ..clear()
            ..addAll(list);
        }
        _hasMore =
            decoded is Map &&
            decoded['next'] != null &&
            decoded['next'].toString().isNotEmpty;
        _page = page;
      } else {
        _error = 'Failed: ${resp.statusCode}';
      }
    } catch (e) {
      _error = 'Error: $e';
      if (kDebugMode) debugPrint('Wallet summary fetch error: $e');
    } finally {
      _isLoading = false;
      _isLoadingMore = false;
      notifyListeners();
    }
  }
}
