import 'package:favouritesub/services/notification_store.dart';
import 'package:favouritesub/services/push_notification_service.dart';
import 'package:favouritesub/utils/friendly_error.dart';

enum TxKind {
  airtime,
  data,
  cable,
  electricity,
  examPin,
  rechargePin,
  voice,
  fundWallet,
  bulkSms,
  airtimeToCash,
  coupon,
  transfer,
  generic,
}

enum TxOutcome { success, processing, failed }

class TxInfo {
  final TxKind kind;
  final String? amount;
  final String? recipient;
  final String? network;
  final String? plan;
  final String? extra;

  const TxInfo({
    required this.kind,
    this.amount,
    this.recipient,
    this.network,
    this.plan,
    this.extra,
  });

  TxInfo copyWith({
    String? amount,
    String? recipient,
    String? network,
    String? plan,
    String? extra,
  }) => TxInfo(
    kind: kind,
    amount: amount ?? this.amount,
    recipient: recipient ?? this.recipient,
    network: network ?? this.network,
    plan: plan ?? this.plan,
    extra: extra ?? this.extra,
  );
}

class TransactionNotifier {
  static Future<void> notify({
    required TxInfo info,
    required TxOutcome outcome,
    String? rawError,
    double? cashbackEarned,
  }) async {
    final title = _title(info.kind, outcome);
    final body = _body(info, outcome, rawError);
    if (body.isEmpty) return;
    final fullBody =
        outcome == TxOutcome.success && _validCashback(cashbackEarned)
        ? '$body You earned ${_money(cashbackEarned!)} cashback.'
        : body;
    if (outcome == TxOutcome.success) {
      // Successful purchases are emitted by the backend ledger. Pulling the
      // authoritative event here avoids a second local banner/inbox item when
      // the same FCM push reaches this device.
      await NotificationStore.instance.syncFromBackend();
      return;
    }
    await PushNotificationService.instance.showLocal(
      title: title,
      body: fullBody,
    );
    NotificationStore.instance.add(
      title: title,
      body: fullBody,
      kind: _storeKind(outcome),
      meta: {
        'tx_kind': info.kind.name,
        if (info.amount != null) 'amount': info.amount,
        if (info.recipient != null) 'recipient': info.recipient,
        if (info.network != null) 'network': info.network,
        if (info.plan != null) 'plan': info.plan,
        if (_validCashback(cashbackEarned)) 'cashback': cashbackEarned,
      },
    );
  }

  static AppNotificationKind _storeKind(TxOutcome outcome) {
    switch (outcome) {
      case TxOutcome.success:
        return AppNotificationKind.transactionSuccess;
      case TxOutcome.processing:
        return AppNotificationKind.transactionProcessing;
      case TxOutcome.failed:
        return AppNotificationKind.transactionFailed;
    }
  }

  static String composeBody({
    required TxInfo info,
    required TxOutcome outcome,
    String? rawError,
    double? cashbackEarned,
  }) {
    final body = _body(info, outcome, rawError);
    if (outcome == TxOutcome.success && _validCashback(cashbackEarned)) {
      return '$body You earned ${_money(cashbackEarned!)} cashback.';
    }
    return body;
  }

  static String composeTitle({
    required TxKind kind,
    required TxOutcome outcome,
  }) => _title(kind, outcome);

  static bool _validCashback(double? v) => v != null && v > 0;

  static String _money(double v) {
    if (v <= 0) return '₦0';
    final isWhole = v == v.roundToDouble();
    final s = v
        .toStringAsFixed(isWhole ? 0 : 2)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
    return '₦$s';
  }

  static String _title(TxKind kind, TxOutcome outcome) {
    switch (outcome) {
      case TxOutcome.success:
        return '${_label(kind)} Successful';
      case TxOutcome.processing:
        return '${_label(kind)} Processing';
      case TxOutcome.failed:
        return '${_label(kind)} Failed';
    }
  }

  static String _label(TxKind kind) {
    switch (kind) {
      case TxKind.airtime:
        return 'Airtime Purchase';
      case TxKind.data:
        return 'Data Purchase';
      case TxKind.cable:
        return 'Cable Subscription';
      case TxKind.electricity:
        return 'Electricity Bill';
      case TxKind.examPin:
        return 'Exam Pin Purchase';
      case TxKind.rechargePin:
        return 'Recharge Pin Order';
      case TxKind.voice:
        return 'Voice Bundle';
      case TxKind.fundWallet:
        return 'Wallet Funding';
      case TxKind.bulkSms:
        return 'Bulk SMS';
      case TxKind.airtimeToCash:
        return 'Airtime to Cash';
      case TxKind.coupon:
        return 'Coupon Redemption';
      case TxKind.transfer:
        return 'Wallet Transfer';
      case TxKind.generic:
        return 'Transaction';
    }
  }

