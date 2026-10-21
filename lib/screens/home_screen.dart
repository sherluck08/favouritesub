import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:favouritesub/models/service.dart';
import 'package:favouritesub/providers/settings_provider.dart';
import 'package:favouritesub/screens/buy_data_screen.dart';
import 'package:favouritesub/screens/electricity_bill_screen.dart';
import 'package:favouritesub/screens/cable_sub_screen.dart';
import 'package:favouritesub/widgets/service_card.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../widgets/transaction_list_item.dart';
import 'transaction_screen.dart';
import 'transaction_receipt_screen.dart';
import 'package:favouritesub/providers/user_provider.dart';
import 'package:favouritesub/screens/buy_airtime_screen.dart';
import 'package:favouritesub/screens/recharge_pin_screen.dart';
import 'package:favouritesub/screens/result_checker_screen.dart';
import 'package:favouritesub/screens/fund_wallet_screen.dart';
import 'package:favouritesub/providers/app_data_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:favouritesub/utils/pin_guard.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _alertShown = false;
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => Provider.of<UserProvider>(context, listen: false).loadUserData(),
    );
    Future.microtask(
      () => Provider.of<TransactionProvider>(context, listen: false).refresh(),
    );

    Future.microtask(() async {
      final appData = Provider.of<AppDataProvider>(context, listen: false);
      await appData.load();
      await _maybeShowAppAlert();

      await PinGuard.prewarm(context);
    });
  }

  Future<void> _refreshUserData() async {
    await Provider.of<UserProvider>(context, listen: false).refreshUserData();
  }

  Future<void> _maybeShowAppAlert() async {
    if (_alertShown) return;
    final appData = Provider.of<AppDataProvider>(context, listen: false).data;
    final alertMsg = (appData?.alert?.message ?? '').trim();
    final notifMsg = (appData?.notification?.message ?? '').trim();
    String message = '';
    if (alertMsg.isNotEmpty) {
      message = alertMsg;
    } else if (notifMsg.isNotEmpty) {
      message = notifMsg;
    }
    if (message.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final storageKey = token != null && token.isNotEmpty
        ? 'alert_shown_for_token_$token'
        : 'alert_shown_generic';
    final alreadyShown = prefs.getBool(storageKey) ?? false;
    if (alreadyShown) return;

    _alertShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showAnnouncementDialog(
        message.replaceAll('\r\n', '\n'),
        storageKey: storageKey,
      );
    });
  }

  void _showAnnouncementDialog(String message, {required String storageKey}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.7),
                        Theme.of(context).colorScheme.primary,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.campaign_rounded, color: Colors.white),
                      const SizedBox(width: 10),
                      const Text(
                        'Announcement',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    message,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool(storageKey, true);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Got it',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    final List<Service> services = [
      Service(
        name: 'Buy Data',
        icon: Icons.wifi,
        gradientColors: [Colors.blue, Theme.of(context).colorScheme.primary],
        onTap: () {
          PinGuard.pushWithPinSetup(context, (_) => BuyDataScreen());
        },
      ),
      Service(
        name: 'Airtime topup',
        icon: Icons.phone,
        gradientColors: [Colors.orange, Colors.red],
        onTap: () {
          PinGuard.pushWithPinSetup(context, (_) => const BuyAirtimeScreen());
        },
      ),
      Service(
        name: 'Cable Sub',
        icon: Icons.tv,
        gradientColors: [Colors.green, Colors.teal],
        onTap: () {
          PinGuard.pushWithPinSetup(context, (_) => const CableSubScreen());
        },
      ),
      Service(
        name: 'Electricity',
        icon: Icons.lightbulb,
        gradientColors: [Colors.pink, Colors.indigo],
        onTap: () {
          PinGuard.pushWithPinSetup(
            context,
            (_) => const ElectricityBillScreen(),
          );
        },
      ),
      Service(
        name: 'Recharge PIN',
        icon: Icons.print,
        gradientColors: [
          Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
          Theme.of(context).colorScheme.primary,
        ],
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const RechargePinScreen()),
          );
        },
      ),
      Service(
        name: 'Result Checker',
        icon: Icons.article_outlined,
        gradientColors: [Colors.teal, Colors.green],
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ResultCheckerScreen(),
            ),
          );
        },
      ),
    ];

    final userProvider = Provider.of<UserProvider>(context);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshUserData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              Container(
                height: MediaQuery.of(context).size.height * 0.34,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(8),
                  ),
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.7),
                      Theme.of(context).colorScheme.primary,
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 30),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Welcome Back,",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),

                            Text(
                              userProvider.username,
                              style: TextStyle(
                                color: Colors.blue.shade100,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        Spacer(),
                        IconButton(
                          padding: EdgeInsets.zero,

                          onPressed: () {},
                          icon: Icon(
                            Icons.notifications_outlined,
                            color: Colors.blue[50],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Card(
                      color: Colors.transparent,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                          child: Container(
                            width: MediaQuery.of(context).size.width,
                            color: Colors.white.withValues(alpha: 0.1),
                            padding: EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          "Wallet Balance",
                                          style: TextStyle(
                                            color: Colors.pink.shade50,
                                            fontSize: 14,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: () {
                                            settings.setShowBalance(
                                              !settings.showBalance,
                                            );
                                          },
                                          child: Icon(
                                            settings.showBalance
                                                ? Icons.remove_red_eye_outlined
                                                : Icons.visibility_off_outlined,
                                            color: Colors.pink.shade50,
                                            size: 20,
                                          ),
                                        ),
                                      ],
                                    ),

                                    Row(
                                      children: [
                                        Text(
                                          settings.showBalance
                                              ? userProvider.balance
                                              : '********',
                                          style: TextStyle(
                                            color: Colors.pink.shade50,
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (settings.showBalance &&
                                            userProvider.isLoading)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              left: 8.0,
                                            ),
                                            child: SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(Colors.pink.shade50),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                                TextButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const FundWalletScreen(),
                                      ),
                                    );
                                  },
                                  label: Text("Fund Wallet"),
                                  icon: Icon(Icons.add),
                                  style: TextButton.styleFrom(
                                    backgroundColor: Colors.blue[50],
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "What would you like to do today?",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 20),
                  ],
                ),
              ),

              Container(
                transform: Matrix4.translationValues(0.0, -95.0, 0.0),
                padding: const EdgeInsets.all(16),

                child: Column(
                  children: [
                    GridView.count(
                      crossAxisCount: 3,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      children: services
                          .map((service) => ServiceCard(service: service))
                          .toList(),
                    ),
                    const SizedBox(height: 20),

                    Container(
                      padding: EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(14),
                          topRight: Radius.circular(14),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Recent Transactions",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const TransactionScreen(),
                                    ),
                                  );
                                },
                                child: const Text(
                                  "View All",
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Consumer<TransactionProvider>(
                            builder: (context, tx, _) {
                              final list = tx.items.take(5).toList();
                              if (tx.isLoading && list.isEmpty) {
                                return const Padding(
                                  padding: EdgeInsets.all(24.0),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              if (list.isEmpty) {
                                return Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(
                                    'No recent transactions',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                );
                              }
                              return Column(
                                children: list
                                    .map(
                                      (t) => InkWell(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  TransactionReceiptScreen(
                                                    item: t,
                                                  ),
                                            ),
                                          );
                                        },
                                        child: TransactionListItem(item: t),
                                      ),
                                    )
                                    .toList(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
