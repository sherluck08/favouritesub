import 'package:favouritesub/screens/fund_wallet_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:favouritesub/providers/app_data_provider.dart';
import 'package:favouritesub/widgets/primary_button.dart';
import 'package:favouritesub/widgets/wallet_balance_text.dart';
import 'package:favouritesub/providers/settings_provider.dart';
import 'package:favouritesub/widgets/pin_auth_sheet.dart';
import 'package:favouritesub/services/biometric_service.dart';
import 'package:favouritesub/services/recharge_pin_service.dart';
import 'package:favouritesub/models/transaction_item.dart';
import 'package:favouritesub/screens/specialized_receipt_screens.dart';
import 'package:flutter/services.dart';
import 'package:favouritesub/services/wallet_service.dart';
import 'package:favouritesub/models/app_data.dart';
import 'package:favouritesub/utils/utils.dart';

class RechargePinScreen extends StatefulWidget {
  const RechargePinScreen({super.key});

  @override
  State<RechargePinScreen> createState() => _RechargePinScreenState();
}

class _RechargePinScreenState extends State<RechargePinScreen> {
  int? _selectedNetworkId;
  int? _selectedAmountId;
  final TextEditingController _nameCtrl = TextEditingController();
  int _quantity = 1;
  final TextEditingController _quantityCtrl = TextEditingController(text: '1');
  bool _isPlacing = false;

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
    _nameCtrl.dispose();
    _quantityCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appData = context.watch<AppDataProvider>();
    final colors = Theme.of(context).colorScheme;

    final networks = appData.data?.networks ?? const [];
    final selectedNetwork = (_selectedNetworkId != null && networks.isNotEmpty)
        ? networks.firstWhere(
            (n) => n.id == _selectedNetworkId,
            orElse: () => networks.first,
          )
        : null;
    final amounts = selectedNetwork?.rechargeCardPricing ?? const [];

