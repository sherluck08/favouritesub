import 'dart:async';

import 'package:favouritesub/models/app_data.dart';
import 'package:favouritesub/providers/app_data_provider.dart';
import 'package:favouritesub/services/airtime_to_cash_service.dart';
import 'package:favouritesub/utils/friendly_error.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

enum _PayoutDestination { wallet, bank }

class AirtimeToCashScreen extends StatefulWidget {
  const AirtimeToCashScreen({super.key});

  @override
  State<AirtimeToCashScreen> createState() => _AirtimeToCashScreenState();
}

class _AirtimeToCashScreenState extends State<AirtimeToCashScreen> {
  final _phoneController = TextEditingController();
  final _amountController = TextEditingController();
  int? _networkId;
  _PayoutDestination _destination = _PayoutDestination.wallet;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppDataProvider>().silentRefresh();
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  String _money(num value) => NumberFormat.currency(
    locale: 'en_NG',
    symbol: '₦',
    decimalDigits: value % 1 == 0 ? 0 : 2,
  ).format(value);

  AdminNumber? _receiverFor(AppData data, String networkName) {
    final key = networkName.trim().toUpperCase();
    for (final item in data.adminNumbers) {
      if (item.network.trim().toUpperCase() == key &&
          item.phoneNumber.trim().isNotEmpty) {
        return item;
      }
    }
    return null;
  }

  bool _hasBankDetails(UserData user) =>
      (user.bankName?.trim().isNotEmpty ?? false) &&
      (user.accountNumber?.trim().isNotEmpty ?? false) &&
      (user.accountName?.trim().isNotEmpty ?? false);

  int _networkOrder(String networkName) {
    return switch (networkName.trim().toUpperCase()) {
      'MTN' => 0,
      'GLO' => 1,
      'AIRTEL' => 2,
      '9MOBILE' => 100,
      _ => 50,
    };
  }

  Future<void> _proceed(AppData data) async {
    final phone = _phoneController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());
    final minimumAmount = data.webconfig?.airtimeToCashMinimumAmount ?? 500;
    final matches = data.networks.where((item) => item.id == _networkId);

    String? error;
    if (matches.isEmpty) {
      error = 'Select the network of the SIM sending the airtime.';
    } else if (phone.length != 11 || !RegExp(r'^0\d{10}$').hasMatch(phone)) {
      error = 'Enter the 11-digit phone number that will send the airtime.';
    } else if (amount == null || amount < minimumAmount) {
      error = 'The minimum airtime amount is ${_money(minimumAmount)}.';
    } else if (_destination == _PayoutDestination.bank && amount < 1000) {
      error = 'Bank payout is available from ₦1,000. Choose wallet instead.';
    } else if (_destination == _PayoutDestination.bank &&
        !_hasBankDetails(data.user)) {
      error =
          'Add complete bank details to your profile before choosing bank payout.';
    }

