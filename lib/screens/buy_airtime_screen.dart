import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'package:favouritesub/screens/fund_wallet_screen.dart';
import 'package:favouritesub/services/purchase_service.dart';
import 'package:favouritesub/services/biometric_service.dart';
import 'package:favouritesub/providers/settings_provider.dart';
import 'package:favouritesub/services/wallet_service.dart';
import 'package:favouritesub/widgets/wallet_balance_text.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/beneficiary_service.dart';
import '../widgets/recent_beneficiaries_strip.dart';
import '../widgets/pin_auth_sheet.dart';
import '../widgets/primary_result_sheet.dart';
import '../services/transaction_notifier.dart';
import '../widgets/confirm_transaction_screen.dart';

import '../providers/app_data_provider.dart';
import '../models/app_data.dart';
import '../utils/utils.dart';

class BuyAirtimeScreen extends StatefulWidget {
  const BuyAirtimeScreen({super.key});

  @override
  State<BuyAirtimeScreen> createState() => _BuyAirtimeScreenState();
}

class _BuyAirtimeScreenState extends State<BuyAirtimeScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final FlutterNativeContactPicker _picker = FlutterNativeContactPicker();

  int? _selectedNetworkId;
  String? _selectedAirtimeType;
  final TextEditingController _amountController = TextEditingController();
  int? _selectedPresetIndex;
  List<BeneficiaryItem> _beneficiaries = const [];

  static const _presets = [100, 200, 500, 1000, 5000, 10000];

  @override
  void initState() {
    super.initState();
    _loadBeneficiaries();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickContact() async {
    try {
      final contact = await _picker.selectContact();
      if (contact != null && contact.phoneNumbers?.isNotEmpty == true) {
        final raw = contact.phoneNumbers!.first;
        final formatted = formatNigerianNumber(raw);
        setState(() {
          _phoneController.text = formatted;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Contact pick failed: $e')));
    }
  }

  bool get _isReady =>
      _selectedNetworkId != null &&
      _selectedAirtimeType != null &&
      _phoneController.text.length == 11 &&
      _amountController.text.trim().isNotEmpty;

  Future<void> _loadBeneficiaries() async {
    final items = await BeneficiaryService.load(
      service: BeneficiaryService.airtime,
    );
    if (!mounted) return;
    setState(() => _beneficiaries = items);
  }

  void _applyBeneficiary(BeneficiaryItem item) {
    setState(() {
      _selectedNetworkId = item.networkId;
      _selectedAirtimeType = null;
      _selectedPresetIndex = null;
      _phoneController.text = item.phone;
      _amountController.clear();
    });
    FocusScope.of(context).unfocus();
  }

  void _onNetworkTap(int id) {
    setState(() {
      _selectedNetworkId = id;
      _selectedAirtimeType = null;
      _selectedPresetIndex = null;
      _amountController.clear();
    });
  }

  void _onPresetTap(int index) {
    setState(() {
      _selectedPresetIndex = index;
      _amountController.text = _presets[index].toString();
    });
  }

  String _logoForNetwork(int networkId) =>
      _NetworkChip._images[networkId] ?? '';

  AirtimeQuote? _currentQuote(AppDataProvider provider) {
    final networkId = _selectedNetworkId;
    final airtimeType = _selectedAirtimeType;
    final faceValue = double.tryParse(_amountController.text.trim());
    final data = provider.data;
    if (networkId == null ||
        airtimeType == null ||
        faceValue == null ||
        faceValue <= 0 ||
        data == null) {
      return null;
    }
    final matches = data.networks.where((item) => item.id == networkId);
    if (matches.isEmpty) return null;
    return data.airtimePricing.quote(
      network: matches.first.name,
      airtimeType: airtimeType,
      faceValue: faceValue,
    );
  }

  String _money(double value) => '₦${value.toStringAsFixed(2)}';

  String _percent(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);

  Future<void> _saveBeneficiary({
    required int networkId,
    required String networkName,
    required String phone,
  }) async {
    final items = await BeneficiaryService.save(
      service: BeneficiaryService.airtime,
      networkId: networkId,
      networkName: networkName,
      phone: phone,
    );
    if (!mounted) return;
    setState(() => _beneficiaries = items);
  }

  void _onNext() {
    if (!_isReady) return;
    final appData = Provider.of<AppDataProvider>(context, listen: false);
    final availableNetworks = appData.networks;
    if (availableNetworks.isEmpty) return;
    final network = availableNetworks.firstWhere(
      (item) => item.id == _selectedNetworkId,
      orElse: () => availableNetworks.first,
    );
    final networkId = _selectedNetworkId!;
    final airtimeType = _selectedAirtimeType!;
    final phone = _phoneController.text.trim();
    final amount = _amountController.text.trim();
    final quote = _currentQuote(appData);
    if (quote == null) return;
    final imagePath = _logoForNetwork(networkId);

    pushConfirmTransaction(
      context,
      networkImage: imagePath.isNotEmpty
          ? Image.asset(imagePath, fit: BoxFit.contain)
          : const Icon(Icons.phone_in_talk_rounded, size: 40),
      details: [
        TxDetail('To', phone),
        TxDetail('Airtime value', _money(quote.faceValue)),
        TxDetail(
          'Discount (${_percent(quote.discountPercent)}%)',
          '-${_money(quote.discountAmount)}',
        ),
        TxDetail('Amount to pay', _money(quote.amountToPay)),
        TxDetail('Network', network.name),
        TxDetail('Description', '${network.name} $airtimeType'),
      ],
      onExecute: () async {
        final result = await PurchaseService.buyAirtime(
          networkId: networkId,
          airtimeType: airtimeType,
          phone: phone,
          amount: amount,
        );
        final status = (result['status'] ?? result['Status'] ?? '')
            .toString()
            .toLowerCase();
        if (status.contains('success')) {
          await _saveBeneficiary(
            networkId: networkId,
            networkName: network.name,
            phone: phone,
          );
        }
        return result;
      },
      successTitle: 'Transaction Successful!',
      successMsg:
          "Congratulations! You've successfully purchased airtime for $phone on ${network.name}",
      notify: TxInfo(
        kind: TxKind.airtime,
        amount: _money(quote.amountToPay),
        recipient: phone,
        network: network.name,
      ),
    );
  }

  void _showAirtimeTypeSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final options = const ['VTU', 'Share and Sell'];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                height: 4,
                width: 42,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Select Airtime Type',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              ...options.map(
                (opt) => ListTile(
                  title: Text(opt),
                  trailing: _selectedAirtimeType == opt
                      ? Icon(
                          Icons.check,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedAirtimeType = opt;
                      _selectedPresetIndex = null;
                      _amountController.clear();
                    });
                    Navigator.of(context).pop();
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // Retained temporarily for compatibility with the previous checkout flow.
  // ignore: unused_element
  void _showSummarySheet({required String networkName}) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: 50,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Confirm Airtime Topup',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    _kv('Network', networkName),
                    const SizedBox(height: 8),
                    _kv('Airtime Type', _selectedAirtimeType ?? ''),
                    const SizedBox(height: 8),
                    _kv('Phone', _phoneController.text),
                    const SizedBox(height: 8),
                    _kv('Amount', _amountController.text),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Wallet Balance",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 10),
              Container(
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    WalletBalanceText(
                      style: TextStyle(
                        fontSize: 22,
                        letterSpacing: 2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const FundWalletScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        "Fund Wallet",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),

              Builder(
                builder: (context) {
                  final amount =
                      double.tryParse(_amountController.text.trim()) ?? 0.0;
                  final hasEnough = WalletService.hasSufficientBalance(
                    balance: WalletService.getWalletBalance(context),
                    amount: amount,
                  );
                  return hasEnough
                      ? const SizedBox(height: 16)
                      : Padding(
                          padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                          child: Text(
                            'Insufficient balance',
                            style: TextStyle(
                              color: Colors.redAccent.shade200,
                              fontSize: 13,
                            ),
                          ),
                        );
                },
              ),

              SizedBox(
                width: MediaQuery.of(context).size.width,
                child: Container(
                  decoration: (() {
                    final amount =
                        double.tryParse(_amountController.text.trim()) ?? 0.0;
                    final hasEnough = WalletService.hasSufficientBalance(
                      balance: WalletService.getWalletBalance(context),
                      amount: amount,
                    );
                    return BoxDecoration(
                      color: hasEnough ? null : Colors.grey,
                      gradient: hasEnough
                          ? LinearGradient(
                              colors: [
                                Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.85),
                                Theme.of(context).colorScheme.primary,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: hasEnough
                          ? [
                              BoxShadow(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.35),
                                offset: const Offset(0, 4),
                                blurRadius: 10,
                              ),
                            ]
                          : [],
                    );
                  })(),
                  child: ElevatedButton(
                    onPressed: () async {
                      final balance = WalletService.getWalletBalance(context);
                      final amount =
                          double.tryParse(_amountController.text.trim()) ?? 0.0;
                      if (!WalletService.hasSufficientBalance(
                        balance: balance,
                        amount: amount,
                      )) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Insufficient balance')),
                        );
                        return;
                      }

                      final requireBio = Provider.of<SettingsProvider>(
                        context,
                        listen: false,
                      ).biometricPayEnabled;
                      final result = await showPinAuthSheet(
                        context,
                        allowBiometric: requireBio,
                        biometricAuth: () => BiometricService.authenticate(
                          context,
                          reason: 'Confirm payment',
                        ),
                      );
                      if (result == null || !result.success) return;
                      await _performAirtimePurchase();
                    },
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 60,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      "Confirm Payment",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 70),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(k, style: TextStyle(color: Colors.grey.shade700)),
        const SizedBox(width: 12),
        Flexible(child: Text(v, textAlign: TextAlign.right)),
      ],
    );
  }

  Future<void> _performAirtimePurchase() async {
    if (_selectedNetworkId == null ||
        _selectedAirtimeType == null ||
        _phoneController.text.length != 11) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all fields')),
      );
      return;
    }
    final amount = _amountController.text.trim();
    if (amount.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter amount')));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final res = await PurchaseService.buyAirtime(
        networkId: _selectedNetworkId!,
        airtimeType: _selectedAirtimeType!,
        phone: _phoneController.text.trim(),
        amount: amount,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      final status = (res['status'] ?? '').toString();

      if (status == 'success') {
        final appData = Provider.of<AppDataProvider>(context, listen: false);
        final network = appData.networks.firstWhere(
          (item) => item.id == _selectedNetworkId,
          orElse: () => appData.networks.first,
        );
        await _saveBeneficiary(
          networkId: _selectedNetworkId!,
          networkName: network.name,
          phone: _phoneController.text.trim(),
        );
        if (!mounted) return;
        _showResult(
          'Airtime Purchase Successful',
          Colors.green,
          Icons.check_circle_outline,
        );
      } else if (status == 'processing') {
        _showResult('Processing', Colors.orange, Icons.hourglass_bottom);
      } else if (status == 'failed') {
        _showResult(
          res['message']['error'][0]?.toString() ?? 'Purchase failed',
          Colors.red,
          Icons.error_outline,
        );
      } else {
        _showResult(
          res['message']['error'][0]?.toString() ?? 'Purchase failed',
          Colors.red,
          Icons.error_outline,
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      _showResult('Error: $e', Colors.red, Icons.error_outline);
    }
  }

  void _showResult(String message, Color color, IconData icon) {
    showPrimaryResultSheet(
      context,
      title: message,
      color: color,
      primaryButtonLabel: 'Done',
      onPrimaryPressed: () {},
      secondaryButtonLabel: 'View Transactions',
      onSecondaryPressed: () {
        Navigator.of(context).pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final appData = Provider.of<AppDataProvider>(context);
    if (appData.data == null && !appData.isLoading) {
      Future.microtask(appData.load);
    }

    final networkProviders = appData.networks.reversed
        .where((network) => const {1, 2, 3, 4}.contains(network.id))
        .toList();
    final hasNetwork = _selectedNetworkId != null;
    final hasType = _selectedAirtimeType != null;
    final quote = _currentQuote(appData);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cs.onPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          'Airtime',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: cs.onPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _NextButton(active: _isReady, onTap: _onNext, cs: cs),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AirtimeWalletBar(cs: cs),
              const SizedBox(height: 24),
              RecentBeneficiariesStrip(
                items: _beneficiaries,
                logoForNetwork: _logoForNetwork,
                onTap: _applyBeneficiary,
              ),
              if (_beneficiaries.isNotEmpty) const SizedBox(height: 24),
              const _SectionLabel('Select Network'),
              const SizedBox(height: 12),
              SizedBox(
                height: 62,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: networkProviders.length,
                  itemBuilder: (context, index) {
                    final network = networkProviders[index];
                    final selected = _selectedNetworkId == network.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 32),
                      child: _NetworkChip(
                        networkId: network.id,
                        isSelected: selected,
                        dim: hasNetwork && !selected,
                        onTap: () => _onNetworkTap(network.id),
                      ),
                    );
                  },
                ),
              ),
              if (hasNetwork) ...[
                const SizedBox(height: 24),
                const _SectionLabel('Airtime Types'),
                const SizedBox(height: 8),
                _DropdownField(
                  value: _selectedAirtimeType,
                  hint: 'Airtime Types',
                  onTap: _showAirtimeTypeSheet,
                  cs: cs,
                ),
              ],
              const SizedBox(height: 24),
              const _SectionLabel('Phone Number'),
              const SizedBox(height: 8),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 11,
                onChanged: (_) => setState(() {}),
                inputFormatters: [
                  LengthLimitingTextInputFormatter(11),
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: _fieldDecoration(
                  cs,
                  hint: 'Phone Number',
                  suffixIcon: IconButton(
                    icon: Icon(
                      Icons.contacts_rounded,
                      color: cs.onSurfaceVariant,
                    ),
                    onPressed: _pickContact,
                  ),
                  counterText: '',
                ),
              ),
              if (hasType) ...[
                const SizedBox(height: 24),
                const _SectionLabel('Choose an amount'),
                const SizedBox(height: 12),
                _AmountChipsGrid(
                  presets: _presets,
                  selectedIndex: _selectedPresetIndex,
                  cs: cs,
                  onTap: _onPresetTap,
                ),
                const SizedBox(height: 24),
                Row(children: [const _SectionLabel('Amount')]),
                const SizedBox(height: 8),
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) {
                    setState(() => _selectedPresetIndex = null);
                  },
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(7),
                  ],
                  decoration: _fieldDecoration(cs, hint: 'Amount'),
                ),
                if (quote != null) ...[
                  const SizedBox(height: 14),
                  _AirtimePriceBreakdown(
                    quote: quote,
                    money: _money,
                    percent: _percent,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(
    ColorScheme cs, {
    required String hint,
    Widget? suffixIcon,
    String? counterText,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.35),
      hintText: hint,
      hintStyle: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.primary, width: 1.5),
      ),
      counterText: counterText,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}

class _AirtimePriceBreakdown extends StatelessWidget {
  final AirtimeQuote quote;
  final String Function(double) money;
  final String Function(double) percent;

  const _AirtimePriceBreakdown({
    required this.quote,
    required this.money,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.primary.withValues(alpha: 0.14)),
      ),
      child: Column(
        children: [
          _PriceRow(label: 'Airtime value', value: money(quote.faceValue)),
          const SizedBox(height: 10),
          _PriceRow(
            label: 'Discount (${percent(quote.discountPercent)}%)',
            value: '-${money(quote.discountAmount)}',
            valueColor: const Color(0xFF087A4B),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: cs.outlineVariant),
          ),
          _PriceRow(
            label: 'Amount to pay',
            value: money(quote.amountToPay),
            emphasized: true,
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool emphasized;

  const _PriceRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: emphasized
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: valueColor ?? theme.colorScheme.onSurface,
            fontWeight: emphasized ? FontWeight.w800 : FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

class _AirtimeWalletBar extends StatelessWidget {
  final ColorScheme cs;
  const _AirtimeWalletBar({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.credit_card_rounded, size: 20, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            'Wallet Balance',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
            ),
          ),
          const Spacer(),
          Consumer<UserProvider>(
            builder: (_, user, __) => Text(
              user.balance,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: cs.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NextButton extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  final ColorScheme cs;
  const _NextButton({
    required this.active,
    required this.onTap,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: active ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? cs.onPrimary : cs.onPrimary.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Next',
          style: TextStyle(
            color: active ? cs.primary : cs.onPrimary.withValues(alpha: 0.55),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _NetworkChip extends StatelessWidget {
  final int networkId;
  final bool isSelected;
  final bool dim;
  final VoidCallback onTap;

  const _NetworkChip({
    required this.networkId,
    required this.isSelected,
    required this.dim,
    required this.onTap,
  });

  static const _bgColors = {
    1: Color(0xFFFFD700),
    2: Color(0xFF53AC46),
    3: Color(0xFF6DBE4F),
    4: Color(0xFFFFCDD2),
  };

  static const _images = {
    1: 'assets/images/mtn_logo.png',
    2: 'assets/images/glo_logo.png',
    3: 'assets/images/9mobile_logo.png',
    4: 'assets/images/airtel_logo.png',
  };

  @override
  Widget build(BuildContext context) {
    final image = _images[networkId] ?? '';
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: dim ? 0.35 : 1,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: _bgColors[networkId] ?? Colors.grey.shade200,
                borderRadius: BorderRadius.circular(14),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: image.isNotEmpty
                    ? Image.asset(image, fit: BoxFit.contain)
                    : const SizedBox.shrink(),
              ),
            ),
            if (isSelected)
              Positioned(
                bottom: -4,
                right: -4,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(1),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 20,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String? value;
  final String hint;
  final VoidCallback onTap;
  final ColorScheme cs;

  const _DropdownField({
    required this.value,
    required this.hint,
    required this.onTap,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              value ?? hint,
              style: TextStyle(
                fontSize: 15,
                color: value != null
                    ? cs.onSurface
                    : cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _AmountChipsGrid extends StatelessWidget {
  final List<int> presets;
  final int? selectedIndex;
  final ColorScheme cs;
  final ValueChanged<int> onTap;

  const _AmountChipsGrid({
    required this.presets,
    required this.selectedIndex,
    required this.cs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.6,
      ),
      itemCount: presets.length,
      itemBuilder: (_, index) {
        final selected = selectedIndex == index;
        return GestureDetector(
          onTap: () => onTap(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? cs.onSurface
                  : cs.surfaceContainerHighest.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'N${presets[index]}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: selected ? cs.surface : cs.onSurface,
              ),
            ),
          ),
        );
      },
    );
  }
}
