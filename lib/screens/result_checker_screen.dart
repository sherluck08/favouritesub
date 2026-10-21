import 'package:favouritesub/providers/app_data_provider.dart';
import 'package:favouritesub/providers/settings_provider.dart';
import 'package:favouritesub/providers/user_provider.dart';
import 'package:favouritesub/services/biometric_service.dart';
import 'package:favouritesub/services/result_checker_service.dart';
import 'package:favouritesub/services/transaction_notifier.dart';
import 'package:favouritesub/services/wallet_service.dart';
import 'package:favouritesub/utils/friendly_error.dart';
import 'package:favouritesub/utils/utils.dart';
import 'package:favouritesub/widgets/pin_auth_sheet.dart';
import 'package:favouritesub/widgets/primary_result_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'fund_wallet_screen.dart';

class ResultCheckerScreen extends StatefulWidget {
  const ResultCheckerScreen({super.key});

  @override
  State<ResultCheckerScreen> createState() => _ResultCheckerScreenState();
}

class _ResultCheckerScreenState extends State<ResultCheckerScreen> {
  final _quantityController = TextEditingController();
  String? _selectedExam;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AppDataProvider>().load();
    });
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  List<_ExamOption> _uniqueExams(AppDataProvider appData) {
    final available = appData.data?.exam ?? const [];
    final seen = <String>{};
    final exams = <_ExamOption>[];
    for (final exam in available) {
      final name = exam.examName.trim();
      if (name.isEmpty || !seen.add(name.toUpperCase())) continue;
      exams.add(
        _ExamOption(
          name: name,
          amount: exam.amount,
          asset: Utils.getAssetForExam(name),
        ),
      );
    }
    return exams;
  }

  double _priceFor(String examName) {
    final available = context.read<AppDataProvider>().data?.exam ?? const [];
    final matches = available.where(
      (exam) => exam.examName.toLowerCase() == examName.toLowerCase(),
    );
    return matches.isEmpty ? 0 : matches.first.amount;
  }

  int get _quantity => int.tryParse(_quantityController.text.trim()) ?? 0;

  double get _totalAmount =>
      _selectedExam == null ? 0 : _priceFor(_selectedExam!) * _quantity;

  bool get _canProceed => _selectedExam != null && _quantity > 0 && !_isBusy;

  void _showSummarySheet() {
    if (!_canProceed) return;
    final colors = Theme.of(context).colorScheme;
    final amount = _totalAmount;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: colors.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Confirm purchase',
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Review the details before paying from your wallet.',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    _detailRow('Exam', _selectedExam!, colors),
                    const SizedBox(height: 13),
                    _detailRow('Quantity', '$_quantity', colors),
                    const SizedBox(height: 13),
                    _detailRow(
                      'Total amount',
                      '₦${amount.toStringAsFixed(2)}',
                      colors,
                      emphasized: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: colors.primary.withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_rounded,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Wallet balance',
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                          Consumer<UserProvider>(
                            builder: (_, user, __) => Text(
                              user.balance,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const FundWalletScreen(),
                          ),
                        );
                      },
                      child: const Text('Fund wallet'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Builder(
                builder: (buttonContext) {
                  final balance = WalletService.getWalletBalance(buttonContext);
                  final hasEnough = WalletService.hasSufficientBalance(
                    balance: balance,
                    amount: amount,
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!hasEnough)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            'Your wallet balance is not enough for this purchase.',
                            style: TextStyle(color: colors.error, fontSize: 13),
                          ),
                        ),
                      FilledButton(
                        onPressed: hasEnough
                            ? () async {
                                final requireBiometric = sheetContext
                                    .read<SettingsProvider>()
                                    .biometricPayEnabled;
                                final auth = await showPinAuthSheet(
                                  sheetContext,
                                  allowBiometric: requireBiometric,
                                  biometricAuth: () =>
                                      BiometricService.authenticate(
                                        sheetContext,
                                        reason: 'Confirm payment',
                                      ),
                                );
                                if (auth == null || !auth.success) return;
                                if (sheetContext.mounted) {
                                  Navigator.pop(sheetContext);
                                }
                                await _performPurchase();
                              }
                            : null,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Buy exam PIN',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(
    String label,
    String value,
    ColorScheme colors, {
    bool emphasized = false,
  }) => Row(
    children: [
      Text(label, style: TextStyle(color: colors.onSurfaceVariant)),
      const Spacer(),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontWeight: emphasized ? FontWeight.w900 : FontWeight.w700,
            color: emphasized ? colors.primary : colors.onSurface,
          ),
        ),
      ),
    ],
  );

  Future<void> _performPurchase() async {
    setState(() => _isBusy = true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final transaction = TxInfo(
      kind: TxKind.examPin,
      amount: '₦${_totalAmount.toStringAsFixed(0)}',
      plan: '${_selectedExam ?? ''} x$_quantity',
    );

    Map<String, dynamic> response;
    try {
      response = await ResultCheckerService.purchasePins(
        examName: _selectedExam!,
        quantity: _quantity,
      );
    } catch (error) {
      if (!mounted) return;
      Navigator.pop(context);
      setState(() => _isBusy = false);
      final message = FriendlyError.from(
        error,
        fallback: 'Unable to generate exam PINs right now.',
      );
      TransactionNotifier.notify(
        info: transaction,
        outcome: TxOutcome.failed,
        rawError: error.toString(),
      );
      await showPrimaryResultSheet(
        context,
        color: Colors.red,
        icon: Icons.error,
        title: 'Generation failed',
        message: message,
        details: _resultDetails(),
        primaryButtonLabel: 'Close',
        onPrimaryPressed: () {},
      );
      return;
    }

    if (!mounted) return;
    Navigator.pop(context);
    setState(() => _isBusy = false);

    final status = (response['status'] ?? '').toString().toLowerCase();
    final isSuccess = status.contains('success');
    final isProcessing = !isSuccess && status.contains('process');
    final rawError =
        (response['message']?['error']?.first?.toString() ??
                response['api_response']?.toString() ??
                'Unable to generate exam PINs')
            .trim();

    TransactionNotifier.notify(
      info: transaction,
      outcome: isSuccess
          ? TxOutcome.success
          : isProcessing
          ? TxOutcome.processing
          : TxOutcome.failed,
      rawError: isSuccess ? null : rawError,
    );

    await showPrimaryResultSheet(
      context,
      color: isSuccess
          ? Colors.green
          : isProcessing
          ? Colors.orange
          : Colors.red,
      icon: isSuccess
          ? Icons.check_circle
          : isProcessing
          ? Icons.schedule
          : Icons.error,
      title: isSuccess
          ? 'PINs generated successfully'
          : isProcessing
          ? 'Purchase processing'
          : 'Generation failed',
      message: isSuccess
          ? null
          : FriendlyError.sanitize(
              rawError,
              fallback: 'Unable to generate exam PINs right now.',
            ),
      details: _resultDetails(),
      primaryButtonLabel: isSuccess ? 'Done' : 'Close',
      onPrimaryPressed: () {},
    );
  }

  List<DetailEntry> _resultDetails() => [
    DetailEntry('Exam', _selectedExam!),
    DetailEntry('Quantity', '$_quantity'),
    DetailEntry('Amount', '₦${_totalAmount.toStringAsFixed(0)}'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final appData = context.watch<AppDataProvider>();
    final exams = _uniqueExams(appData);
    final showAmount = _selectedExam != null && _quantity > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exam PIN'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _NextButton(
              active: _canProceed,
              onTap: _showSummarySheet,
              colors: colors,
            ),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _WalletBar(colors: colors),
              const SizedBox(height: 28),
              Text(
                'Choose an exam',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 5),
              Text(
                'Select the examination PIN you want to purchase.',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              if (exams.isEmpty)
                _EmptyExamState(colors: colors)
              else
                SizedBox(
                  height: 102,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(right: 4),
                    itemCount: exams.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, index) {
                      final exam = exams[index];
                      return _ExamCard(
                        exam: exam,
                        selected: _selectedExam == exam.name,
                        colors: colors,
                        onTap: () => setState(() {
                          _selectedExam = exam.name;
                        }),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 28),
              _fieldLabel('Quantity', colors),
              const SizedBox(height: 9),
              TextField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Enter number of PINs',
                  prefixIcon: const Icon(Icons.confirmation_number_outlined),
                  suffixText: _quantity == 1 ? 'PIN' : 'PINs',
                  filled: true,
                  fillColor: colors.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: colors.primary, width: 1.5),
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: showAmount
                    ? Padding(
                        key: const ValueKey('amount'),
                        padding: const EdgeInsets.only(top: 24),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: colors.primary.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total amount',
                                    style: TextStyle(
                                      color: colors.onSurfaceVariant,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '₦${_totalAmount.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: colors.primary,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Icon(
                                Icons.receipt_long_rounded,
                                color: colors.primary,
                                size: 30,
                              ),
                            ],
                          ),
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('empty')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String text, ColorScheme colors) => Text(
    text,
    style: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: colors.onSurface,
    ),
  );
}

