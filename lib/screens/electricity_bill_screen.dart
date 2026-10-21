import 'dart:async';

import 'package:favouritesub/providers/app_data_provider.dart';
import 'package:favouritesub/providers/settings_provider.dart';
import 'package:favouritesub/providers/transaction_provider.dart';
import 'package:favouritesub/providers/user_provider.dart';
import 'package:favouritesub/screens/fund_wallet_screen.dart';
import 'package:favouritesub/services/biometric_service.dart';
import 'package:favouritesub/services/electricity_service.dart';
import 'package:favouritesub/services/wallet_service.dart';
import 'package:favouritesub/utils/utils.dart';
import 'package:favouritesub/widgets/pin_auth_sheet.dart';
import 'package:favouritesub/widgets/primary_result_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class ElectricityBillScreen extends StatefulWidget {
  const ElectricityBillScreen({super.key});

  @override
  State<ElectricityBillScreen> createState() => _ElectricityBillScreenState();
}

class _ElectricityBillScreenState extends State<ElectricityBillScreen> {
  static const _presets = [500, 1000, 2000, 3000, 5000, 10000];

  final _meterController = TextEditingController();
  final _phoneController = TextEditingController();
  final _amountController = TextEditingController();

  Map<String, dynamic>? _selectedDisco;
  String? _selectedMeterType;
  int? _selectedPresetIndex;
  String? _inlineMeterError;
  bool _isBusy = false;
  bool _didLoadAppData = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoadAppData) return;
    _didLoadAppData = true;
    unawaited(context.read<AppDataProvider>().load());
  }

  @override
  void dispose() {
    _meterController.dispose();
    _phoneController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _getDiscos(AppDataProvider appData) {
    final data = appData.data;
    if (data == null) return const [];
    return data.disco.map((disco) {
      return <String, dynamic>{'id': disco.id, 'name': disco.name};
    }).toList();
  }

  bool get _canValidate {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    return _selectedDisco != null &&
        _meterController.text.trim().isNotEmpty &&
        _selectedMeterType != null &&
        _phoneController.text.trim().length == 11 &&
        amount > 0 &&
        !_isBusy;
  }

  String _money(String raw) {
    final amount = double.tryParse(raw.replaceAll(',', '')) ?? 0;
    final whole = amount == amount.roundToDouble();
    final value = amount
        .toStringAsFixed(whole ? 0 : 2)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
        );
    return '₦$value';
  }

  void _openDiscoSheet(List<Map<String, dynamic>> discos) {
    if (discos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Electricity providers are still loading'),
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        var query = '';
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final colors = Theme.of(context).colorScheme;
            final filtered = discos.where((disco) {
              final name = (disco['name'] ?? '').toString().toLowerCase();
              return query.isEmpty || name.contains(query.toLowerCase());
            }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.68,
              minChildSize: 0.42,
              maxChildSize: 0.94,
              expand: false,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: colors.outlineVariant,
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Select electricity provider',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Choose the distribution company for your meter.',
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        autofocus: false,
                        textInputAction: TextInputAction.search,
                        onChanged: (value) {
                          setSheetState(() => query = value.trim());
                        },
                        decoration: InputDecoration(
                          hintText: 'Search providers',
                          prefixIcon: const Icon(Icons.search_rounded),
                          filled: true,
                          fillColor: colors.surfaceContainerHighest.withValues(
                            alpha: 0.55,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: filtered.isEmpty
                            ? Center(
                                child: Text(
                                  'No provider matches your search',
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                controller: scrollController,
                                padding: const EdgeInsets.only(bottom: 20),
                                itemCount: filtered.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 5),
                                itemBuilder: (context, index) {
                                  final disco = filtered[index];
                                  final name = (disco['name'] ?? '').toString();
                                  final selected =
                                      _selectedDisco?['id'] == disco['id'];
                                  return Material(
                                    color: selected
                                        ? colors.primary.withValues(alpha: 0.08)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(14),
                                    child: ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 3,
                                          ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      leading: _ProviderLogo(name: name),
                                      title: Text(
                                        name,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      trailing: selected
                                          ? Icon(
                                              Icons.check_circle_rounded,
                                              color: colors.primary,
                                            )
                                          : const Icon(
                                              Icons.chevron_right_rounded,
                                            ),
                                      onTap: () {
                                        setState(() {
                                          _selectedDisco = disco;
                                          _inlineMeterError = null;
                                        });
                                        Navigator.pop(sheetContext);
                                      },
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _selectMeterType(String type) {
    setState(() {
      _selectedMeterType = type;
      _inlineMeterError = null;
    });
  }

  void _selectPreset(int index) {
    setState(() {
      _selectedPresetIndex = index;
      _amountController.text = _presets[index].toString();
    });
    HapticFeedback.selectionClick();
  }

  Future<void> _onNext() async {
    if (!_canValidate) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isBusy = true;
      _inlineMeterError = null;
    });

    final discoName = (_selectedDisco?['name'] ?? '').toString();
    final meterType = _selectedMeterType ?? '';
    final meterNumber = _meterController.text.trim();

    try {
      final response = await ElectricityService.validateMeterNumber(
        meterNumber: meterNumber,
        discoName: discoName,
        meterType: meterType,
      );
      if (!mounted) return;

      if (response['invalid'] == true) {
        setState(() {
          _inlineMeterError = (response['name'] ?? 'Invalid meter number')
              .toString();
        });
        return;
      }

      final customerName = (response['name'] ?? 'Customer').toString();
      final customerAddress = (response['address'] ?? '').toString();
      await _showConfirmation(
        customerName: customerName,
        customerAddress: customerAddress,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _inlineMeterError = _friendlyError(
          error,
          fallback: 'Could not validate this meter. Please try again.',
        );
      });
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _showConfirmation({
    required String customerName,
    required String customerAddress,
  }) async {
    final discoName = (_selectedDisco?['name'] ?? '').toString();
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText) ?? 0;
    final balance = WalletService.getWalletBalance(context);
    final hasEnough = WalletService.hasSufficientBalance(
      balance: balance,
      amount: amount,
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _ElectricityConfirmationSheet(
          discoName: discoName,
          meterNumber: _meterController.text.trim(),
          meterType: _selectedMeterType ?? '',
          customerName: customerName,
          customerAddress: customerAddress,
          amount: _money(amountText),
          hasEnoughBalance: hasEnough,
          onFundWallet: () {
            Navigator.pop(sheetContext);
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const FundWalletScreen()));
          },
          onConfirm: hasEnough
              ? () {
                  Navigator.pop(sheetContext);
                  _authorizeAndPurchase(
                    customerName: customerName,
                    customerAddress: customerAddress,
                  );
                }
              : null,
        );
      },
    );
  }

  Future<void> _authorizeAndPurchase({
    required String customerName,
    required String customerAddress,
  }) async {
    if (!mounted) return;
    final requireBiometric = context
        .read<SettingsProvider>()
        .biometricPayEnabled;
    final result = await showPinAuthSheet(
      context,
      allowBiometric: requireBiometric,
      biometricAuth: () => BiometricService.authenticate(
        context,
        reason: 'Confirm electricity payment',
      ),
    );
    if (!mounted || result == null || !result.success) return;

    await _performPurchase(
      customerName: customerName,
      customerAddress: customerAddress,
    );
  }

  Future<void> _performPurchase({
    required String customerName,
    required String customerAddress,
  }) async {
    final discoName = (_selectedDisco?['name'] ?? '').toString();
    final rawDiscoId = _selectedDisco?['id'];
    final discoId = rawDiscoId is int
        ? rawDiscoId
        : int.tryParse(rawDiscoId.toString()) ?? 0;
    final meterNumber = _meterController.text.trim();
    final meterType = _selectedMeterType ?? '';
    final amount = _amountController.text.trim();
    final phone = _phoneController.text.trim();

    setState(() => _isBusy = true);
    try {
      final response = await ElectricityService.purchaseElectricity(
        discoName: discoId,
        meterNumber: meterNumber,
        meterType: meterType,
        amount: amount,
        customerPhone: phone,
        customerName: customerName,
        customerAddress: customerAddress,
      );
      if (!mounted) return;

      final status = (response['Status'] ?? response['status'] ?? '')
          .toString()
          .toLowerCase();
      final successful = status.contains('success');
      final processing =
          status.contains('process') || status.contains('pending');
      final token = _cleanToken((response['token'] ?? '').toString());
      final message = _friendlyError(
        response['message'] ??
            response['api_response'] ??
            response['error'] ??
            '',
        fallback: successful
            ? 'Your electricity payment was completed successfully.'
            : processing
            ? 'Your electricity payment is being processed.'
            : 'The electricity payment could not be completed.',
      );

      if (successful || processing) {
        _resetForm();
        unawaited(_refreshAfterPurchase());
      }

      final color = successful
          ? const Color(0xFF16835B)
          : processing
          ? const Color(0xFFB66A05)
          : Theme.of(context).colorScheme.error;
      final icon = successful
          ? Icons.check_circle_outline_rounded
          : processing
          ? Icons.schedule_rounded
          : Icons.error_outline_rounded;
      final title = successful
          ? 'Electricity payment successful'
          : processing
          ? 'Payment processing'
          : 'Payment unsuccessful';

      await showPrimaryResultSheet(
        context,
        title: title,
        message: message,
        color: color,
        icon: icon,
        details: [
          DetailEntry('Provider', discoName),
          DetailEntry('Meter number', meterNumber),
          DetailEntry('Meter type', meterType),
          DetailEntry('Customer', customerName),
          DetailEntry('Amount', _money(amount)),
        ],
        copySectionLabel: token.isEmpty ? null : 'Electricity token',
        copyText: token.isEmpty ? null : token,
        primaryButtonLabel: 'Done',
      );
    } catch (error) {
      if (!mounted) return;
      await showPrimaryResultSheet(
        context,
        title: 'Payment unsuccessful',
        message: _friendlyError(
          error,
          fallback: 'The electricity payment could not be completed.',
        ),
        color: Theme.of(context).colorScheme.error,
        icon: Icons.error_outline_rounded,
        primaryButtonLabel: 'Try again',
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _refreshAfterPurchase() async {
    await Future.wait([
      context.read<UserProvider>().loadUserData(),
      context.read<TransactionProvider>().refresh(),
      context.read<AppDataProvider>().silentRefresh(force: true),
    ]);
  }

  void _resetForm() {
    setState(() {
      _selectedDisco = null;
      _selectedMeterType = null;
      _selectedPresetIndex = null;
      _inlineMeterError = null;
      _meterController.clear();
      _phoneController.clear();
      _amountController.clear();
    });
  }

  String _cleanToken(String token) {
    final value = token.trim();
    if (value.toLowerCase().startsWith('token:')) {
      return value.substring(6).trim();
    }
    return value;
  }

  String _friendlyError(Object? error, {required String fallback}) {
    if (error == null) return fallback;
    var message = error.toString().trim();
    message = message.replaceFirst(
      RegExp(r'^Exception:\s*', caseSensitive: false),
      '',
    );
    final lower = message.toLowerCase();
    if (lower.contains('failed host lookup') ||
        lower.contains('socketexception') ||
        lower.contains('network is unreachable') ||
        lower.contains('connection refused')) {
      return 'No internet connection. Check your network and try again.';
    }
    if (lower.contains('timeout')) {
      return 'The request took too long. Please try again.';
    }
    if (message.isEmpty ||
        message.length > 220 ||
        message.contains('package:')) {
      return fallback;
    }
    return message;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final appData = context.watch<AppDataProvider>();
    final discos = _getDiscos(appData);
    final amountText = _amountController.text.trim();

    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _isBusy ? null : () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Electricity',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.25,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _NextButton(
              active: _canValidate,
              busy: _isBusy,
              onTap: _onNext,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          IgnorePointer(
            ignoring: _isBusy,
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _WalletBar(),
                        const SizedBox(height: 26),
                        const _FieldLabel('Select electricity provider'),
                        const SizedBox(height: 8),
                        _DropField(
                          value: _selectedDisco == null
                              ? null
                              : (_selectedDisco!['name'] ?? '').toString(),
                          hint: appData.isLoading && discos.isEmpty
                              ? 'Loading providers...'
                              : 'Select provider',
                          loading: appData.isLoading && discos.isEmpty,
                          onTap: () => _openDiscoSheet(discos),
                        ),
                        const SizedBox(height: 24),
                        const _FieldLabel('Meter number'),
                        const SizedBox(height: 8),
                        _InputField(
                          controller: _meterController,
                          hint: 'Enter meter number',
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (_) {
                            setState(() => _inlineMeterError = null);
                          },
                        ),
                        if (_inlineMeterError != null) ...[
                          const SizedBox(height: 7),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                size: 16,
                                color: colors.error,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _inlineMeterError!,
                                  style: TextStyle(
                                    color: colors.error,
                                    fontSize: 12,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 24),
                        const _FieldLabel('Meter type'),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            for (final type in const ['Prepaid', 'Postpaid'])
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    right: type == 'Prepaid' ? 6 : 0,
                                    left: type == 'Postpaid' ? 6 : 0,
                                  ),
                                  child: _ChoiceChip(
                                    label: type,
                                    selected: _selectedMeterType == type,
                                    onTap: () => _selectMeterType(type),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const _FieldLabel('Customer phone number'),
                        const SizedBox(height: 8),
                        _InputField(
                          controller: _phoneController,
                          hint: 'Enter 11-digit phone number',
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(11),
                          ],
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 24),
                        const _FieldLabel('Choose an amount'),
                        const SizedBox(height: 10),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = constraints.maxWidth >= 600 ? 6 : 3;
                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _presets.length,
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columns,
                                    mainAxisSpacing: 10,
                                    crossAxisSpacing: 10,
                                    mainAxisExtent: 48,
                                  ),
                              itemBuilder: (context, index) {
                                return _ChoiceChip(
                                  label: _money(_presets[index].toString()),
                                  selected: _selectedPresetIndex == index,
                                  onTap: () => _selectPreset(index),
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            const _FieldLabel('Amount'),
                            const Spacer(),
                            if (amountText.isNotEmpty)
                              Text(
                                _money(amountText),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _InputField(
                          controller: _amountController,
                          hint: 'Enter amount',
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          prefixText: '₦ ',
                          onChanged: (_) {
                            setState(() => _selectedPresetIndex = null);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_isBusy)
            Positioned.fill(
              child: ColoredBox(
                color: colors.surface.withValues(alpha: 0.82),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: CircularProgressIndicator(color: colors.primary),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WalletBar extends StatelessWidget {
  const _WalletBar();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              Icons.account_balance_wallet_outlined,
              size: 18,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Wallet balance',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Consumer<UserProvider>(
            builder: (context, user, _) {
              return Flexible(
                child: Text(
                  user.balance,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: colors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _NextButton extends StatelessWidget {
  const _NextButton({
    required this.active,
    required this.busy,
    required this.onTap,
  });

  final bool active;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: active
          ? colors.onPrimary
          : colors.onPrimary.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: active && !busy ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
          child: Text(
            busy ? 'Please wait' : 'Next',
            style: TextStyle(
              color: active
                  ? colors.primary
                  : colors.onPrimary.withValues(alpha: 0.55),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
      ),
    );
  }
}

class _DropField extends StatelessWidget {
  const _DropField({
    required this.value,
    required this.hint,
    required this.loading,
    required this.onTap,
  });

  final String? value;
  final String hint;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHighest.withValues(alpha: 0.42),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value ?? hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: value == null
                        ? colors.onSurfaceVariant.withValues(alpha: 0.65)
                        : colors.onSurface,
                    fontSize: 14,
                    fontWeight: value == null
                        ? FontWeight.w500
                        : FontWeight.w700,
                  ),
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: colors.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.hint,
    required this.keyboardType,
    required this.inputFormatters,
    required this.onChanged,
    this.prefixText,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final List<TextInputFormatter> inputFormatters;
  final ValueChanged<String> onChanged;
  final String? prefixText;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        prefixText: prefixText,
        hintStyle: TextStyle(
          color: colors.onSurfaceVariant.withValues(alpha: 0.58),
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.42),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 16,
        ),
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
          borderSide: BorderSide(color: colors.primary, width: 1.4),
        ),
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected
            ? colors.primary
            : colors.surfaceContainerHighest.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? colors.onPrimary : colors.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProviderLogo extends StatelessWidget {
  const _ProviderLogo({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 42,
      height: 42,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Image.asset(
        Utils.getAssetForElectricity(name),
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) =>
            Icon(Icons.bolt_rounded, color: colors.primary, size: 22),
      ),
    );
  }
}

class _ElectricityConfirmationSheet extends StatelessWidget {
  const _ElectricityConfirmationSheet({
    required this.discoName,
    required this.meterNumber,
    required this.meterType,
    required this.customerName,
    required this.customerAddress,
    required this.amount,
    required this.hasEnoughBalance,
    required this.onFundWallet,
    required this.onConfirm,
  });

  final String discoName;
  final String meterNumber;
  final String meterType;
  final String customerName;
  final String customerAddress;
  final String amount;
  final bool hasEnoughBalance;
  final VoidCallback onFundWallet;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              const SizedBox(height: 20),
              _ProviderLogo(name: discoName),
              const SizedBox(height: 12),
              const Text(
                'Confirm electricity payment',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Check these details before you continue.',
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: 0.44),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    _ConfirmationRow(label: 'Provider', value: discoName),
                    _ConfirmationRow(label: 'Meter number', value: meterNumber),
                    _ConfirmationRow(label: 'Meter type', value: meterType),
                    _ConfirmationRow(label: 'Customer', value: customerName),
                    if (customerAddress.isNotEmpty)
                      _ConfirmationRow(
                        label: 'Address',
                        value: customerAddress,
                      ),
                    _ConfirmationRow(
                      label: 'Amount',
                      value: amount,
                      prominent: true,
                      showDivider: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: hasEnoughBalance
                      ? colors.primary.withValues(alpha: 0.07)
                      : colors.error.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      hasEnoughBalance
                          ? Icons.verified_outlined
                          : Icons.info_outline_rounded,
                      color: hasEnoughBalance ? colors.primary : colors.error,
                      size: 20,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        hasEnoughBalance
                            ? 'Your wallet can cover this payment.'
                            : 'Your wallet balance is insufficient.',
                        style: TextStyle(
                          color: hasEnoughBalance
                              ? colors.primary
                              : colors.error,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (!hasEnoughBalance)
                      TextButton(
                        onPressed: onFundWallet,
                        child: const Text('Fund wallet'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onConfirm,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text(
                    'Confirm and pay',
                    style: TextStyle(fontWeight: FontWeight.w800),
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

class _ConfirmationRow extends StatelessWidget {
  const _ConfirmationRow({
    required this.label,
    required this.value,
    this.prominent = false,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final bool prominent;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: prominent ? 15 : 12,
                    fontWeight: prominent ? FontWeight.w800 : FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            color: colors.outlineVariant.withValues(alpha: 0.5),
          ),
      ],
    );
  }
}
