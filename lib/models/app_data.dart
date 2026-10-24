import 'dart:convert';

class AppData {
  final UserData user;
  final List<BankAccount> banks;
  final WebConfig? webconfig;
  final AppMessage? notification;
  final AppMessage? alert;
  final List<AdminNumber> adminNumbers;
  final SmsPricing? smsPricing;
  final List<ExamItem> exam;
  final List<Cable> cable;
  final List<Disco> disco;
  final List<String> planTypes;
  final List<NetworkDef> networks;
  final AirtimePricing airtimePricing;

  AppData({
    required this.user,
    required this.banks,
    required this.webconfig,
    required this.notification,
    required this.alert,
    required this.adminNumbers,
    required this.smsPricing,
    required this.exam,
    required this.cable,
    required this.disco,
    required this.planTypes,
    required this.networks,
    required this.airtimePricing,
  });

  factory AppData.fromJson(Map<String, dynamic> json) {
    return AppData(
      user: UserData.fromJson(json['user'] as Map<String, dynamic>),
      banks: (json['banks'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(BankAccount.fromJson)
          .toList(),
      webconfig: (json['webconfig'] is Map)
          ? WebConfig.fromJson(json['webconfig'] as Map<String, dynamic>)
          : null,
      notification: (json['notification'] is Map)
          ? AppMessage.fromJson(json['notification'] as Map<String, dynamic>)
          : null,
      alert: (json['alert'] is Map)
          ? AppMessage.fromJson(json['alert'] as Map<String, dynamic>)
          : null,
      adminNumbers: (json['Admin_number'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(AdminNumber.fromJson)
          .toList(),
      smsPricing: (json['sms_pricing'] is Map)
          ? SmsPricing.fromJson(json['sms_pricing'] as Map<String, dynamic>)
          : null,
      exam: (json['exam'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ExamItem.fromJson)
          .toList(),
      cable: (json['cable'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(Cable.fromJson)
          .toList(),
      disco: (json['disco'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(Disco.fromJson)
          .toList(),
      planTypes: _parsePlanTypes(json['plan_type']),
      networks: _parseNetworks(json['network']),
      airtimePricing: AirtimePricing.fromAppData(json),
    );
  }

  Map<String, dynamic> toJson() => {
    'user': user.toJson(),
    'banks': banks.map((e) => e.toJson()).toList(),
    'webconfig': webconfig?.toJson(),
    'notification': notification?.toJson(),
    'alert': alert?.toJson(),
    'Admin_number': adminNumbers.map((e) => e.toJson()).toList(),
    'sms_pricing': smsPricing?.toJson(),
    'exam': exam.map((e) => e.toJson()).toList(),
    'cable': cable.map((e) => e.toJson()).toList(),
    'disco': disco.map((e) => e.toJson()).toList(),
    'plan_type': planTypes.map((e) => [e, e]).toList(),
    'network': networks.map((e) => e.toJson()).toList(),
    'topuppercentage': airtimePricing.toJson(),
  };

  static List<String> _parsePlanTypes(dynamic raw) {
    final out = <String>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is List && item.isNotEmpty) {
          final v = item.first?.toString();
          if (v != null) out.add(v.trim());
        } else if (item is String) {
          out.add(item.trim());
        }
      }
    }

    final seen = <String>{};
    return out.where((e) => seen.add(e.toUpperCase())).toList();
  }

  static List<NetworkDef> _parseNetworks(dynamic raw) {
    final list = <NetworkDef>[];
    if (raw is List) {
      for (final item in raw.whereType<Map>()) {
        list.add(NetworkDef.fromJson(Map<String, dynamic>.from(item)));
      }
    }
    return list;
  }

  static AppData fromJsonString(String jsonString) =>
      AppData.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  String toJsonString() => jsonEncode(toJson());
}

/// User-specific airtime rates returned by the backend.
///
/// The backend stores a percentage of face value (99 means the customer pays
/// 99%). Parsing and quoting live here so every branded app can reuse exactly
/// the same calculation for its form, confirmation screen and receipt.
class AirtimePricing {
  final Map<String, Map<String, double>> rates;

  const AirtimePricing(this.rates);

  factory AirtimePricing.fromJson(dynamic raw) {
    final parsed = <String, Map<String, double>>{};
    if (raw is Map) {
      raw.forEach((network, value) {
        if (value is! Map) return;
        final types = <String, double>{};
        value.forEach((type, rate) {
          final number = rate is num
              ? rate.toDouble()
              : double.tryParse(rate.toString());
          if (number != null) types[_key(type.toString())] = number;
        });
        parsed[_key(network.toString())] = types;
      });
    }
    return AirtimePricing(parsed);
  }

  /// Supports both API shapes used by the related branded projects:
  /// a top-level payment-percentage map and per-network discount percentages.
  factory AirtimePricing.fromAppData(Map<String, dynamic> json) {
    if (json['topuppercentage'] is Map) {
      return AirtimePricing.fromJson(json['topuppercentage']);
    }

    final parsed = <String, Map<String, double>>{};
    final networks = json['network'];
    if (networks is List) {
      for (final entry in networks.whereType<Map>()) {
        final network = entry['name']?.toString();
        final percentages = entry['topup_percentage'];
        if (network == null || percentages is! Map) continue;
        final vtuDiscount = _number(percentages['vtu_percentage']);
        final snsDiscount = _number(percentages['sns_percentage']);
        parsed[_key(network)] = {
          if (vtuDiscount != null) _key('VTU'): 100 - vtuDiscount,
          if (snsDiscount != null) _key('Share and Sell'): 100 - snsDiscount,
        };
      }
    }
    return AirtimePricing(parsed);
  }

  AirtimeQuote quote({
    required String network,
    required String airtimeType,
    required double faceValue,
  }) {
    final rawRate = rates[_key(network)]?[_key(airtimeType)] ?? 100;
    final ratePercent = rawRate <= 1 ? rawRate * 100 : rawRate;
    return AirtimeQuote(
      faceValue: faceValue,
      ratePercent: ratePercent.clamp(0, 100).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => rates;

  static String _key(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static double? _number(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '');
}

class AirtimeQuote {
  final double faceValue;
  final double ratePercent;

  const AirtimeQuote({required this.faceValue, required this.ratePercent});

  double get amountToPay => faceValue * ratePercent / 100;
  double get discountAmount => faceValue - amountToPay;
  double get discountPercent => 100 - ratePercent;
}

class UserData {
  final int id;
  final String email;
  final String username;
  final String? phone;
  final String? fullName;
  final double accountBalance;
  final String walletBalance;
  final String bonusBalance;
  final String? reservedAccountNumber;
  final String? reservedBankName;
  final String? bankName;
  final String? accountNumber;
  final String? accountName;
  final String? pin;
  final List<BankAccount>? accounts;

  UserData({
    required this.id,
    required this.email,
    required this.username,
    required this.phone,
    required this.fullName,
    required this.accountBalance,
    required this.walletBalance,
    required this.bonusBalance,
    required this.reservedAccountNumber,
    required this.reservedBankName,
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
    required this.pin,
    this.accounts,
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    List<BankAccount>? parsedAccounts;
    try {
      final dynamic accountsContainer =
          json['bank_accounts'] ?? json['accounts'];

      List<BankAccount> parseAccounts(dynamic raw) {
        final out = <BankAccount>[];
        if (raw is String && raw.trim().isNotEmpty) {
          final decoded = jsonDecode(raw);
          return parseAccounts(decoded);
        }
        if (raw is Map && raw['accounts'] is List) {
          for (final item in (raw['accounts'] as List).whereType<Map>()) {
            out.add(BankAccount.fromJson(Map<String, dynamic>.from(item)));
          }
          return out;
        }
        if (raw is List) {
          for (final item in raw.whereType<Map>()) {
            out.add(BankAccount.fromJson(Map<String, dynamic>.from(item)));
          }
          return out;
        }
        return out;
      }

      parsedAccounts = parseAccounts(accountsContainer);
    } catch (e) {
      print("Failed to decode accounts: $e");
    }

    return UserData(
      id: (json['id'] as num).toInt(),
      email: (json['email'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      phone: json['Phone']?.toString(),
      fullName: json['FullName']?.toString(),
      accountBalance: (json['Account_Balance'] as num?)?.toDouble() ?? 0.0,
      walletBalance: (json['wallet_balance'] ?? '0').toString(),
      bonusBalance: (json['bonus_balance'] ?? '0').toString(),
      reservedAccountNumber: json['reservedaccountNumber']?.toString(),
      pin: json['pin']?.toString(),
      reservedBankName: json['reservedbankName']?.toString(),
      bankName: json['BankName']?.toString(),
      accountNumber: json['AccountNumber']?.toString(),
      accountName: json['AccountName']?.toString(),
      accounts: parsedAccounts,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'username': username,
    'Phone': phone,
    'FullName': fullName,
    'Account_Balance': accountBalance,
    'wallet_balance': walletBalance,
    'bonus_balance': bonusBalance,
    'reservedaccountNumber': reservedAccountNumber,
    'pin': pin,
    'reservedbankName': reservedBankName,
    'BankName': bankName,
    'AccountNumber': accountNumber,
    'AccountName': accountName,
    'bank_accounts': accounts != null
        ? jsonEncode({'accounts': accounts!.map((e) => e.toJson()).toList()})
        : null,
  };
}

class BankAccount {
  final String bankCode;
  final String bankName;
  final String accountNumber;
  final String accountName;

  BankAccount({
    required this.bankCode,
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
  });

  factory BankAccount.fromJson(Map<String, dynamic> json) => BankAccount(
    bankCode: (json['bankCode'] ?? json['bank_code'] ?? '').toString(),
    bankName: (json['bankName'] ?? json['bank_name'] ?? '').toString(),
    accountNumber: (json['accountNumber'] ?? json['account_number'] ?? '')
        .toString(),
    accountName: (json['accountName'] ?? json['account_name'] ?? '').toString(),
  );

  Map<String, dynamic> toJson() => {
    'bankCode': bankCode,
    'bankName': bankName,
    'accountNumber': accountNumber,
    'accountName': accountName,
  };
}

class WebConfig {
  final String? supportPhoneNumber;
  final String? gmail;
  final String? whatsappGroupLink;
  final double airtimeToCashMinimumAmount;

  WebConfig({
    this.supportPhoneNumber,
    this.gmail,
    this.whatsappGroupLink,
    this.airtimeToCashMinimumAmount = 500,
  });

  factory WebConfig.fromJson(Map<String, dynamic> json) => WebConfig(
    supportPhoneNumber: json['support_phone_number']?.toString(),
    gmail: json['gmail']?.toString(),
    whatsappGroupLink: json['whatsapp_group_link']?.toString(),
    airtimeToCashMinimumAmount: _readMinimumAmount(
      json['airtime_to_cash_minimum_amount'],
    ),
  );

  Map<String, dynamic> toJson() => {
    'support_phone_number': supportPhoneNumber,
    'gmail': gmail,
    'whatsapp_group_link': whatsappGroupLink,
    'airtime_to_cash_minimum_amount': airtimeToCashMinimumAmount,
  };

  static double _readMinimumAmount(dynamic value) {
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');
    return parsed != null && parsed > 0 ? parsed : 500;
  }
}

class AppMessage {
  final String message;
  AppMessage({required this.message});
  factory AppMessage.fromJson(Map<String, dynamic> json) =>
      AppMessage(message: (json['message'] ?? '').toString());
  Map<String, dynamic> toJson() => {'message': message};
}

class AdminNumber {
  final String network;
  final String phoneNumber;
  AdminNumber({required this.network, required this.phoneNumber});
  factory AdminNumber.fromJson(Map<String, dynamic> json) => AdminNumber(
    network: (json['network'] ?? '').toString(),
    phoneNumber: (json['phone_number'] ?? '').toString(),
  );
  Map<String, dynamic> toJson() => {
    'network': network,
    'phone_number': phoneNumber,
  };
}

class SmsPricing {
  final double dnd;
  final double sms;
  SmsPricing({required this.dnd, required this.sms});
  factory SmsPricing.fromJson(Map<String, dynamic> json) => SmsPricing(
    dnd: (json['dnd'] as num?)?.toDouble() ?? 0,
    sms: (json['sms'] as num?)?.toDouble() ?? 0,
  );
  Map<String, dynamic> toJson() => {'dnd': dnd, 'sms': sms};
}

class ExamItem {
  final String examName;
  final double amount;
  ExamItem({required this.examName, required this.amount});
  factory ExamItem.fromJson(Map<String, dynamic> json) => ExamItem(
    examName: (json['exam_name'] ?? '').toString(),
    amount: (json['amount'] as num?)?.toDouble() ?? 0,
  );
  Map<String, dynamic> toJson() => {'exam_name': examName, 'amount': amount};
}

class CablePlan {
  final int id;
  final String package;
  final double planAmount;
  CablePlan({
    required this.id,
    required this.package,
    required this.planAmount,
  });
  factory CablePlan.fromJson(Map<String, dynamic> json) => CablePlan(
    id: (json['id'] as num).toInt(),
    package: (json['package'] ?? '').toString(),
    planAmount: (json['plan_amount'] as num?)?.toDouble() ?? 0,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'package': package,
    'plan_amount': planAmount,
  };
}

class Cable {
  final int id;
  final String name;
  final List<CablePlan> cableplan;
  Cable({required this.id, required this.name, required this.cableplan});
  factory Cable.fromJson(Map<String, dynamic> json) => Cable(
    id: (json['id'] as num).toInt(),
    name: (json['name'] ?? '').toString(),
    cableplan: (json['cableplan'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(CablePlan.fromJson)
        .toList(),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'cableplan': cableplan.map((e) => e.toJson()).toList(),
  };
}

class Disco {
  final int id;
  final String name;
  Disco({required this.id, required this.name});
  factory Disco.fromJson(Map<String, dynamic> json) => Disco(
    id: (json['id'] as num).toInt(),
    name: (json['name'] ?? '').toString(),
  );
  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

class NetworkPlanItem {
  final int id;
  final String plan;
  final double amount;
  final String validity;

  NetworkPlanItem({
    required this.id,
    required this.plan,
    required this.amount,
    required this.validity,
  });

  factory NetworkPlanItem.fromJson(Map<String, dynamic> json) =>
      NetworkPlanItem(
        id: (json['id'] as num).toInt(),
        plan: (json['plan'] ?? '').toString(),
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        validity: (json['month_validate'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'plan': plan,
    'amount': amount,
    'month_validate': validity,
  };
}

class NetworkDef {
  final String name;
  final int id;
  final Map<String, List<NetworkPlanItem>> plansByType;
  final List<RechargePricing> rechargeCardPricing;
  final double airtimeCashRatePercent;

  NetworkDef({
    required this.name,
    required this.id,
    required this.plansByType,
    required this.rechargeCardPricing,
    required this.airtimeCashRatePercent,
  });

  factory NetworkDef.fromJson(Map<String, dynamic> json) {
    final planMapRaw = json['plan'];
    final plansByType = <String, List<NetworkPlanItem>>{};
    if (planMapRaw is Map) {
      planMapRaw.forEach((type, listRaw) {
        final typeKey = type.toString().trim().toUpperCase();
        final items = (listRaw as List? ?? [])
            .whereType<Map>()
            .map((e) => NetworkPlanItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        plansByType[typeKey] = items;
      });
    }
    final recharge = <RechargePricing>[];
    final rechargeRaw = json['recharge_card_pricing'];
    if (rechargeRaw is List) {
      for (final item in rechargeRaw.whereType<Map>()) {
        recharge.add(RechargePricing.fromJson(Map<String, dynamic>.from(item)));
      }
    }
    return NetworkDef(
      name: (json['name'] ?? '').toString(),
      id: (json['id'] as num).toInt(),
      plansByType: plansByType,
      rechargeCardPricing: recharge,
      airtimeCashRatePercent: _readAirtimeCashRate(
        json['airtime_convert_percentage'],
      ),
    );
  }

  static double _readAirtimeCashRate(dynamic raw) {
    dynamic value = raw;
    if (raw is Map) value = raw['percent'];
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');
    return (parsed ?? 0).clamp(0, 100).toDouble();
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'id': id,
    'plan': plansByType.map(
      (k, v) => MapEntry(k, v.map((e) => e.toJson()).toList()),
    ),
    'recharge_card_pricing': rechargeCardPricing
        .map((e) => e.toJson())
        .toList(),
    'airtime_convert_percentage': {'percent': airtimeCashRatePercent},
  };

  List<NetworkPlanItem> getPlans(String planType) =>
      plansByType[planType.trim().toUpperCase()] ?? const [];
}

class RechargePricing {
  final int id;
  final double amount;
  final double amountToPay;

  RechargePricing({
    required this.id,
    required this.amount,
    required this.amountToPay,
  });

  factory RechargePricing.fromJson(Map<String, dynamic> json) =>
      RechargePricing(
        id: (json['id'] as num).toInt(),
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        amountToPay:
            (json['amountToPay'] as num?)?.toDouble() ??
            (json['amount_to_pay'] as num?)?.toDouble() ??
            0,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'amount': amount,
    'amountToPay': amountToPay,
  };
}
