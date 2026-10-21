import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'package:favouritesub/providers/app_data_provider.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/beneficiary_service.dart';
import '../services/purchase_service.dart';

import '../models/network.dart';
import '../models/plan_card.dart';
import '../providers/plan_provider.dart';
import '../utils/utils.dart';
import '../widgets/plan_card_widget.dart';
import '../widgets/recent_beneficiaries_strip.dart';
import '../widgets/wallet_balance_text.dart';
import 'transaction_screen.dart';
import 'fund_wallet_screen.dart';
import '../widgets/primary_result_sheet.dart';

import 'package:favouritesub/providers/settings_provider.dart';
import '../services/wallet_service.dart';
import '../widgets/pin_auth_sheet.dart';
import '../services/biometric_service.dart';
import 'package:favouritesub/utils/nigerian_network_validator.dart';
import '../services/transaction_notifier.dart';
import '../widgets/confirm_transaction_screen.dart';

final imagePath = "assets/images";

final networks = [
  Network(
    id: 1,
    name: "Mtn",
    image: "$imagePath/mtn_logo.png",
    bgColor: Colors.yellow,
  ),
  Network(
    id: 2,
    name: "Glo",
    image: "$imagePath/glo_logo.png",
    bgColor: Color(0xFF53ac46),
  ),
  Network(
    id: 4,
    name: "Airtel",
    image: "$imagePath/airtel_logo.png",
    bgColor: Colors.red.shade100,
  ),
  Network(
    id: 3,
    name: "9mobile",
    image: "$imagePath/9mobile_logo.png",
    bgColor: Colors.green.shade300,
  ),
];

class BuyDataScreen extends StatefulWidget {
  const BuyDataScreen({super.key});

  @override
  State<BuyDataScreen> createState() => _BuyDataScreenState();
}

class _BuyDataScreenState extends State<BuyDataScreen> {
  String? _selectedValue;
  int? _selectedNetworkId;
  int networkId = 0;
  final TextEditingController _phoneController = TextEditingController();
  final picker = FlutterNativeContactPicker();
  String? _phoneNetworkError;
  List<BeneficiaryItem> _beneficiaries = const [];

