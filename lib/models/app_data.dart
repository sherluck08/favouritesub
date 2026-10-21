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

  WebConfig({this.supportPhoneNumber, this.gmail, this.whatsappGroupLink});

  factory WebConfig.fromJson(Map<String, dynamic> json) => WebConfig(
    supportPhoneNumber: json['support_phone_number']?.toString(),
    gmail: json['gmail']?.toString(),
    whatsappGroupLink: json['whatsapp_group_link']?.toString(),
  );

  Map<String, dynamic> toJson() => {
    'support_phone_number': supportPhoneNumber,
    'gmail': gmail,
    'whatsapp_group_link': whatsappGroupLink,
  };
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

  NetworkDef({
    required this.name,
    required this.id,
    required this.plansByType,
    required this.rechargeCardPricing,
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
    );
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