  static String _body(TxInfo info, TxOutcome outcome, String? rawError) {
    switch (outcome) {
      case TxOutcome.success:
        return _successBody(info);
      case TxOutcome.processing:
        return _processingBody(info);
      case TxOutcome.failed:
        return _failedBody(info, rawError);
    }
  }

  static String _successBody(TxInfo i) {
    final amt = i.amount;
    switch (i.kind) {
      case TxKind.airtime:
        final head = amt != null
            ? '$amt airtime delivered'
            : 'Airtime delivered';
        return '$head'
            '${i.recipient != null ? " to ${i.recipient}" : ""}'
            '${i.network != null ? " on ${i.network}" : ""}.';
      case TxKind.data:
        final plan = i.plan ?? 'Data bundle';
        return '$plan${i.network != null ? " (${i.network})" : ""}'
            '${i.recipient != null ? " activated on ${i.recipient}" : " activated"}'
            '${amt != null ? " — $amt" : ""}.';
      case TxKind.cable:
        final head = i.plan ?? 'Cable plan';
        return '$head'
            '${i.recipient != null ? " on smart card ${i.recipient}" : ""}'
            '${amt != null ? " — $amt" : ""}.';
      case TxKind.electricity:
        return 'Electricity'
            '${i.network != null ? " (${i.network})" : ""}'
            '${i.recipient != null ? " for meter ${i.recipient}" : ""}'
            '${amt != null ? " — $amt" : ""} delivered.';
      case TxKind.examPin:
        return 'Exam pin${i.plan != null ? " (${i.plan})" : ""} purchased${amt != null ? " for $amt" : ""}.';
      case TxKind.rechargePin:
        return 'Recharge pin order placed${i.network != null ? " for ${i.network}" : ""}${amt != null ? " — $amt" : ""}.';
      case TxKind.voice:
        return 'Voice bundle${i.plan != null ? " (${i.plan})" : ""}${i.recipient != null ? " activated on ${i.recipient}" : " activated"}${amt != null ? " — $amt" : ""}.';
      case TxKind.fundWallet:
        return 'Wallet funded${amt != null ? " with $amt" : ""}.';
      case TxKind.bulkSms:
        final extra = i.extra;
        return 'Message sent${extra != null ? " to $extra recipient(s)" : ""}${amt != null ? " — $amt" : ""}.';
      case TxKind.airtimeToCash:
        return 'Airtime-to-cash request received${amt != null ? " for $amt" : ""}. We will credit you shortly.';
      case TxKind.coupon:
        return 'Coupon redeemed${amt != null ? " — $amt added to your wallet" : ""}.';
      case TxKind.transfer:
        return 'Transfer of ${amt ?? "funds"}'
            '${i.recipient != null ? " to ${i.recipient}" : ""} completed.';
      case TxKind.generic:
        return 'Your transaction was completed successfully.';
    }
  }

  static String _processingBody(TxInfo i) {
    final amt = i.amount;
    switch (i.kind) {
      case TxKind.airtime:
        return 'Your airtime top-up${amt != null ? " of $amt" : ""}'
            '${i.recipient != null ? " for ${i.recipient}" : ""} is processing.';
      case TxKind.data:
        return 'Your data purchase${i.plan != null ? " (${i.plan})" : ""}'
            '${i.recipient != null ? " for ${i.recipient}" : ""} is processing.';
      case TxKind.cable:
        return 'Your cable subscription${i.recipient != null ? " on ${i.recipient}" : ""} is processing.';
      case TxKind.electricity:
        return 'Your electricity payment${i.recipient != null ? " for meter ${i.recipient}" : ""} is processing.';
      case TxKind.examPin:
        return 'Your exam pin order is processing.';
      case TxKind.rechargePin:
        return 'Your recharge pin order is processing.';
      case TxKind.voice:
        return 'Your voice bundle purchase is processing.';
      case TxKind.fundWallet:
        return 'Your wallet funding is processing.';
      case TxKind.bulkSms:
        return 'Your bulk SMS request is processing.';
      case TxKind.airtimeToCash:
        return 'Your airtime-to-cash request is processing.';
      case TxKind.coupon:
        return 'Your coupon is being verified.';
      case TxKind.transfer:
        return 'Your transfer is processing.';
      case TxKind.generic:
        return 'Your transaction is processing. We will notify you shortly.';
    }
  }

  static String _failedBody(TxInfo i, String? rawError) {
    final reason = rawError == null || rawError.trim().isEmpty
        ? 'Please try again.'
        : FriendlyError.sanitize(rawError, fallback: 'Please try again.');
    final what = _label(i.kind).toLowerCase();
    return 'Your $what could not be completed. $reason';
  }
}