    if (error != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    final network = matches.first;
    final receiver = _receiverFor(data, network.name);
    if (receiver == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A receiving number is not available for this network.',
          ),
        ),
      );
      return;
    }
    if (network.airtimeCashRatePercent <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Airtime to cash is not available for this network.'),
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _AirtimeTransferInstructionsScreen(
          network: network,
          senderPhone: phone,
          receiverPhone: receiver.phoneNumber.trim(),
          airtimeAmount: amount!,
          cashAmount: amount * network.airtimeCashRatePercent / 100,
          payoutDestination: _destination,
          bankName: data.user.bankName,
          accountNumber: data.user.accountNumber,
        ),
      ),
    );
    if (submitted == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final provider = context.watch<AppDataProvider>();
    final data = provider.data;
    final availableNetworks = data == null
        ? const <NetworkDef>[]
        : (data.networks
              .where(
                (network) =>
                    network.airtimeCashRatePercent > 0 &&
                    _receiverFor(data, network.name) != null,
              )
              .toList()
            ..sort((a, b) {
              final order = _networkOrder(
                a.name,
              ).compareTo(_networkOrder(b.name));
              return order != 0 ? order : a.name.compareTo(b.name);
            }));
    final minimumAmount = data?.webconfig?.airtimeToCashMinimumAmount ?? 500;
    final selected = availableNetworks
        .where((network) => network.id == _networkId)
        .firstOrNull;
    final amount = double.tryParse(_amountController.text.trim());
    final cashAmount = selected != null && amount != null
        ? amount * selected.airtimeCashRatePercent / 100
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Airtime to cash'), centerTitle: true),
      body: data == null
          ? _LoadingState(
              hasError: provider.error != null,
              onRetry: provider.refresh,
            )
          : GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 40),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _IntroCard(colors: colors),
                        const SizedBox(height: 26),
                        const _SectionLabel('Select network'),
                        const SizedBox(height: 12),
                        if (availableNetworks.isEmpty)
                          _UnavailableCard(colors: colors)
                        else
                          SizedBox(
                            height: 92,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: availableNetworks.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (context, index) {
                                final network = availableNetworks[index];
                                return _NetworkOption(
                                  network: network,
                                  selected: network.id == _networkId,
                                  onTap: () => setState(() {
                                    _networkId = network.id;
                                  }),
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 24),
                        const _SectionLabel('Your sending SIM'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(11),
                          ],
                          decoration: _fieldDecoration(
                            context,
                            hint: 'e.g. 08012345678',
                            icon: Icons.sim_card_outlined,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const _SectionLabel('Airtime amount'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _amountController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(7),
                          ],
                          onChanged: (_) => setState(() {}),
                          decoration: _fieldDecoration(
                            context,
                            hint: 'Minimum ${_money(minimumAmount)}',
                            icon: Icons.payments_outlined,
                            prefixText: '₦ ',
                          ),
                        ),
                        if (cashAmount != null && cashAmount > 0) ...[
                          const SizedBox(height: 14),
                          _QuoteCard(
                            rate: selected!.airtimeCashRatePercent,
                            airtimeAmount: amount!,
                            cashAmount: cashAmount,
                            money: _money,
                          ),
                        ],
                        const SizedBox(height: 24),
                        const _SectionLabel('Receive payment in'),
                        const SizedBox(height: 10),
                        _PayoutOptions(
                          value: _destination,
                          user: data.user,
                          bankAvailable: _hasBankDetails(data.user),
                          onChanged: (value) =>
                              setState(() => _destination = value),
                        ),
                        const SizedBox(height: 26),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: availableNetworks.isEmpty
                                ? null
                                : () => _proceed(data),
                            icon: const Icon(Icons.arrow_forward_rounded),
                            label: const Text(
                              'Proceed',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(54),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _AirtimeTransferInstructionsScreen extends StatefulWidget {
  const _AirtimeTransferInstructionsScreen({
    required this.network,
    required this.senderPhone,
    required this.receiverPhone,
    required this.airtimeAmount,
    required this.cashAmount,
    required this.payoutDestination,
    this.bankName,
    this.accountNumber,
  });

  final NetworkDef network;
  final String senderPhone;
  final String receiverPhone;
  final double airtimeAmount;
  final double cashAmount;
  final _PayoutDestination payoutDestination;
  final String? bankName;
  final String? accountNumber;

  @override
  State<_AirtimeTransferInstructionsScreen> createState() =>
      _AirtimeTransferInstructionsScreenState();
}

class _AirtimeTransferInstructionsScreenState
    extends State<_AirtimeTransferInstructionsScreen> {
  late final DateTime _expiresAt;
  Timer? _timer;
  Duration _remaining = const Duration(minutes: 30);
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _expiresAt = DateTime.now().add(const Duration(minutes: 30));
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    final remaining = _expiresAt.difference(DateTime.now());
    if (!mounted) return;
    setState(
      () => _remaining = remaining.isNegative ? Duration.zero : remaining,
    );
    if (remaining.isNegative) _timer?.cancel();
  }

  String _money(num value) => NumberFormat.currency(
    locale: 'en_NG',
    symbol: '₦',
    decimalDigits: value % 1 == 0 ? 0 : 2,
  ).format(value);

  String get _countdown =>
      '${_remaining.inMinutes.toString().padLeft(2, '0')}:'
      '${(_remaining.inSeconds % 60).toString().padLeft(2, '0')}';

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    await HapticFeedback.selectionClick();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$label copied')));
  }

  Future<void> _showFinalConfirmation() async {
    if (_remaining == Duration.zero || _submitting) return;
    var confirmed = false;
    final shouldSubmit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          icon: Icon(
            Icons.verified_user_outlined,
            color: Theme.of(context).colorScheme.primary,
            size: 34,
          ),
          title: const Text('Have you sent the airtime?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Confirm only if you sent exactly ${_money(widget.airtimeAmount)} '
                '${widget.network.name} airtime to ${widget.receiverPhone}.',
                style: const TextStyle(height: 1.45),
              ),
              const SizedBox(height: 14),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: confirmed,
                onChanged: (value) =>
                    setDialogState(() => confirmed = value ?? false),
                title: const Text(
                  'I have completed this transfer from my personal SIM.',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                'False confirmation may lead to restrictions on your account.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Not yet'),
            ),
            FilledButton(
              onPressed: confirmed
                  ? () => Navigator.of(dialogContext).pop(true)
                  : null,
              child: const Text('Yes, airtime sent'),
            ),
          ],
        ),
      ),
    );
    if (shouldSubmit == true) await _submit();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final result = await AirtimeToCashService.submit(
        networkId: widget.network.id,
        senderPhone: widget.senderPhone,
        airtimeAmount: widget.airtimeAmount,
        fundWallet: widget.payoutDestination == _PayoutDestination.wallet,
      );
      if (!mounted) return;
      final done = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => _AirtimeRequestSubmittedScreen(
            result: result,
            networkName: widget.network.name,
            senderPhone: widget.senderPhone,
            receiverPhone: widget.receiverPhone,
            airtimeAmount: widget.airtimeAmount,
            cashAmount: widget.cashAmount,
            payoutLabel: widget.payoutDestination == _PayoutDestination.wallet
                ? 'Wallet'
                : '${widget.bankName} • ${widget.accountNumber}',
          ),
        ),
      );
      if (done == true && mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              FriendlyError.from(
                error,
                fallback: 'We could not submit your request. Please try again.',
              ),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final guide = _TransferGuide.forNetwork(
      widget.network.name,
      receiver: widget.receiverPhone,
      amount: widget.airtimeAmount.toStringAsFixed(0),
    );
    final expired = _remaining == Duration.zero;

    return PopScope(
      canPop: !_submitting,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Send airtime'),
          centerTitle: true,
          automaticallyImplyLeading: !_submitting,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TransferSummary(
                    network: widget.network.name,
                    receiver: widget.receiverPhone,
                    airtimeAmount: _money(widget.airtimeAmount),
                    cashAmount: _money(widget.cashAmount),
                    payout:
                        widget.payoutDestination == _PayoutDestination.wallet
                        ? 'FavouriteSub wallet'
                        : '${widget.bankName} • ${widget.accountNumber}',
                    onCopy: () =>
                        _copy(widget.receiverPhone, 'Receiving number'),
                  ),
                  const SizedBox(height: 16),
                  _CountdownCard(value: _countdown, expired: expired),
                  const SizedBox(height: 24),
                  Text(
                    guide.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...guide.steps.indexed.map(
                    (entry) =>
                        _InstructionStep(number: entry.$1 + 1, text: entry.$2),
                  ),
                  if (guide.transferCode != null) ...[
                    const SizedBox(height: 8),
                    _CodeCard(
                      code: guide.transferCode!,
                      onCopy: () => _copy(guide.transferCode!, 'Transfer code'),
                    ),
                  ],
                  const SizedBox(height: 22),
                  _NoticeCard(
                    icon: Icons.info_outline_rounded,
                    color: const Color(0xFFB96B00),
                    text:
                        'Ensure you have sent exactly ${_money(widget.airtimeAmount)} '
                        'to ${widget.receiverPhone} before tapping “Confirm airtime sent”. '
                        'You must complete the transfer within 30 minutes.',
                  ),
                  const SizedBox(height: 10),
                  const _NoticeCard(
                    icon: Icons.schedule_rounded,
                    color: Color(0xFF176B4D),
                    text:
                        'Confirmation is instant. Payment is automated and is usually completed within 5–30 minutes.',
                  ),
                  const SizedBox(height: 10),
                  const _NoticeCard(
                    icon: Icons.sim_card_alert_outlined,
                    color: Color(0xFF9D2525),
                    text:
                        'Send from your personal SIM. Confirming without sending airtime may lead to restrictions on your account.',
                  ),
                  const SizedBox(height: 26),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: expired || _submitting
                          ? null
                          : _showFinalConfirmation,
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_outline_rounded),
                      label: Text(
                        _submitting
                            ? 'Submitting request…'
                            : expired
                            ? 'Transfer window expired'
                            : 'Confirm airtime sent',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(expired ? 'Start again' : 'Cancel'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TransferGuide {
  const _TransferGuide({
    required this.title,
    required this.steps,
    this.transferCode,
  });

  final String title;
  final List<String> steps;
  final String? transferCode;

  factory _TransferGuide.forNetwork(
    String network, {
    required String receiver,
    required String amount,
  }) {
    switch (network.trim().toUpperCase()) {
      case 'MTN':
        return _TransferGuide(
          title: 'How to transfer MTN airtime',
          steps: [
            'Dial *321# on your personal MTN line.',
            'Choose Airtime Transfer (Share ’N’ Sell).',
            'Enter $receiver as the recipient number.',
            'Enter ₦$amount and confirm with your transfer PIN.',
          ],
          transferCode: '*321*$receiver*$amount*PIN#',
        );
      case 'GLO':
        return _TransferGuide(
          title: 'How to transfer Glo airtime',
          steps: [
            'If you still use the default PIN, change it first with *132*00000*NewPIN*NewPIN#.',
            'Use $receiver as the recipient number.',
            'Enter exactly ₦$amount and confirm with your Glo transfer PIN.',
          ],
          transferCode: '*131*$receiver*$amount*PIN#',
        );
      case 'AIRTEL':
        return _TransferGuide(
          title: 'How to transfer Airtel airtime',
          steps: [
            'Dial *321# on your personal Airtel line.',
            'Choose Airtime Transfer or Me2U.',
            'Enter $receiver as the recipient number.',
            'Enter exactly ₦$amount and confirm with your transfer PIN.',
          ],
        );
      default:
        return _TransferGuide(
          title: 'How to transfer 9mobile airtime',
          steps: [
            'Dial *223# on your personal 9mobile line and choose airtime transfer.',
            'Enter $receiver as the recipient number.',
            'Enter exactly ₦$amount and confirm with your transfer PIN.',
          ],
        );
    }
  }
}

class _AirtimeRequestSubmittedScreen extends StatelessWidget {
  const _AirtimeRequestSubmittedScreen({
    required this.result,
    required this.networkName,
    required this.senderPhone,
    required this.receiverPhone,
    required this.airtimeAmount,
    required this.cashAmount,
    required this.payoutLabel,
  });

  final Map<String, dynamic> result;
  final String networkName;
  final String senderPhone;
  final String receiverPhone;
  final double airtimeAmount;
  final double cashAmount;
  final String payoutLabel;

  String _money(num value) => NumberFormat.currency(
    locale: 'en_NG',
    symbol: '₦',
    decimalDigits: value % 1 == 0 ? 0 : 2,
  ).format(value);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reference = (result['ident'] ?? result['id'] ?? '').toString();
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Request received'),
          centerTitle: true,
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  children: [
                    Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        color: const Color(0xFF16845B).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 44,
                        color: Color(0xFF16845B),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Airtime confirmation received',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'We’ll verify the transfer and process your payment, usually within 5–30 minutes.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 26),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest.withValues(
                          alpha: 0.45,
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        children: [
                          if (reference.isNotEmpty)
                            _ResultRow('Reference', reference),
                          _ResultRow('Network', networkName),
                          _ResultRow('Sending SIM', senderPhone),
                          _ResultRow('Sent to', receiverPhone),
                          _ResultRow('Airtime sent', _money(airtimeAmount)),
                          _ResultRow('Expected payment', _money(cashAmount)),
                          _ResultRow('Payment destination', payoutLabel),
                          const _ResultRow('Status', 'Processing', last: true),
                        ],
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Done',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow(this.label, this.value, {this.last = false});
  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: last ? 0 : 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.colors});
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: colors.primary.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: colors.primary.withValues(alpha: 0.13)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: colors.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.currency_exchange_rounded, color: colors.onPrimary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Convert airtime to cash',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 5),
              Text(
                'Enter the SIM you’ll send from and see exactly how much you’ll receive before continuing.',
                style: TextStyle(color: colors.onSurfaceVariant, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({required this.hasError, required this.onRetry});
  final bool hasError;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: hasError
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Could not load airtime-to-cash details.'),
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          )
        : const CircularProgressIndicator(),
  );
}

class _UnavailableCard extends StatelessWidget {
  const _UnavailableCard({required this.colors});
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: colors.errorContainer,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      'Airtime to cash is currently unavailable. Please check again later.',
      style: TextStyle(
        color: colors.onErrorContainer,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _NetworkOption extends StatelessWidget {
  const _NetworkOption({
    required this.network,
    required this.selected,
    required this.onTap,
  });
  final NetworkDef network;
  final bool selected;
  final VoidCallback onTap;

  String get _asset {
    switch (network.name.trim().toUpperCase()) {
      case 'MTN':
        return 'assets/images/mtn_logo.png';
      case 'GLO':
        return 'assets/images/glo_logo.png';
      case 'AIRTEL':
        return 'assets/images/airtel_logo.png';
      default:
        return 'assets/images/9mobile_logo.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? colors.primary.withValues(alpha: 0.09)
          : colors.surfaceContainerHighest.withValues(alpha: 0.42),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 112,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? colors.primary : colors.outlineVariant,
              width: selected ? 1.8 : 1,
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  _asset,
                  width: 38,
                  height: 38,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  network.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({
    required this.rate,
    required this.airtimeAmount,
    required this.cashAmount,
    required this.money,
  });
  final double rate;
  final double airtimeAmount;
  final double cashAmount;
  final String Function(num) money;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16845B).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF16845B).withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        children: [
          _QuoteRow('Airtime you’ll send', money(airtimeAmount)),
          const SizedBox(height: 10),
          _QuoteRow(
            'Conversion rate',
            '${rate.toStringAsFixed(rate % 1 == 0 ? 0 : 2)}%',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: colors.outlineVariant),
          ),
          _QuoteRow('You’ll receive', money(cashAmount), emphasized: true),
        ],
      ),
    );
  }
}

class _QuoteRow extends StatelessWidget {
  const _QuoteRow(this.label, this.value, {this.emphasized = false});
  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            color: emphasized
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: emphasized ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ),
      Text(
        value,
        style: TextStyle(
          fontSize: emphasized ? 19 : 15,
          fontWeight: FontWeight.w900,
          color: emphasized ? const Color(0xFF16845B) : null,
        ),
      ),
    ],
  );
}

