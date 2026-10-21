import 'dart:convert';

enum TransactionType {
  data,
  airtime,
  cable,
  electricity,
  rechargeCard,
  exam,
  sms,
}

class TransactionItem {
  final String id;
  final String networkName;
  final String planSize;
  final String planType;
  final DateTime timestamp;
  final String networkId;
  final String amount;
  final String status;
  final String paymentMedium;
  final String balanceBefore;
  final String balanceAfter;
  final String mobileNumber;
  final String plan;
  final String portedNumber;
  final String duration;
  final String apiResponse;
  final TransactionType transactionType;

  final String? meterNumber;
  final String? meterType;
  final String? customerName;
  final String? customerAddress;
  final String? product;
  final String? token;
  final String? quantity;
  final String? pins;
  final String? nameOnCard;
  final String? service;
  final String? packageName;
  final String? smartCardNumber;
  final List<dynamic>? pinEntries;
  final String? examName;

  TransactionItem({
    required this.id,
    required this.networkName,
    required this.planSize,
    required this.planType,
    required this.timestamp,
    required this.networkId,
    required this.amount,
    required this.status,
    required this.paymentMedium,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.mobileNumber,
    required this.plan,
    required this.portedNumber,
    required this.duration,
    required this.apiResponse,
    required this.transactionType,
    this.meterNumber,
    this.meterType,
    this.customerName,
    this.customerAddress,
    this.product,
    this.token,
    this.quantity,
    this.pins,
    this.nameOnCard,
    this.service,
    this.packageName,
    this.smartCardNumber,
    this.pinEntries,
    this.examName,
  });