  @override
  void initState() {
    super.initState();
    _loadBeneficiaries();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AppDataProvider>().silentRefresh(force: true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    for (final asset in const [
      'assets/images/mtn_logo.png',
      'assets/images/glo_logo.png',
      'assets/images/9mobile_logo.png',
      'assets/images/airtel_logo.png',
    ]) {
      precacheImage(AssetImage(asset), context);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickContact() async {
    try {
      final contact = await picker.selectContact();
      if (!mounted) return;
      if (contact != null && contact.phoneNumbers?.isNotEmpty == true) {
        String rawNumber = contact.phoneNumbers!.first;
        String formatted = formatNigerianNumber(rawNumber);
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

  void _onNext() {
    if (!_isReady) return;
    final plan = Provider.of<PlanProvider>(
      context,
      listen: false,
    ).selectedPlan!;
    final appData = Provider.of<AppDataProvider>(context, listen: false);
    if (appData.networks.isEmpty) return;
    final network = appData.networks.firstWhere(
      (item) => item.id == _selectedNetworkId,
      orElse: () => appData.networks.first,
    );
    final networkId = _selectedNetworkId!;
    final phone = _phoneController.text.trim();
    final imagePath = networks
        .firstWhere(
          (item) => item.id == networkId,
          orElse: () => networks.first,
        )
        .image;

    pushConfirmTransaction(
      context,
      networkImage: Image.asset(imagePath, fit: BoxFit.contain),
      details: [
        TxDetail('To', phone),
        TxDetail('Amount', 'N${plan.planAmount}.0'),
        TxDetail('Network', network.name),
        TxDetail('Description', '${plan.planSize} FOR ${plan.planType}'),
      ],
      onExecute: () async {
        final result = await PurchaseService.buyData(
          networkId: networkId,
          planType: plan.planType,
          planId: plan.planId,
          phone: phone,
          expectedAmount: plan.planAmount,
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
          "Congratulations! You've successfully purchased ${plan.planSize} for $phone on ${network.name}",
      notify: TxInfo(
        kind: TxKind.data,
        amount: '₦${plan.planAmount}',
        recipient: phone,
        network: network.name,
        plan: '${plan.planSize} ${plan.planType}',
      ),
    );
  }

  bool get _isReady {
    final plan = Provider.of<PlanProvider>(context, listen: false).selectedPlan;
    return _selectedNetworkId != null &&
        _phoneController.text.length == 11 &&
        _selectedValue != null &&
        plan != null &&
        _phoneNetworkError == null;
  }

  Future<void> _loadBeneficiaries() async {
    final items = await BeneficiaryService.load(
      service: BeneficiaryService.data,
    );
    if (!mounted) return;
    setState(() => _beneficiaries = items);
  }

  void _applyBeneficiary(BeneficiaryItem item) {
    setState(() {
      _selectedNetworkId = item.networkId;
      networkId = item.networkId;
      _selectedValue = null;
      _phoneNetworkError = null;
      _phoneController.text = item.phone;
    });
    Provider.of<PlanProvider>(context, listen: false).setSelectedPlan(null);
    FocusScope.of(context).unfocus();
  }

  void _onNetworkTap(int id) {
    setState(() {
      _selectedNetworkId = id;
      networkId = id;
      _selectedValue = null;
      _phoneNetworkError = null;
    });
    Provider.of<PlanProvider>(context, listen: false).setSelectedPlan(null);
  }

  Future<void> _saveBeneficiary({
    required int networkId,
    required String networkName,
    required String phone,
  }) async {
    final items = await BeneficiaryService.save(
      service: BeneficiaryService.data,
      networkId: networkId,
      networkName: networkName,
      phone: phone,
    );
    if (!mounted) return;
    setState(() => _beneficiaries = items);
  }

  String _logoForNetwork(int networkId) =>
      _DataNetworkChip._images[networkId] ?? '';

  Future<void> _showDataTypeSheet() async {
    final cs = Theme.of(context).colorScheme;
    final appData = Provider.of<AppDataProvider>(context, listen: false);
    await appData.silentRefresh(force: true);
    if (!mounted) return;
    final options = _getPlanTypesForSelectedNetwork(appData);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
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
              'Select Data Type',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ...options.map(
              (option) => ListTile(
                title: Text(option),
                trailing: _selectedValue == option
                    ? Icon(Icons.check, color: cs.primary)
                    : null,
                onTap: () {
                  setState(() => _selectedValue = option);
                  Provider.of<PlanProvider>(
                    context,
                    listen: false,
                  ).setSelectedPlan(null);
                  Navigator.pop(sheetContext);
                  _showPlanBottomSheet(option);
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Get plan types for the selected network from API data
  /// Returns only the plan types that are actually available for the selected network
  List<String> _getPlanTypesForSelectedNetwork(AppDataProvider appData) {
    // If no network selected or no networks available, return empty list
    if (_selectedNetworkId == null || appData.networks.isEmpty) {
      return [];
    }

    try {
      // Find the selected network
      final selectedNetwork = appData.networks.firstWhere(
        (network) => network.id == _selectedNetworkId,
        orElse: () => appData.networks.first,
      );

      // Return the actual plan types from the selected network
      // plansByType is a Map<String, List<NetworkPlanItem>>
      // We want the keys (plan types) that have at least one plan
      final planTypes = selectedNetwork.plansByType.keys
          .where((key) => selectedNetwork.plansByType[key]?.isNotEmpty ?? false)
          .toList();

      return planTypes;
    } catch (e) {
      // If there's any error, return empty list
      debugPrint('Error getting plan types: $e');
      return [];
    }
  }

  void _showPlanBottomSheet(String selectedType) {
    final appData = Provider.of<AppDataProvider>(context, listen: false);
    final items = _selectedNetworkId == null
        ? <dynamic>[]
        : appData.getPlansFor(_selectedNetworkId!, selectedType);

    final filteredPlans = items
        .map(
          (p) => PlanCard(
            planSize: p.plan,
            planType: selectedType,
            planId: p.id.toString(),
            planAmount: (p.amount == p.amount.roundToDouble())
                ? p.amount.toInt().toString()
                : p.amount.toStringAsFixed(0),
            planValidity: p.validity,
          ),
        )
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: filteredPlans.length > 6 ? 0.72 : 0.58,
          maxChildSize: 0.94,
          minChildSize: 0.48,
          builder: (context, scrollController) {
            final colors = Theme.of(context).colorScheme;
            final hasMorePlans = filteredPlans.length > 6;
            return Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: colors.outlineVariant,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Choose a $selectedType plan',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  Icon(
                                    hasMorePlans
                                        ? Icons.swipe_up_rounded
                                        : Icons.touch_app_outlined,
                                    size: 17,
                                    color: colors.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      hasMorePlans
                                          ? 'Scroll down to see all available plans'
                                          : 'Tap a plan to select it',
                                      style: TextStyle(
                                        color: colors.onSurfaceVariant,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.09),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            '${filteredPlans.length} ${filteredPlans.length == 1 ? 'plan' : 'plans'}',
                            style: TextStyle(
                              color: colors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: colors.outlineVariant),
                  Expanded(
                    child: filteredPlans.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.inventory_2_outlined,
                                    size: 42,
                                    color: colors.onSurfaceVariant,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No plans are available for this type yet.',
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final columns = constraints.maxWidth < 360
                                  ? 2
                                  : constraints.maxWidth > 650
                                  ? 4
                                  : 3;
                              return Scrollbar(
                                controller: scrollController,
                                thumbVisibility: hasMorePlans,
                                trackVisibility: hasMorePlans,
                                radius: const Radius.circular(8),
                                child: GridView.builder(
                                  controller: scrollController,
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    16,
                                    22,
                                    28,
                                  ),
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: columns,
                                        mainAxisSpacing: 12,
                                        crossAxisSpacing: 12,
                                        childAspectRatio: columns == 2
                                            ? 1.05
                                            : 0.85,
                                      ),
                                  itemCount: filteredPlans.length,
                                  itemBuilder: (context, index) {
                                    final plan = filteredPlans[index];
                                    return PlanCardWidget(
                                      plan: plan,
                                      onTap: () {
                                        context
                                            .read<PlanProvider>()
                                            .setSelectedPlan(plan);
                                        Navigator.of(context).pop();
                                      },
                                    );
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
  }

  // Kept available for deployments that enforce carrier matching.
  // ignore: unused_element
  bool _validatePhoneAgainstSelectedNetwork({bool showMessage = false}) {
    final phone = _phoneController.text.trim();
    if (phone.length < 10 || _selectedNetworkId == null) {
      setState(() => _phoneNetworkError = null);
      return true;
    }

    final validation = NigerianNetworkValidator.validateNumber(phone);
    String? expected;
    switch (_selectedNetworkId) {
      case 1:
        expected = 'MTN';
        break;
      case 2:
        expected = 'GLO';
        break;
      case 3:
        expected = 'AIRTEL';
        break;
      case 4:
        expected = '9MOBILE';
        break;
      default:
        expected = null;
    }

    final detected = (validation.network?.name ?? '').toUpperCase();
    final ok = expected == null || detected == expected;
    setState(() {
      _phoneNetworkError = ok
          ? null
          : 'Number does not match selected network ($expected)';
    });

    if (!ok && showMessage) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('The entered number is not a valid $expected line'),
        ),
      );
    }
    return ok;
  }

  // Retained temporarily for compatibility with the previous checkout flow.
  // ignore: unused_element
  void _showPurchaseSummary({
    required Network network,
    required String phone,
    required PlanCard plan,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Confirm your order",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              SizedBox(height: 10),
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Network",
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        Spacer(),
                        Text(network.name, style: TextStyle(fontSize: 14)),
                        SizedBox(width: 8),
                        Image.asset(network.image, width: 30),
                      ],
                    ),

                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Plan",
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),

                        Text(
                          '${plan.planSize} ${plan.planType} ',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),

                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Validity",
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),

                        Text(plan.planValidity, style: TextStyle(fontSize: 14)),
                      ],
                    ),

                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Amount",
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),

                        Text(plan.planAmount, style: TextStyle(fontSize: 14)),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Phone",
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700,
                            fontSize: 14,
                          ),
                        ),
                        Text(phone, style: TextStyle(fontSize: 14)),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 10),
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
                  final selectedPlan = Provider.of<PlanProvider>(
                    context,
                  ).selectedPlan;
                  final amount =
                      double.tryParse(
                        (selectedPlan?.planAmount ?? '0').replaceAll(',', ''),
                      ) ??
                      0.0;
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
                    final selectedPlan = Provider.of<PlanProvider>(
                      context,
                    ).selectedPlan;
                    final amount =
                        double.tryParse(
                          (selectedPlan?.planAmount ?? '0').replaceAll(',', ''),
                        ) ??
                        0.0;
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
                      final selectedPlan = Provider.of<PlanProvider>(
                        context,
                        listen: false,
                      ).selectedPlan;
                      final amount =
                          double.tryParse(
                            (selectedPlan?.planAmount ?? '0').replaceAll(
                              ',',
                              '',
                            ),
                          ) ??
                          0.0;
                      final balance = WalletService.getWalletBalance(context);
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
                      if (!context.mounted) return;
                      if (result == null || !result.success) return;
                      final currentPlan = selectedPlan!;
                      final phone = _phoneController.text.trim();
                      await _performPurchase(
                        networkId: networkId,
                        planType: currentPlan.planType,
                        planId: currentPlan.planId,
                        phone: phone,
                        selectedPlan: currentPlan,
                      );
                    },
                    style: (() {
                      final selectedPlan = Provider.of<PlanProvider>(
                        context,
                      ).selectedPlan;
                      final amount =
                          double.tryParse(
                            (selectedPlan?.planAmount ?? '0').replaceAll(
                              ',',
                              '',
                            ),
                          ) ??
                          0.0;
                      final hasEnough = WalletService.hasSufficientBalance(
                        balance: WalletService.getWalletBalance(context),
                        amount: amount,
                      );
                      return ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: hasEnough
                            ? Colors.transparent
                            : Colors.grey,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 60,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      );
                    })(),
                    child: Builder(
                      builder: (context) {
                        return const Text(
                          "Confirm Payment",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        );
                      },
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

  void _resetForm() {
    setState(() {
      _selectedNetworkId = null;
      _selectedValue = null;
      networkId = 0;
      _phoneController.clear();
    });
    Provider.of<PlanProvider>(context, listen: false).setSelectedPlan(null);
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
    final selectedPlan = Provider.of<PlanProvider>(context).selectedPlan;
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          Provider.of<PlanProvider>(
            context,
            listen: false,
          ).setSelectedPlan(null);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: cs.onPrimary),
            onPressed: () {
              Provider.of<PlanProvider>(
                context,
                listen: false,
              ).setSelectedPlan(null);
              Navigator.pop(context);
            },
          ),
          centerTitle: true,
          title: Text(
            'Data',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: cs.onPrimary,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _DataNextButton(active: _isReady, onTap: _onNext, cs: cs),
            ),
          ],
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: RefreshIndicator(
            onRefresh: () => context.read<AppDataProvider>().refresh(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DataWalletBar(cs: cs),
                  const SizedBox(height: 24),
                  RecentBeneficiariesStrip(
                    items: _beneficiaries,
                    logoForNetwork: _logoForNetwork,
                    onTap: _applyBeneficiary,
                  ),
                  if (_beneficiaries.isNotEmpty) const SizedBox(height: 24),
                  _dataLabel(context, 'Select Network'),
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
                          child: _DataNetworkChip(
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
                    _dataLabel(context, 'Data Types'),
                    const SizedBox(height: 8),
                    _DataDropdownField(
                      value: _selectedValue,
                      hint: 'Data Types',
                      onTap: _showDataTypeSheet,
                      cs: cs,
                    ),
                  ],
                  const SizedBox(height: 24),
                  _dataLabel(context, 'Phone Number'),
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
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: cs.surfaceContainerHighest.withValues(
                        alpha: 0.35,
                      ),
                      hintText: 'Phone Number',
                      hintStyle: TextStyle(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          Icons.contacts_rounded,
                          color: cs.onSurfaceVariant,
                        ),
                        onPressed: _pickContact,
                      ),
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
                      counterText: '',
                      errorText: _phoneNetworkError,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),
                  if (selectedPlan != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'You selected:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${selectedPlan.planSize} for ₦${selectedPlan.planAmount} (${selectedPlan.planValidity})',
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dataLabel(BuildContext context, String text) => Text(
    text,
    style: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: Theme.of(context).colorScheme.onSurface,
    ),
  );
}

class _DataWalletBar extends StatelessWidget {
  final ColorScheme cs;
  const _DataWalletBar({required this.cs});

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

class _DataNextButton extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  final ColorScheme cs;

