import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:favouritesub/models/app_data.dart';
import 'package:favouritesub/providers/app_data_provider.dart';
import 'package:favouritesub/providers/user_provider.dart';
import 'package:favouritesub/services/bonus_service.dart';
import 'package:favouritesub/widgets/my_textfield.dart';
import 'package:favouritesub/widgets/primary_button.dart';
import 'package:favouritesub/widgets/primary_result_sheet.dart';
import 'package:favouritesub/widgets/pin_auth_sheet.dart';
import 'package:favouritesub/services/biometric_service.dart';

class BonusToWalletScreen extends StatefulWidget {
  const BonusToWalletScreen({super.key});

  @override
  State<BonusToWalletScreen> createState() => _BonusToWalletScreenState();
}

class _BonusToWalletScreenState extends State<BonusToWalletScreen> {
  final TextEditingController _amountCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();

    final appData = Provider.of<AppDataProvider>(context, listen: false).data;
    final bonus = _parseAmount(appData?.user.bonusBalance ?? '0');
    if (bonus > 0) {
      _amountCtrl.text = bonus.toStringAsFixed(2);
    }
  }

  double _parseAmount(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^0-9\.]'), '');
    return double.tryParse(cleaned) ?? 0.0;
  }

  Future<void> _submit() async {
    final amountText = _amountCtrl.text.trim();
    final amount = _parseAmount(amountText);

    final appData = Provider.of<AppDataProvider>(context, listen: false).data;
    final UserData? user = appData?.user;
    final bonus = _parseAmount(user?.bonusBalance ?? '0');

    String? error;
    if (amount <= 0) {
      error = 'Enter a valid amount';
    } else if (amount > bonus) {
      error = 'Amount exceeds your bonus balance';
    }
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    final pinResult = await showPinAuthSheet(
      context,
      allowBiometric: true,
      biometricAuth: () => BiometricService.authenticate(
        context,
        reason: 'Confirm transfer from bonus to wallet',
      ),
    );
    if (pinResult == null || !pinResult.success) {
      return;
    }

    setState(() => _submitting = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final resp = await BonusService.transferBonusToWallet(
        amount: amount.toStringAsFixed(2),
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      if (resp['error'] != null) {
        await showPrimaryResultSheet(
          context,
          color: Colors.red,
          icon: Icons.error,
          title: 'Transfer Failed',
          message: resp['error'],
        );
      } else {
        await showPrimaryResultSheet(
          context,
          color: Colors.green,
          icon: Icons.check_circle,
          title: 'Bonus Transfer',
          message: (resp['message'] ?? resp['Status'] ?? 'Transfer successful')
              .toString(),
        );
      }

      await Provider.of<UserProvider>(context, listen: false).refreshUserData();
      await Provider.of<AppDataProvider>(context, listen: false).refresh();

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      await showPrimaryResultSheet(
        context,
        title: 'Transfer Failed',
        message: e.toString(),
        primaryButtonLabel: 'Close',
        color: Colors.red,
        icon: Icons.error,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final appData = Provider.of<AppDataProvider>(context).data;
    final bonus = _parseAmount(appData?.user.bonusBalance ?? '0');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer Bonus to Wallet'),
        centerTitle: true,
        backgroundColor: color,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Amount',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                MyTextfield(
                  hintText: '0.00',
                  textController: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9\.]')),
                  ],
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                Text(
                  'Bonus balance: ₦${bonus.toStringAsFixed(2)}',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: _submitting ? 'Processing...' : 'Proceed',
                  onPressed: _submitting ? null : _submit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