class _PayoutOptions extends StatelessWidget {
  const _PayoutOptions({
    required this.value,
    required this.user,
    required this.bankAvailable,
    required this.onChanged,
  });
  final _PayoutDestination value;
  final UserData user;
  final bool bankAvailable;
  final ValueChanged<_PayoutDestination> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _PayoutTile(
        selected: value == _PayoutDestination.wallet,
        icon: Icons.account_balance_wallet_outlined,
        title: 'FavouriteSub wallet',
        subtitle: 'Receive payment in your app wallet',
        onTap: () => onChanged(_PayoutDestination.wallet),
      ),
      const SizedBox(height: 10),
      _PayoutTile(
        selected: value == _PayoutDestination.bank,
        enabled: bankAvailable,
        icon: Icons.account_balance_outlined,
        title: 'Bank account',
        subtitle: bankAvailable
            ? '${user.bankName} • ${user.accountNumber}'
            : 'Add complete bank details on your account to enable this',
        onTap: () => onChanged(_PayoutDestination.bank),
      ),
    ],
  );
}

class _PayoutTile extends StatelessWidget {
  const _PayoutTile({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });
  final bool selected;
  final bool enabled;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: selected
            ? colors.primary.withValues(alpha: 0.07)
            : colors.surfaceContainerHighest.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: selected ? colors.primary : colors.outlineVariant,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: selected ? colors.primary : colors.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: selected ? colors.primary : colors.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TransferSummary extends StatelessWidget {
  const _TransferSummary({
    required this.network,
    required this.receiver,
    required this.airtimeAmount,
    required this.cashAmount,
    required this.payout,
    required this.onCopy,
  });
  final String network;
  final String receiver;
  final String airtimeAmount;
  final String cashAmount;
  final String payout;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primary, colors.primary.withValues(alpha: 0.82)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SEND $network AIRTIME',
            style: TextStyle(
              color: colors.onPrimary.withValues(alpha: 0.75),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: Text(
                  receiver,
                  style: TextStyle(
                    color: colors.onPrimary,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              IconButton.filledTonal(
                onPressed: onCopy,
                tooltip: 'Copy receiving number',
                icon: const Icon(Icons.copy_rounded, size: 19),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: colors.onPrimary.withValues(alpha: 0.24)),
          const SizedBox(height: 8),
          _SummaryLine('Exact airtime amount', airtimeAmount, colors),
          const SizedBox(height: 8),
          _SummaryLine('You’ll receive', cashAmount, colors),
          const SizedBox(height: 8),
          _SummaryLine('Paid to', payout, colors),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine(this.label, this.value, this.colors);
  final String label;
  final String value;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(color: colors.onPrimary.withValues(alpha: 0.72)),
        ),
      ),
      const SizedBox(width: 14),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.right,
          style: TextStyle(
            color: colors.onPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ],
  );
}

class _CountdownCard extends StatelessWidget {
  const _CountdownCard({required this.value, required this.expired});
  final String value;
  final bool expired;

