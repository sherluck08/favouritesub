import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:favouritesub/services/session_http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:favouritesub/utils/api.dart';

import '../models/transaction_item.dart';

class TransactionProvider extends ChangeNotifier {
  static const String _cacheKey = 'tx_cache_v1';
  static const String _cacheTsKey = 'tx_cache_ts_v1';

  List<TransactionItem> _items = [];
  bool _isLoading = false;
  String? _error;
  DateTime? _lastUpdated;
  int _page = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  TransactionType? _selectedFilter;

  bool _isValid(TransactionItem t) {
    final hasId = t.id.trim().isNotEmpty;
    final hasStatus = t.status.toString().trim().isNotEmpty;
    final hasAmountStr = t.amount.toString().trim().isNotEmpty;

    final amountSanitized = t.amount.toString().replaceAll(
      RegExp(r'[^0-9.\-]'),
      '',
    );
    final amountNum = double.tryParse(amountSanitized) ?? -1;
    final hasAnyLabel =
        (t.networkName +
                t.product.toString() +
                t.service.toString() +
                (t.packageName ?? '') +
                (t.nameOnCard ?? ''))
            .trim()
            .isNotEmpty;

    final type = _deriveType(t);
    final dataHasPlan =
        t.planSize.trim().isNotEmpty ||
        t.plan.trim().isNotEmpty ||
        t.planType.trim().isNotEmpty;
    final cableHasKey =
        (t.smartCardNumber?.trim().isNotEmpty ?? false) ||
        (t.packageName?.trim().isNotEmpty ?? false);
    final electricityHasKey =
        (t.meterNumber?.trim().isNotEmpty ?? false) ||
        (t.meterType?.trim().isNotEmpty ?? false);
    final rechargeHasKey =
        (t.pins?.trim().isNotEmpty ?? false) ||
        (t.nameOnCard?.trim().isNotEmpty ?? false) ||
        (t.quantity?.trim().isNotEmpty ?? false);
    final examHasKey =
        (t.pinEntries?.isNotEmpty ?? false) ||
        (t.pins?.trim().isNotEmpty ?? false) ||
        (t.quantity?.trim().isNotEmpty ?? false);
    final baseValid =
        hasId && hasStatus && hasAnyLabel && (amountNum > 0 || hasAmountStr);

    final looksLikeAirtime =
        t.mobileNumber.trim().isNotEmpty &&
        t.networkName.trim().isNotEmpty &&
        !dataHasPlan;

    if (type == TransactionType.data) {
      if (!dataHasPlan && looksLikeAirtime) return baseValid;
      return baseValid && dataHasPlan;
    }
    if (type == TransactionType.cable) {
      return baseValid && cableHasKey;
    }
    if (type == TransactionType.electricity) {
      final electricValid =
          hasId &&
          hasStatus &&
          (amountNum > 0 || hasAmountStr) &&
          electricityHasKey;
      return electricValid;
    }
    if (type == TransactionType.rechargeCard) {
      final rechargeValid =
          hasId &&
          hasStatus &&
          (amountNum > 0 || hasAmountStr) &&
          rechargeHasKey;
      return rechargeValid;
    }
    if (type == TransactionType.exam) {
      final examValid =
          hasId && hasStatus && (amountNum > 0 || hasAmountStr) && examHasKey;
      return examValid;
    }
    return baseValid;
  }