    double? unitPrice;
    if (selectedNetwork != null && _selectedAmountId != null) {
      final list = selectedNetwork.rechargeCardPricing;
      if (list.isNotEmpty) {
        final match = list.firstWhere(
          (e) => e.id == _selectedAmountId,
          orElse: () => list.first,
        );
        unitPrice = match.amountToPay;
      }
    }
    final total = unitPrice != null ? (unitPrice * _quantity) : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Recharge PIN'), centerTitle: true),
      body: networks.isEmpty
          ? Center(
              child: appData.isLoading
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('No networks available'),
                        const SizedBox(height: 12),
                        PrimaryButton(
                          label: 'Retry',
                          onPressed: () => appData.refresh(),
                        ),
                      ],
                    ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 36),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _RechargeWalletCard(colors: colors),
                      const SizedBox(height: 26),
                      Text(
                        'Print recharge PINs',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Choose a network and denomination, then enter the name to print on each card.',
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 26),
                      _sectionLabel('Network', colors),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 102,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: networks.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final network = networks[index];
                            return _RechargeNetworkCard(
                              network: network,
                              selected: _selectedNetworkId == network.id,
                              colors: colors,
                              onTap: () => setState(() {
                                _selectedNetworkId = network.id;
                                _selectedAmountId = null;
                              }),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      _sectionLabel('Denomination', colors),
                      const SizedBox(height: 9),
                      DropdownButtonFormField<int>(
                        key: ValueKey(
                          '${_selectedNetworkId ?? 'network'}-${_selectedAmountId ?? 'amount'}',
                        ),
                        initialValue: _selectedAmountId,
                        isExpanded: true,
                        decoration: _fieldDecoration(
                          context,
                          hint: selectedNetwork == null
                              ? 'Select a network first'
                              : 'Select recharge amount',
                          icon: Icons.payments_outlined,
                        ),
                        items: amounts
                            .map(
                              (price) => DropdownMenuItem<int>(
                                value: price.id,
                                child: Text(
                                  '₦${price.amount.toStringAsFixed(0)} value  •  ₦${price.amountToPay.toStringAsFixed(0)} each',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: selectedNetwork == null
                            ? null
                            : (value) =>
                                  setState(() => _selectedAmountId = value),
                      ),
                      const SizedBox(height: 20),
                      _sectionLabel('Print details', colors),
                      const SizedBox(height: 9),
                      TextField(
                        controller: _nameCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: _fieldDecoration(
                          context,
                          hint: 'Name on card',
                          icon: Icons.badge_outlined,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _quantityCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                        ],
                        decoration:
                            _fieldDecoration(
                              context,
                              hint: 'Quantity',
                              icon: Icons.confirmation_number_outlined,
                            ).copyWith(
                              suffixText: _quantity == 1 ? 'card' : 'cards',
                            ),
                        onChanged: (value) {
                          final parsed = int.tryParse(value.trim());
                          setState(() {
                            _quantity = parsed == null || parsed < 1
                                ? 1
                                : parsed;
                          });
                        },
                      ),
                      if (total != null) ...[
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: colors.primary.withValues(alpha: 0.14),
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                'Total to pay',
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '₦${total.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: colors.primary,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _isPlacing
                              ? null
                              : () => _showConfirmSheet(context),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(54),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            _isPlacing ? 'Processing…' : 'Continue',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _sectionLabel(String label, ColorScheme colors) => Text(
    label,
    style: TextStyle(
      color: colors.onSurface,
      fontSize: 14,
      fontWeight: FontWeight.w800,
    ),
  );

  InputDecoration _fieldDecoration(
    BuildContext context, {
    required String hint,
    required IconData icon,
  }) {
    final colors = Theme.of(context).colorScheme;
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
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
    );
  }

  void _showConfirmSheet(BuildContext context) {
    if (_selectedNetworkId == null ||
        _selectedAmountId == null ||
        _nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all fields')),
      );
      return;
    }

    final appData = Provider.of<AppDataProvider>(context, listen: false);
    final network = appData.data!.networks.firstWhere(
      (n) => n.id == _selectedNetworkId,
    );
    final unit = network.rechargeCardPricing.firstWhere(
      (e) => e.id == _selectedAmountId,
    );
    final total = unit.amountToPay * _quantity;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final colors = Theme.of(sheetContext).colorScheme;
        final hasEnough = WalletService.hasSufficientBalance(
          balance: WalletService.getWalletBalance(sheetContext),
          amount: total,
        );
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Confirm recharge PIN order',
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 5),
              Text(
                'Review your print details before payment.',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _kv('Network', network.name),
                    const SizedBox(height: 12),
                    _kv('Denomination', '₦${unit.amount.toStringAsFixed(0)}'),
                    const SizedBox(height: 12),
                    _kv('Name on card', _nameCtrl.text.trim()),
                    const SizedBox(height: 12),
                    _kv('Quantity', _quantity.toString()),
                    const SizedBox(height: 12),
                    _kv('Total', '₦${total.toStringAsFixed(2)}'),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _RechargeWalletCard(colors: colors),
              if (!hasEnough) ...[
                const SizedBox(height: 10),
                Text(
                  'Your wallet balance is not enough for this order.',
                  style: TextStyle(color: colors.error, fontSize: 13),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: hasEnough
                      ? () async {
                          final requireBiometric = sheetContext
                              .read<SettingsProvider>()
                              .biometricPayEnabled;
                          final auth = await showPinAuthSheet(
                            sheetContext,
                            allowBiometric: requireBiometric,
                            biometricAuth: () => BiometricService.authenticate(
                              sheetContext,
                              reason: 'Confirm order',
                            ),
                          );
                          if (auth == null || !auth.success) return;
                          if (sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                          }
                          await _placeOrder();
                        }
                      : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Confirm and pay',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
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
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _placeOrder() async {
    if (_selectedNetworkId == null || _selectedAmountId == null) return;
    setState(() => _isPlacing = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final resp = await RechargePinService.createOrder(
        network: _selectedNetworkId!,
        networkAmount: _selectedAmountId!,
        nameOnCard: _nameCtrl.text.trim(),
        quantity: _quantity,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      final status = (resp['Status'] ?? resp['status'] ?? '')
          .toString()
          .toLowerCase();
      if (status == 'successful') {
        await _showSuccessPinsSheet(resp);
      } else {
        _showFailure(
          resp['error']?.toString() ?? 'Recharge PIN purchased failed',
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      _showFailure(e.toString());
    } finally {
      if (mounted) setState(() => _isPlacing = false);
    }
  }

  Future<void> _showSuccessPinsSheet(Map<String, dynamic> resp) async {
    final List<dynamic> pins = resp['data_pin'] ?? resp['pins'] ?? [];
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom + 16;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: bottomInset,
              top: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Recharge PINs Generated',
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
                const SizedBox(height: 12),
                Text(
                  'Your recharge card pins are ready.',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RechargeCardPinsReceiptScreen(
                                item: TransactionItem(
                                  id: (resp['id'] ?? '').toString(),
                                  networkName: '',
                                  planSize: '',
                                  planType: '',
                                  timestamp:
                                      DateTime.tryParse(
                                        (resp['create_date'] ?? '').toString(),
                                      ) ??
                                      DateTime.now(),
                                  networkId: (resp['network'] ?? '').toString(),
                                  amount:
                                      (resp['amount'] ??
                                              resp['paid_amount'] ??
                                              '')
                                          .toString(),
                                  status:
                                      (resp['Status'] ??
                                              resp['status'] ??
                                              'successful')
                                          .toString(),
                                  paymentMedium: '',
                                  balanceBefore:
                                      (resp['previous_balance'] ??
                                              resp['balance_before'] ??
                                              '')
                                          .toString(),
                                  balanceAfter:
                                      (resp['after_balance'] ??
                                              resp['balance_after'] ??
                                              '')
                                          .toString(),
                                  mobileNumber: '',
                                  plan: '',
                                  portedNumber: '',
                                  duration: '',
                                  apiResponse:
                                      (resp['api_response'] ??
                                              resp['message'] ??
                                              '')
                                          .toString(),
                                  transactionType: TransactionType.rechargeCard,
                                  quantity: (resp['quantity'] ?? '').toString(),
                                  nameOnCard: (resp['name_on_card'] ?? '')
                                      .toString(),
                                  service: 'Recharge Card',
                                ),
                                pinEntries: pins,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.visibility),
                        label: const Text('View Recharge Pins'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          Navigator.of(
                            context,
                          ).popUntil((route) => route.isFirst);
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.home_outlined),
                        label: const Text('Go to Dashboard'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Retained for rendering legacy recharge-pin response payloads.
  // ignore: unused_element
  Widget _pinRow(BuildContext ctx, dynamic item) {
    String pin = '';
    String serial = '';
    String load = '';
    try {
      final fields = (item is Map && item['fields'] is Map)
          ? item['fields'] as Map
          : {};
      pin = (fields['pin'] ?? '').toString();
      serial = (fields['serial'] ?? '').toString();
      load = (fields['load_code'] ?? '').toString();
    } catch (_) {}
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'PIN: ',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Expanded(
                child: Text(
                  pin,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
              IconButton(
                tooltip: 'Copy',
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: pin));
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(const SnackBar(content: Text('PIN copied')));
                  }
                },
                icon: const Icon(Icons.copy),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Text(
                'Serial: ',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Expanded(
                child: Text(
                  serial,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
              IconButton(
                tooltip: 'Copy',
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: serial));
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Serial copied')),
                    );
                  }
                },
                icon: const Icon(Icons.copy),
              ),
            ],
          ),
          if (load.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Text(
                  'Load Code: ',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Expanded(
                  child: Text(
                    load,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy',
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: load));
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Load code copied')),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showFailure(String message) {
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
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.error_outline, color: Colors.red),
                ),

                SizedBox(width: 8),
                Text(
                  'Recharge PIN Purchase Failed',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(message, style: TextStyle(fontSize: 14)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
            SizedBox(height: 40),
          ],
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
}

class _RechargeWalletCard extends StatelessWidget {
  final ColorScheme colors;

  const _RechargeWalletCard({required this.colors});

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
        WalletBalanceText(
          style: TextStyle(
            color: colors.primary,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _RechargeNetworkCard extends StatelessWidget {
  final NetworkDef network;
  final bool selected;
  final ColorScheme colors;
  final VoidCallback onTap;

  const _RechargeNetworkCard({
    required this.network,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: network.name,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 96,
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
        decoration: BoxDecoration(
          color: selected
              ? colors.primary.withValues(alpha: 0.08)
              : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(17),
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
                      Utils.logoFor(network.name),
                      width: 48,
                      height: 48,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.sim_card_outlined,
                        color: colors.primary,
                        size: 36,
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
                          color: colors.onPrimary,
                          size: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              network.name,
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
