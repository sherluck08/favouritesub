import 'package:provider/provider.dart';
import 'package:flutter/widgets.dart';
import 'package:favouritesub/providers/user_provider.dart';

class WalletService {
  static double parseBalanceString(String raw) {
    final onlyDigits = raw.replaceAll(RegExp(r'[^0-9\.]'), '');
    return double.tryParse(onlyDigits) ?? 0.0;
  }

  static double getWalletBalance(BuildContext context) {
    final up = Provider.of<UserProvider>(context, listen: false);
    return parseBalanceString(up.balance);
  }

  static bool hasSufficientBalance({
    required double balance,
    required double amount,
  }) {
    return balance >= amount && amount > 0;
  }
}