  TransactionType _deriveType(TransactionItem t) {
    final s = (t.service ?? '').toLowerCase();
    final p = (t.product ?? '').toLowerCase();
    final planType = t.planType.toLowerCase();
    final planName = t.planSize.toLowerCase();
    final pkg = (t.packageName ?? '').toLowerCase();
    final card = (t.smartCardNumber ?? '').toLowerCase();
    final meter = (t.meterNumber ?? '').toLowerCase();
    final meterType = (t.meterType ?? '').toLowerCase();

    final hasExamText =
        s.contains('exam') ||
        p.contains('exam') ||
        p.contains('waec') ||
        p.contains('neco') ||
        p.contains('jamb') ||
        s.contains('waec') ||
        s.contains('neco') ||
        s.contains('jamb') ||
        (t.examName != null && t.examName!.trim().isNotEmpty);
    if (hasExamText) return TransactionType.exam;
    if (s.contains('data') ||
        p.contains('data') ||
        planType.contains('sme') ||
        planType.contains('gift') ||
        planType.contains('gifting') ||
        planType.contains('corporate') ||
        planName.contains('gb') ||
        planName.contains('mb')) {
      return TransactionType.data;
    }
    if (s.contains('airtime') ||
        p.contains('airtime') ||
        s.contains('vtu') ||
        p.contains('vtu') ||
        s.contains('topup') ||
        p.contains('topup')) {
      return TransactionType.airtime;
    }
    if (meter.isNotEmpty ||
        meterType.isNotEmpty ||
        s.contains('electric') ||
        p.contains('electric') ||
        s.contains('electricity') ||
        p.contains('electricity')) {
      return TransactionType.electricity;
    }
    if (pkg.isNotEmpty ||
        card.isNotEmpty ||
        s.contains('cable') ||
        p.contains('cable') ||
        s.contains('tv') ||
        p.contains('tv') ||
        s.contains('dstv') ||
        p.contains('dstv') ||
        s.contains('gotv') ||
        p.contains('gotv') ||
        s.contains('startimes') ||
        p.contains('startimes')) {
      return TransactionType.cable;
    }

    final hasRechargeText =
        s.contains('recharge') ||
        s.contains('epin') ||
        p.contains('pin') ||
        (t.nameOnCard != null && t.nameOnCard!.trim().isNotEmpty);
    if ((t.pins != null && t.pins!.trim().isNotEmpty) ||
        hasRechargeText ||
        ((t.pinEntries?.isNotEmpty ?? false) && !hasExamText)) {
      return TransactionType.rechargeCard;
    }
    if (s.contains('cable') || s.contains('tv') || p.contains('cable')) {
      return TransactionType.cable;
    }
    if (s.contains('recharge') ||
        p.contains('recharge') ||
        s.contains('epin') ||
        p.contains('epin')) {
      return TransactionType.rechargeCard;
    }
    if (s.contains('exam') ||
        p.contains('exam') ||
        s.contains('waec') ||
        p.contains('waec') ||
        s.contains('jamb') ||
        p.contains('jamb')) {
      return TransactionType.exam;
    }
    if (s.contains('sms')) return TransactionType.sms;

    return t.transactionType;
  }

  List<TransactionItem> get items => _selectedFilter != null
      ? _items.where((item) => _deriveType(item) == _selectedFilter).toList()
      : _items;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  TransactionType? get selectedFilter => _selectedFilter;

  bool get isStale {
    if (_lastUpdated == null) return true;
    return DateTime.now().difference(_lastUpdated!).inMinutes > 10;
  }

  Future<void> load() async {
    await _loadFromCache();
    if (_items.isEmpty || isStale || _cacheMissingReceiptFields()) {
      await fetch();
    }
  }