  @override
  Widget build(BuildContext context) {
    final color = expired
        ? Theme.of(context).colorScheme.error
        : const Color(0xFFB96B00);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              expired ? 'Transfer window expired' : 'Complete transfer within',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _InstructionStep extends StatelessWidget {
  const _InstructionStep({required this.number, required this.text});
  final int number;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 13),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 27,
          height: 27,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Text(
            '$number',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(text, style: const TextStyle(height: 1.4)),
          ),
        ),
      ],
    ),
  );
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.code, required this.onCopy});
  final String code;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(15, 10, 8, 10),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              code,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 0.25,
              ),
            ),
          ),
          IconButton(
            onPressed: onCopy,
            tooltip: 'Copy transfer code',
            icon: const Icon(Icons.copy_rounded),
          ),
        ],
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.icon,
    required this.color,
    required this.text,
  });
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withValues(alpha: 0.16)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 21),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.4,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
  );
}

InputDecoration _fieldDecoration(
  BuildContext context, {
  required String hint,
  required IconData icon,
  String? prefixText,
}) {
  final colors = Theme.of(context).colorScheme;
  return InputDecoration(
    filled: true,
    fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.35),
    hintText: hint,
    prefixIcon: Icon(icon),
    prefixText: prefixText,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: colors.primary, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  );
}