  factory TransactionItem.fromJson(Map<String, dynamic> json) {
    String pickStr(List keys) {
      for (final k in keys) {
        final v = json[k];
        if (v != null && v.toString().isNotEmpty) return v.toString();
      }
      return '';
    }

    DateTime pickDate(List keys) {
      for (final k in keys) {
        final v = json[k];
        if (v != null && v.toString().isNotEmpty) {
          final d = DateTime.tryParse(v.toString());
          if (d != null) return d;
        }
      }

      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    TransactionType determineTransactionType(Map<String, dynamic> json) {
      final service = pickStr(['service', 'product', 'type']).toLowerCase();
      final product = pickStr(['product']).toLowerCase();
      final hasAirtimeType = pickStr(['airtime_type']).isNotEmpty;
      final planTypeLower = pickStr(['plan_type']).toLowerCase();
      final planNameLower = pickStr(['plan_name', 'bundle']).toLowerCase();
      final hasSmartCard = pickStr(['smart_card_number']).isNotEmpty;
      final hasCableNamePlan =
          pickStr(['cablename', 'cable_name']).isNotEmpty ||
          pickStr(['cableplan', 'cable_plan']).isNotEmpty;
      final hasElectricFields =
          pickStr(['meter', 'meter_number']).isNotEmpty ||
          pickStr(['meter_type', 'MeterType']).isNotEmpty ||
          pickStr(['disco_name']).isNotEmpty ||
          pickStr(['token']).isNotEmpty ||
          pickStr(['package']).toLowerCase().contains('electric');
      final hasRechargePinsArray =
          json['data_pin'] is List && (json['data_pin'] as List).isNotEmpty;
      final hasRechargeHints =
          hasRechargePinsArray ||
          pickStr(['name_on_card']).isNotEmpty ||
          pickStr(['pins', 'pin']).isNotEmpty;
      final hasExamHints =
          pickStr(['exam_name']).isNotEmpty ||
          pickStr(['service', 'product']).toLowerCase().contains('exam') ||
          pickStr(['service', 'product']).toLowerCase().contains('waec') ||
          pickStr(['service', 'product']).toLowerCase().contains('neco') ||
          pickStr(['service', 'product']).toLowerCase().contains('jamb') ||
          (pickStr(['data']).contains('result_checker_pin'));

      if (service.contains('data') ||
          product.contains('data') ||
          planTypeLower.contains('sme') ||
          planTypeLower.contains('gift') ||
          planTypeLower.contains('gifting') ||
          planTypeLower.contains('corporate') ||
          planNameLower.contains('gb') ||
          planNameLower.contains('mb')) {
        return TransactionType.data;
      }

      if (hasElectricFields ||
          service.contains('electric') ||
          product.contains('electric') ||
          product.contains('electricity') ||
          service.contains('electricity')) {
        return TransactionType.electricity;
      }

      if (hasExamHints) {
        return TransactionType.exam;
      }

      if (hasRechargeHints ||
          service.contains('recharge') ||
          service.contains('epin') ||
          product.contains('pin')) {
        return TransactionType.rechargeCard;
      }

      if (hasSmartCard ||
          hasCableNamePlan ||
          service.contains('cable') ||
          product.contains('cable') ||
          service.contains('tv') ||
          product.contains('tv') ||
          service.contains('dstv') ||
          product.contains('dstv') ||
          service.contains('gotv') ||
          product.contains('gotv') ||
          service.contains('startimes') ||
          product.contains('startimes')) {
        return TransactionType.cable;
      }

      if (hasAirtimeType ||
          service.contains('airtime') ||
          service.contains('vtu') ||
          service.contains('topup') ||
          product.contains('airtime') ||
          product.contains('vtu') ||
          product.contains('topup')) {
        return TransactionType.airtime;
      }

      if (service.contains('cable') ||
          product.contains('cable') ||
          service.contains('tv'))
        return TransactionType.cable;
      if (service.contains('electric') ||
          service.contains('electricity') ||
          product.contains('electric') ||
          product.contains('electricity') ||
          product.contains('aedc'))
        return TransactionType.electricity;
      if (service.contains('recharge') ||
          service.contains('epin') ||
          product.contains('pin'))
        return TransactionType.rechargeCard;
      if (service.contains('exam') ||
          product.contains('exam') ||
          service.contains('waec') ||
          product.contains('waec') ||
          service.contains('jamb') ||
          product.contains('jamb'))
        return TransactionType.exam;
      if (service.contains('sms')) return TransactionType.sms;

      final hasMobile = pickStr(['mobile_number', 'phone', 'Phone']).isNotEmpty;
      final hasNetworkName = pickStr([
        'plan_network',
        'network_name',
      ]).isNotEmpty;
      final hasAnyDataPlanField =
          pickStr(['plan_name', 'bundle']).isNotEmpty &&
          (service.contains('data') || product.contains('data'));
      if (hasMobile && hasNetworkName && !hasAnyDataPlanField)
        return TransactionType.airtime;

      return TransactionType.data;
    }

    final transactionType = determineTransactionType(json);

    String extractPins(Map<String, dynamic> json) {
      final rawRecharge = json['data_pin'];
      if (rawRecharge is List) {
        final pins = <String>[];
        for (final entry in rawRecharge) {
          if (entry is Map<String, dynamic>) {
            final fields = (entry['fields'] is Map<String, dynamic>)
                ? entry['fields'] as Map<String, dynamic>
                : entry;
            final pin = fields['pin']?.toString();
            if (pin != null && pin.trim().isNotEmpty) pins.add(pin.trim());
          }
        }
        if (pins.isNotEmpty) return pins.join('\n');
      }

      final dataStr = json['data'];
      if (dataStr is String && dataStr.trim().isNotEmpty) {
        try {
          final parsed = (jsonDecode(dataStr) as List)
              .whereType<Map<String, dynamic>>()
              .toList();
          final pins = <String>[];
          for (final m in parsed) {
            final fields = m['fields'];
            final rc = (fields is Map<String, dynamic>)
                ? fields['result_checker_pin']?.toString()
                : null;
            if (rc != null && rc.isNotEmpty) pins.add(rc);
          }
          if (pins.isNotEmpty) return pins.join('\n');
        } catch (_) {}
      }

      return pickStr(['pins', 'pin']);
    }

    return TransactionItem(
      id: pickStr(['id', 'tx_id', 'reference', 'transaction_id']),
      networkName: pickStr([
        'plan_network',
        'network_name',
        'networkLabel',
        'network',
      ]),
      planSize: pickStr(['plan_name', 'plan', 'bundle', 'product']),
      planType: pickStr(['plan_type', 'type']),
      timestamp: pickDate([
        'create_date',
        'created_at',
        'date',
        'transaction_date',
      ]),
      networkId: pickStr(['network', 'network_id']),
      amount: pickStr(['plan_amount', 'amount', 'amount_paid']),
      status: pickStr(['Status', 'status']),
      paymentMedium: pickStr(['payment_medium', 'paymentMethod']),
      balanceBefore: pickStr(['balance_before', 'previous_balance']),
      balanceAfter: pickStr(['balance_after', 'new_balance', 'after_balance']),
      mobileNumber: pickStr([
        'mobile_number',
        'phone',
        'Phone',
        'Customer_Phone',
      ]),
      plan: pickStr(['plan']),
      portedNumber: pickStr(['Ported_number', 'ported_number']),
      duration: pickStr(['duration', 'description']),
      apiResponse: pickStr(['api_response', 'response', 'message']),
      transactionType: transactionType,
      meterNumber: pickStr(['meter', 'meter_number']),
      meterType: pickStr(['meter_type', 'MeterType']),
      customerName: pickStr(['customer_name', 'name']),
      customerAddress: pickStr(['customer_address', 'address']),
      product: pickStr(['product', 'exam_name']),
      token: pickStr(['token']),
      quantity: pickStr(['quantity']),
      pins: extractPins(json),
      nameOnCard: pickStr(['name_on_card']),
      packageName: pickStr(['package']),
      service: pickStr(['service']),
      smartCardNumber: pickStr(['smart_card_number']),
      pinEntries: (() {
        if (json['data_pin'] is List)
          return List<dynamic>.from(json['data_pin'] as List);

        final dataStr = json['data'];
        if (dataStr is String && dataStr.trim().isNotEmpty) {
          try {
            final list = jsonDecode(dataStr);
            if (list is List) return List<dynamic>.from(list);
          } catch (_) {}
        }
        return null;
      })(),
      examName: pickStr(['exam_name']),
    );
  }
}