  Future<void> refresh() async => fetch(force: true);

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      final ts = prefs.getInt(_cacheTsKey);
      if (raw != null) {
        final list = (jsonDecode(raw) as List)
            .whereType<Map<String, dynamic>>()
            .map(TransactionItem.fromJson)
            .toList();
        _items = list;
      }
      if (ts != null) _lastUpdated = DateTime.fromMillisecondsSinceEpoch(ts);
      if (raw != null) notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('Tx cache load error: $e');
    }
  }

  Future<void> fetch({
    bool force = false,
    int page = 1,
    bool append = false,
  }) async {
    if ((_isLoading && !append) || (_isLoadingMore && append)) return;
    if (!force && !append && !isStale && _items.isNotEmpty) return;

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
      if (token == null) {
        _error = 'No access token';
        _isLoading = false;
        _isLoadingMore = false;
        notifyListeners();
        return;
      }

      final endpoint = _endpointForFilter(_selectedFilter);
      debugPrint('tx.fetch endpoint: $endpoint');
      final response = await http
          .get(
            Uri.parse('${Api.base}$endpoint?page=$page'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        debugPrint('tx.fetch decoded: $decoded');

        List rawList = const [];
        if (decoded is List<dynamic>) {
          rawList = decoded;
        } else if (decoded is Map<String, dynamic>) {
          rawList =
              (decoded['results'] ??
              decoded['result'] ??
              decoded['data'] ??
              decoded['items'] ??
              decoded['history'] ??
              decoded['transactions']);
        }

        final list = (rawList)
            .whereType<Map<String, dynamic>>()
            .map(TransactionItem.fromJson)
            .where(_isValid)
            .toList();
        if (append) {
          final all = [..._items, ...list];
          final seen = <String>{};
          _items = all.where((t) => seen.add(t.id)).toList();
        } else {
          _items = list;
        }

        if (kDebugMode) {
          debugPrint('tx.fetch page=$page -> ${list.length} items');
        }

        if (decoded is Map && decoded.containsKey('next')) {
          final next = decoded['next'];
          _hasMore = next != null && next.toString().isNotEmpty;
        } else {
          _hasMore = rawList.isNotEmpty;
        }

        _page = page;
        _lastUpdated = DateTime.now();

        if (!append || page == 1) {
          await prefs.setString(
            _cacheKey,
            jsonEncode(
              _items
                  .map(
                    (e) => {
                      'id': e.id,
                      'network': e.networkId,
                      'plan_network': e.networkName,
                      'plan_name': e.planSize,
                      'plan_type': e.planType,
                      'create_date': e.timestamp.toIso8601String(),
                      'plan_amount': e.amount,
                      'Status': e.status,

                      'payment_medium': e.paymentMedium,
                      'balance_before': e.balanceBefore,
                      'balance_after': e.balanceAfter,
                      'mobile_number': e.mobileNumber,
                      'plan': e.plan,
                      'Ported_number': e.portedNumber,
                      'duration': e.duration,
                      'api_response': e.apiResponse,

                      'service': e.service,
                      'product': e.product,
                      'meter': e.meterNumber,
                      'meter_type': e.meterType,
                      'customer_name': e.customerName,
                      'customer_address': e.customerAddress,
                      'token': e.token,
                      'quantity': e.quantity,
                      'pins': e.pins,
                      'data_pin': e.pinEntries,
                      'name_on_card': e.nameOnCard,
                    },
                  )
                  .toList(),
            ),
          );
          await prefs.setInt(_cacheTsKey, _lastUpdated!.millisecondsSinceEpoch);
        }
      } else {
        _error = 'Failed: ${response.statusCode}';
      }
    } catch (e) {
      _error = 'Error: $e';
      if (kDebugMode) debugPrint('Tx fetch error: $e');
    } finally {
      _isLoading = false;
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (!_hasMore || _isLoading || _isLoadingMore) return;
    await fetch(page: _page + 1, append: true);
  }

  bool _cacheMissingReceiptFields() {
    if (_items.isEmpty) return true;
    int misses = 0;
    for (final t in _items.take(10)) {
      if (t.mobileNumber.isEmpty ||
          t.duration.isEmpty ||
          t.balanceBefore.isEmpty ||
          t.balanceAfter.isEmpty) {
        misses++;
      }
    }
    return misses >= 3;
  }

  void setFilter(TransactionType? filter) {
    _selectedFilter = filter;

    _page = 1;
    _hasMore = true;
    fetch(force: true, page: 1, append: false);
  }

  void clearFilter() {
    _selectedFilter = null;
    notifyListeners();
  }

  List<TransactionType> get availableTransactionTypes {
    return const [
      TransactionType.data,
      TransactionType.airtime,
      TransactionType.cable,
      TransactionType.electricity,
      TransactionType.rechargeCard,
      TransactionType.exam,
    ];
  }

  String _endpointForFilter(TransactionType? type) {
    switch (type) {
      case TransactionType.airtime:
        return '/api/topup/';
      case TransactionType.data:
        return '/api/data/';
      case TransactionType.cable:
        return '/api/v1/cable/';
      case TransactionType.electricity:
        return '/api/v1/electricity/';
      case TransactionType.rechargeCard:
        return '/api/v1/recharge-pin/';
      case TransactionType.exam:
        return '/api/epin/';
      case TransactionType.sms:
        return '/api/bulk-sms/';
      default:
        return '/api/history2/';
    }
  }
}