  const _DataNextButton({
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

class _DataNetworkChip extends StatelessWidget {
  final int networkId;
  final bool isSelected;
  final bool dim;
  final VoidCallback onTap;

  const _DataNetworkChip({
    required this.networkId,
    required this.isSelected,
    required this.dim,
    required this.onTap,
  });

  static const _backgroundColors = {
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
                color: _backgroundColors[networkId] ?? Colors.grey.shade200,
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

class _DataDropdownField extends StatelessWidget {
  final String? value;
  final String hint;
  final VoidCallback onTap;
  final ColorScheme cs;

  const _DataDropdownField({
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

extension on _BuyDataScreenState {
  Future<void> _performPurchase({
    required int networkId,
    required String planType,
    required String planId,
    required String phone,
    required PlanCard selectedPlan,
  }) async {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    _showLoading();
    try {
      final res = await PurchaseService.buyData(
        networkId: networkId,
        planType: planType,
        planId: planId,
        phone: phone,
        expectedAmount: selectedPlan.planAmount,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      final status = (res['status'] ?? '').toString().toLowerCase();
      if (status.contains('success')) {
        final network = networks.firstWhere(
          (item) => item.id == networkId,
          orElse: () => networks.first,
        );
        await _saveBeneficiary(
          networkId: networkId,
          networkName: network.name,
          phone: phone,
        );
        if (!mounted) return;
        _resetForm();
        _showResultDialog(
          title: 'Your data purchase was successful.',
          message:
              'You have successfully purchased ${selectedPlan.planSize} for ₦${selectedPlan.planAmount} (${selectedPlan.planValidity}) on $phone',
          color: Colors.green,
          icon: Icons.check_circle_outline,
        );
      } else if (status.contains('process')) {
        _resetForm();
        _showResultDialog(
          title: 'Processing',
          message:
              'Your purchase is processing. Please check transactions shortly.',
          color: Colors.orange,
          icon: Icons.hourglass_bottom,
        );
      } else {
        _resetForm();
        _showResultDialog(
          title: 'Purchase Failed',
          message: (res['message'] ?? 'The purchase could not be completed.')
              .toString(),
          color: Colors.red,
          icon: Icons.error_outline,
        );
      }
    } catch (e) {
      debugPrint('Data purchase failed: $e');
      if (!mounted) return;
      Navigator.of(context).pop();
      _resetForm();
      _showResultDialog(
        title: 'Errors',
        message: e.toString(),
        color: Colors.red,
        icon: Icons.error_outline,
      );
    }
  }

  void _showLoading() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
  }

  void _showResultDialog({
    required String title,
    required String message,
    required Color color,
    required IconData icon,
  }) {
    showPrimaryResultSheet(
      context,
      title: title,
      message: message,
      color: color,
      icon: icon,
      primaryButtonLabel: 'Done',
      onPrimaryPressed: () {},
      secondaryButtonLabel: 'View Transactions',
      onSecondaryPressed: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const TransactionScreen()));
      },
    );
  }
}
