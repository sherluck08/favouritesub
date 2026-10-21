import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:favouritesub/providers/user_provider.dart';

class WalletBalanceText extends StatelessWidget {
  final TextStyle style;
  const WalletBalanceText({super.key, required this.style});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    return Text(userProvider.balance, style: style);
  }
}