class _ExamOption {
  final String name;
  final double amount;
  final String asset;

  const _ExamOption({
    required this.name,
    required this.amount,
    required this.asset,
  });
}

class _ExamCard extends StatelessWidget {
  final _ExamOption exam;
  final bool selected;
  final ColorScheme colors;
  final VoidCallback onTap;

  const _ExamCard({
    required this.exam,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: '${exam.name}, ₦${exam.amount.toStringAsFixed(0)}',
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 104,
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 8),
        decoration: BoxDecoration(
          color: selected
              ? colors.primary.withValues(alpha: 0.09)
              : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? colors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(
                    child: Image.asset(
                      exam.asset,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.school_rounded,
                        size: 36,
                        color: colors.primary,
                      ),
                    ),
                  ),
                  if (selected)
                    Positioned(
                      top: -5,
                      right: -5,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: colors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: colors.onPrimary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            Text(
              exam.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? colors.primary : colors.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _EmptyExamState extends StatelessWidget {
  final ColorScheme colors;

  const _EmptyExamState({required this.colors});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: colors.primary,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(child: Text('Loading available exams…')),
      ],
    ),
  );
}

class _WalletBar extends StatelessWidget {
  final ColorScheme colors;

  const _WalletBar({required this.colors});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
    decoration: BoxDecoration(
      color: colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Icon(
          Icons.account_balance_wallet_outlined,
          size: 21,
          color: colors.onSurfaceVariant,
        ),
        const SizedBox(width: 9),
        const Text(
          'Wallet balance',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const Spacer(),
        Consumer<UserProvider>(
          builder: (_, user, __) => Text(
            user.balance,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: colors.primary,
            ),
          ),
        ),
      ],
    ),
  );
}

class _NextButton extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  final ColorScheme colors;

  const _NextButton({
    required this.active,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: active ? onTap : null,
    style: TextButton.styleFrom(
      foregroundColor: colors.primary,
      disabledForegroundColor: colors.onPrimary.withValues(alpha: 0.45),
      backgroundColor: active
          ? colors.onPrimary
          : colors.onPrimary.withValues(alpha: 0.14),
      disabledBackgroundColor: colors.onPrimary.withValues(alpha: 0.14),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
    ),
    child: const Text('Next', style: TextStyle(fontWeight: FontWeight.w800)),
  );
}
