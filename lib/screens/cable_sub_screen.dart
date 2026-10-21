import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:loader_overlay/loader_overlay.dart';

import '../providers/app_data_provider.dart';
import '../widgets/my_textfield.dart';
import '../widgets/cable_card.dart';
import '../models/app_data.dart';
import '../services/cable_service.dart';
import '../widgets/wallet_balance_text.dart';
import 'fund_wallet_screen.dart';
import '../services/wallet_service.dart';
import '../widgets/pin_auth_sheet.dart';
import '../services/biometric_service.dart';
import 'package:favouritesub/providers/settings_provider.dart';

class CableSubScreen extends StatefulWidget {
  const CableSubScreen({super.key});

  @override
  State<CableSubScreen> createState() => _CableSubScreenState();
}

class _CableSubScreenState extends State<CableSubScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _smartCardController = TextEditingController();
  final TextEditingController _planController = TextEditingController();
  final TextEditingController _cableController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  Map<String, dynamic>? _selectedCable;
  Map<String, dynamic>? _selectedPlan;
  String? _inlineError;
  bool _validating = false;

  @override
  void dispose() {
    _smartCardController.dispose();
    _planController.dispose();
    _cableController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    Future.microtask(
      () => Provider.of<AppDataProvider>(context, listen: false).load(),
    );
  }

  List<Map<String, dynamic>> _getCableList(AppDataProvider appData) {
    final data = appData.data;
    if (data == null) return [];
    return data.cable
        .map(
          (c) => {
            'id': c.id,
            'name': c.name,
            'cableplan': c.cableplan
                .map(
                  (p) => {
                    'id': p.id,
                    'package': p.package,
                    'plan_amount': p.planAmount,
                  },
                )
                .toList(),
          },
        )
        .toList();
  }

  List<Map<String, dynamic>> _getPlansForSelected() {
    if (_selectedCable == null) return [];
    final list = _selectedCable!['cableplan'] as List<dynamic>? ?? [];
    return list.whereType<Map<String, dynamic>>().toList();
  }

  void _openPlanBottomSheet() {
    final plans = _getPlansForSelected();
    if (plans.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a cable name first')),
      );
      return;
    }
    final logo = _assetForCable((_selectedCable?['name'] ?? '').toString());
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Plan',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              ...plans.map((p) {
                final name = (p['package'] ?? p['name'] ?? '').toString();
                final price = (p['plan_amount'] ?? p['amount'] ?? 0).toString();
                return Card(
                  elevation: 0,
                  child: ListTile(
                    leading: Image.asset(
                      logo,
                      height: 28,
                      width: 28,
                      fit: BoxFit.contain,
                    ),
                    title: Text(name),
                    trailing: Text(
                      '₦$price',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onTap: () {
                      setState(() {
                        _selectedPlan = p;
                        _planController.text = name;
                        _amountController.text = price;
                      });
                      Navigator.of(context).pop();
                    },
                  ),
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  String _assetForCable(String name) {
    final n = name.toLowerCase();
    if (n.contains('start')) return 'assets/images/startimes_logo.png';
    if (n.contains('go')) return 'assets/images/gotv_logo.png';
    if (n.contains('dst')) return 'assets/images/dstv_logo.png';
    return 'assets/images/startimes_logo.png';
  }

  bool get _canValidate =>
      _selectedCable != null &&
      _selectedPlan != null &&
      _smartCardController.text.trim().isNotEmpty;

  Future<void> _validateIUC() async {
    if (!_canValidate || _validating) return;
    setState(() {
      _inlineError = null;
      _validating = true;
    });
    if (mounted) context.loaderOverlay.show();
    try {
      final res = await CableService.validateIuc(
        smartCardNumber: _smartCardController.text,
        cableName: (_selectedCable?['name'] ?? '').toString(),
      );

      final isInvalid = res['invalid'] == true;
      final name = res['name']?.toString();
      if (isInvalid) {
        setState(() {
          _inlineError = name ?? 'INVALID IUC/SMARTCARD';
        });
      } else {
        _showConfirmationSheet(customer: name ?? 'Customer');
      }
    } catch (e) {
      setState(() {
        _inlineError = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) context.loaderOverlay.hide();
      if (mounted) {
        setState(() {
          _validating = false;
        });
      }
    }
  }

  void _showConfirmationSheet({required String customer}) {
    final cableName = (_selectedCable?['name'] ?? '').toString();
    final planName = (_selectedPlan?['package'] ?? '').toString();
    final amount = _amountController.text.isEmpty
        ? (_selectedPlan?['plan_amount']?.toString() ?? '')
        : _amountController.text;
    final amountDouble = double.tryParse(amount.replaceAll(',', '')) ?? 0.0;
    final logo = _assetForCable(cableName);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Confirm Subscription',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text(
                        'Cable',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.black54,
                        ),
                      ),
                      const Spacer(),
                      Text(cableName),
                      const SizedBox(width: 8),
                      Image.asset(logo, width: 30),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text(
                        'Plan',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.black54,
                        ),
                      ),
                      const Spacer(),
                      Text(planName),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text(
                        'Smart Card/IUC',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.black54,
                        ),
                      ),
                      const Spacer(),
                      Text(_smartCardController.text),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text(
                        'Customer',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.black54,
                        ),
                      ),
                      const Spacer(),
                      Text(customer),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text(
                        'Amount',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.black54,
                        ),
                      ),
                      const Spacer(),
                      Text('₦$amount'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Wallet Balance',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const WalletBalanceText(
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
                      backgroundColor: Colors.purple.shade300,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Fund Wallet',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const SizedBox(height: 4),
            const SizedBox(height: 10),
            Builder(
              builder: (context) {
                final balance = WalletService.getWalletBalance(context);
                final hasEnough = WalletService.hasSufficientBalance(
                  balance: balance,
                  amount: amountDouble,
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!hasEnough)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          'Insufficient balance',
                          style: TextStyle(
                            color: Colors.redAccent.shade200,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    Container(
                      decoration: BoxDecoration(
                        color: hasEnough ? null : Colors.grey,
                        gradient: hasEnough
                            ? const LinearGradient(
                                colors: [Color(0xFF7F00FF), Color(0xFFE100FF)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: hasEnough
                            ? [
                                BoxShadow(
                                  color: Colors.purple.withOpacity(0.4),
                                  offset: const Offset(0, 4),
                                  blurRadius: 10,
                                ),
                              ]
                            : [],
                      ),
                      child: ElevatedButton(
                        onPressed: hasEnough
                            ? () async {
                                final requireBio =
                                    Provider.of<SettingsProvider>(
                                      context,
                                      listen: false,
                                    ).biometricPayEnabled;
                                final result = await showPinAuthSheet(
                                  context,
                                  allowBiometric: requireBio,
                                  biometricAuth: () =>
                                      BiometricService.authenticate(
                                        context,
                                        reason: 'Confirm payment',
                                      ),
                                );
                                if (result == null || !result.success) return;
                                if (!context.mounted) return;
                                Navigator.of(context).pop();
                                final rootContext = this.context;
                                if (rootContext.mounted) {
                                  rootContext.loaderOverlay.show();
                                }
                                try {
                                  final res =
                                      await CableService.purchaseCableSubscription(
                                        cableNameId:
                                            _selectedCable?['id'] as int,
                                        cablePlanId:
                                            _selectedPlan?['id'] as int,
                                        smartCardNumber: _smartCardController
                                            .text
                                            .trim(),
                                        customerName: customer,
                                      );
                                  if (rootContext.mounted) {
                                    rootContext.loaderOverlay.hide();
                                  }
                                  _showResultSheet(res);
                                } catch (e) {
                                  if (rootContext.mounted) {
                                    rootContext.loaderOverlay.hide();
                                  }
                                  _showResultSheet({
                                    'status': 'failed',
                                    'message': {
                                      'error': [
                                        e.toString().replaceFirst(
                                          'Exception: ',
                                          '',
                                        ),
                                      ],
                                    },
                                  });
                                }
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: hasEnough
                              ? Colors.transparent
                              : Colors.grey,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Confirm',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context);
    final cables = _getCableList(appData);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cable Subscription'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: LoaderOverlay(
        overlayColor: const Color.fromRGBO(128, 0, 128, 0.1),
        overlayWidgetBuilder: (context) => Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        child: IgnorePointer(
          ignoring: _validating,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  const Text(
                    'Cable name',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: cables.length,
                      itemBuilder: (context, index) {
                        final c = cables[index];
                        final selectedId = _selectedCable != null
                            ? _selectedCable!['id'] as int
                            : -1;
                        final isSelected = selectedId == (c['id'] as int);
                        return Padding(
                          padding: const EdgeInsets.only(right: 14.0),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedCable = c;
                                _cableController.text = (c['name'] ?? '')
                                    .toString();
                                _selectedPlan = null;
                                _planController.clear();
                                _amountController.clear();
                              });
                            },
                            child: CableCard(
                              cable: Cable(
                                id: c['id'] as int,
                                name: (c['name'] ?? '').toString(),
                                cableplan: _getPlansForSelected()
                                    .map(
                                      (p) => CablePlan(
                                        id: p['id'] as int,
                                        package: (p['package'] ?? '')
                                            .toString(),
                                        planAmount:
                                            (p['plan_amount'] as num?)
                                                ?.toDouble() ??
                                            0,
                                      ),
                                    )
                                    .toList(),
                              ),
                              isSelected: isSelected,
                              dim: _selectedCable != null && !isSelected,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Text(
                    'Smart Card number / IUC number',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  MyTextfield(
                    hintText: 'Enter Smart card / IUC number',
                    textController: _smartCardController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                  ),
                  if (_inlineError != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _inlineError!,
                      style: TextStyle(
                        color: Colors.redAccent.shade200,
                        fontSize: 13,
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  const Text(
                    'Cable plan',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  MyTextfield(
                    hintText: _selectedPlan == null
                        ? 'Tap to select plan'
                        : 'Plan',
                    textController: _planController,
                    readOnly: true,
                    onTap: _openPlanBottomSheet,
                  ),
                  if (_selectedPlan != null) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Amount',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    MyTextfield(
                      hintText: 'Amount',
                      textController: _amountController,
                      readOnly: true,
                      keyboardType: TextInputType.number,
                    ),
                  ],

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _canValidate && !_validating
                          ? _validateIUC
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _canValidate
                            ? Colors.purple
                            : Colors.grey,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Validate',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
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

  void _showResultSheet(Map<String, dynamic> payload) {
    final status = (payload['status'] ?? '').toString();
    final isSuccess =
        status == 'success' ||
        (payload['Status']?.toString().toLowerCase() == 'successful');
    final color = Theme.of(context).colorScheme.primary;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom + 16;
        final data = payload['data'] is Map<String, dynamic>
            ? payload['data'] as Map<String, dynamic>
            : payload;
        final messageMap = payload['message'] as Map<String, dynamic>?;
        final errors = messageMap != null
            ? (messageMap['error'] as List?)?.whereType<String>().toList() ?? []
            : <String>[];
        final apiMsg = data['api_response']?.toString();

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: bottomInset,
              top: 12,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      isSuccess ? Icons.check_circle : Icons.error_outline,
                      color: isSuccess ? Colors.green : Colors.red,
                      size: 28,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Subscription Status',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (isSuccess) ...[
                  _kv('Cable', (_selectedCable?['name'] ?? '').toString()),
                  _kv('Plan', (_selectedPlan?['package'] ?? '').toString()),
                  _kv('IUC/Smartcard', _smartCardController.text),
                  if (data['token'] != null)
                    _kv('Token', data['token'].toString()),
                  if (data['ident'] != null)
                    _kv('Reference', data['ident'].toString()),
                ] else ...[
                  if (apiMsg != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        apiMsg,
                        style: const TextStyle(color: Colors.black87),
                      ),
                    ),
                  ...errors.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        e,
                        style: const TextStyle(color: Colors.black87),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(isSuccess ? 'Done' : 'Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
