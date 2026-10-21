import 'dart:async';

import 'package:favouritesub/main.dart';
import 'package:favouritesub/mixins/refresh_tracker_mixin.dart';
import 'package:favouritesub/models/app_data.dart';
import 'package:favouritesub/models/transaction_item.dart';
import 'package:favouritesub/providers/app_data_provider.dart';
import 'package:favouritesub/providers/settings_provider.dart';
import 'package:favouritesub/providers/transaction_provider.dart';
import 'package:favouritesub/providers/user_provider.dart';
import 'package:favouritesub/services/notification_store.dart';
import 'package:favouritesub/screens/bonus_to_wallet_screen.dart';
import 'package:favouritesub/screens/buy_airtime_screen.dart';
import 'package:favouritesub/screens/buy_data_screen.dart';
import 'package:favouritesub/screens/cable_sub_screen.dart';
import 'package:favouritesub/screens/electricity_bill_screen.dart';
import 'package:favouritesub/screens/fund_wallet_screen.dart';
import 'package:favouritesub/screens/notifications_screen.dart';
import 'package:favouritesub/screens/recharge_pin_screen.dart';
import 'package:favouritesub/screens/result_checker_screen.dart';
import 'package:favouritesub/screens/transaction_receipt_screen.dart';
import 'package:favouritesub/screens/transaction_screen.dart';
import 'package:favouritesub/screens/wallet_summary_screen.dart';
import 'package:favouritesub/utils/pin_guard.dart';
import 'package:favouritesub/utils/refresh_helper.dart';
import 'package:favouritesub/widgets/transaction_list_item.dart';
import 'package:favouritesub/widgets/whatsapp_support_fabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NewHomeScreen extends StatefulWidget {
  const NewHomeScreen({super.key});

  @override
  State<NewHomeScreen> createState() => _NewHomeScreenState();
}

class _NewHomeScreenState extends State<NewHomeScreen>
    with WidgetsBindingObserver, RouteAware, RefreshTrackerMixin {
  static const _brand = Color(0xFF490000);
  static const _brandBright = Color(0xFF8C1D23);

  bool _alertShown = false;
  bool _isManuallyRefreshing = false;
  DateTime? _lastBalanceUpdateTime;
  ModalRoute<void>? _subscribedRoute;

  @override
  Duration get minRefreshInterval => const Duration(seconds: 30);

  @override
  Duration get minManualRefreshInterval => const Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    startRefreshTimer();

    Future.microtask(() async {
      await _refreshData(force: true);
      if (!mounted) return;
      await _maybeShowAppAlert();
      if (mounted) PinGuard.prewarm(context);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of<void>(context);
    if (route == _subscribedRoute) return;
    if (_subscribedRoute != null) routeObserver.unsubscribe(this);
    _subscribedRoute = route;
    if (route != null) routeObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    disposeRefreshTimer();
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() => _backgroundRevalidate();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _backgroundRevalidate();
  }

  void _backgroundRevalidate() {
    if (!mounted) return;
    unawaited(context.read<AppDataProvider>().silentRefresh());
    unawaited(NotificationStore.instance.syncFromBackend());
  }

  Future<void> _refreshData({bool force = false}) async {
    if (!force && !canRefresh()) return;

    await Future.wait([
      context.read<UserProvider>().loadUserData(),
      context.read<TransactionProvider>().refresh(),
      context.read<AppDataProvider>().refresh(),
    ]);
    unawaited(NotificationStore.instance.syncFromBackend());

    markRefreshed();
    if (mounted) {
      setState(() => _lastBalanceUpdateTime = DateTime.now());
    }
  }

  Future<void> _manualRefreshBalance() async {
    if (_isManuallyRefreshing) return;
    setState(() => _isManuallyRefreshing = true);

    await RefreshHelper.executeRefresh(
      context: context,
      lastRefreshTime: _lastBalanceUpdateTime,
      minInterval: minManualRefreshInterval,
      onRefresh: context.read<UserProvider>().loadUserData,
      onSuccess: () {
        if (mounted) {
          setState(() => _lastBalanceUpdateTime = DateTime.now());
        }
      },
      successMessage: 'Balance updated',
    );

    if (mounted) setState(() => _isManuallyRefreshing = false);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _copyAccountNumber(BankAccount account) async {
    await Clipboard.setData(ClipboardData(text: account.accountNumber));
    await HapticFeedback.selectionClick();
    if (mounted) _showMessage('Account number copied');
  }

  Future<void> _maybeShowAppAlert() async {
    if (_alertShown) return;
    final appData = context.read<AppDataProvider>().data;
    final alertMessage = (appData?.alert?.message ?? '').trim();
    final notificationMessage = (appData?.notification?.message ?? '').trim();
    final message = alertMessage.isNotEmpty
        ? alertMessage
        : notificationMessage;
    if (message.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final storageKey = token != null && token.isNotEmpty
        ? 'alert_shown_for_token_$token'
        : 'alert_shown_generic';
    if (prefs.getBool(storageKey) ?? false) return;

    _alertShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _showAnnouncementDialog(
          message.replaceAll('\r\n', '\n'),
          storageKey: storageKey,
        );
      }
    });
  }

  void _showAnnouncementDialog(String message, {required String storageKey}) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final colors = theme.colorScheme;
        return AlertDialog(
          backgroundColor: colors.surface,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          iconPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          icon: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(Icons.campaign_outlined, color: colors.primary),
            ),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
          title: const Text(
            'A quick update',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              message,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                height: 1.55,
                fontSize: 14,
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          actions: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool(storageKey, true);
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Got it',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  List<_ServiceAction> _services() {
    return [
      _ServiceAction(
        icon: Icons.signal_cellular_alt_rounded,
        label: 'Buy data',
        color: const Color(0xFF3156A3),
        onTap: () =>
            PinGuard.pushWithPinSetup(context, (_) => const BuyDataScreen()),
      ),
      _ServiceAction(
        icon: Icons.phone_android_rounded,
        label: 'Airtime',
        color: const Color(0xFF18825A),
        onTap: () =>
            PinGuard.pushWithPinSetup(context, (_) => const BuyAirtimeScreen()),
      ),
      _ServiceAction(
        icon: Icons.tv_rounded,
        label: 'TV & cable',
        color: const Color(0xFF6B3FA0),
        onTap: () =>
            PinGuard.pushWithPinSetup(context, (_) => const CableSubScreen()),
      ),
      _ServiceAction(
        icon: Icons.bolt_rounded,
        label: 'Electricity',
        color: const Color(0xFFC67B08),
        onTap: () => PinGuard.pushWithPinSetup(
          context,
          (_) => const ElectricityBillScreen(),
        ),
      ),
      _ServiceAction(
        icon: Icons.savings_outlined,
        label: 'Bonus wallet',
        color: const Color(0xFF087F7C),
        onTap: () => _push(const BonusToWalletScreen()),
      ),
      _ServiceAction(
        icon: Icons.pin_outlined,
        label: 'Recharge PIN',
        color: const Color(0xFFB54040),
        onTap: () => _push(const RechargePinScreen()),
      ),
      _ServiceAction(
        icon: Icons.school_outlined,
        label: 'Exam PIN',
        color: const Color(0xFF4B56A5),
        onTap: () => _push(const ResultCheckerScreen()),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final useLightStatusIcons = colors.brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: useLightStatusIcons
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: useLightStatusIcons
            ? Brightness.dark
            : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: colors.surface,
        floatingActionButton: const WhatsAppSupportFabs(),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        body: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, viewport) {
              final sidePadding = viewport.maxWidth >= 900
                  ? 32.0
                  : viewport.maxWidth >= 600
                  ? 24.0
                  : 16.0;

              return RefreshIndicator(
                color: colors.primary,
                edgeOffset: 72,
                onRefresh: _refreshData,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 980),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              sidePadding,
                              14,
                              sidePadding,
                              140,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _HomeHeader(),
                                const SizedBox(height: 22),
                                _Appear(
                                  child: Consumer2<UserProvider, SettingsProvider>(
                                    builder: (context, user, settings, _) {
                                      return _WalletHero(
                                        balance: settings.showBalance
                                            ? user.balance
                                            : '••••••••',
                                        balanceVisible: settings.showBalance,
                                        isLoading:
                                            settings.showBalance &&
                                            (user.isLoading ||
                                                _isManuallyRefreshing),
                                        lastUpdated:
                                            _lastBalanceUpdateTime == null
                                            ? 'Ready when you are'
                                            : 'Updated ${getTimeAgo(_lastBalanceUpdateTime!)}',
                                        onToggleBalance: () =>
                                            settings.setShowBalance(
                                              !settings.showBalance,
                                            ),
                                        onRefresh: _manualRefreshBalance,
                                        onFundWallet: () =>
                                            _push(const FundWalletScreen()),
                                        onHistory: () =>
                                            _push(const TransactionScreen()),
                                        onWalletSummary: () =>
                                            _push(const WalletSummaryScreen()),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 22),

                                const _SectionTitle(
                                  title: 'Everyday services',
                                  subtitle: 'Fast payments, all in one place',
                                ),
                                const SizedBox(height: 14),
                                _ServicesGrid(services: _services()),
                                const SizedBox(height: 30),
                                Consumer<AppDataProvider>(
                                  builder: (context, appData, _) {
                                    final accounts =
                                        appData.data?.user.accounts ?? const [];
                                    if (appData.isLoading && accounts.isEmpty) {
                                      return const _BankAccountsLoading();
                                    }
                                    if (accounts.isEmpty) {
                                      return const SizedBox.shrink();
                                    }
                                    return _BankAccountsSection(
                                      accounts: accounts,
                                      onCopy: _copyAccountNumber,
                                    );
                                  },
                                ),
                                const SizedBox(height: 30),
                                _TransactionsSection(
                                  onViewAll: () =>
                                      _push(const TransactionScreen()),
                                  onOpen: (transaction) => _push(
                                    TransactionReceiptScreen(item: transaction),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _NewHomeScreenState._brand,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: const Text(
            'FS',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Consumer<UserProvider>(
            builder: (context, user, _) {
              final cleanName = user.username.trim().isEmpty
                  ? 'there'
                  : user.username.trim().split(RegExp(r'\s+')).first;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _greeting,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    cleanName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const _NotificationBell(),
      ],
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell();

  void _open(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Consumer<NotificationStore>(
      builder: (context, store, _) => Tooltip(
        message: 'Notifications',
        child: Material(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: () => _open(context),
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.notifications_outlined, size: 22),
                  if (store.unreadCount > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: colors.error,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: colors.surface, width: 1.5),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          store.unreadCount > 99
                              ? '99+'
                              : '${store.unreadCount}',
                          style: TextStyle(
                            color: colors.onError,
                            fontSize: 8,
                            height: 1,
                            fontWeight: FontWeight.w900,
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

class _WalletHero extends StatelessWidget {
  const _WalletHero({
    required this.balance,
    required this.balanceVisible,
    required this.isLoading,
    required this.lastUpdated,
    required this.onToggleBalance,
    required this.onRefresh,
    required this.onFundWallet,
    required this.onHistory,
    required this.onWalletSummary,
  });

  final String balance;
  final bool balanceVisible;
  final bool isLoading;
  final String lastUpdated;
  final VoidCallback onToggleBalance;
  final VoidCallback onRefresh;
  final VoidCallback onFundWallet;
  final VoidCallback onHistory;
  final VoidCallback onWalletSummary;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: balanceVisible
          ? 'Wallet balance $balance'
          : 'Wallet balance hidden',
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              _NewHomeScreenState._brand,
              _NewHomeScreenState._brandBright,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: _NewHomeScreenState._brand.withValues(alpha: 0.22),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            const Positioned.fill(
              child: CustomPaint(painter: _WalletPattern()),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 360;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'AVAILABLE BALANCE',
                              style: TextStyle(
                                color: Color(0xFFDDBFC0),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.25,
                              ),
                            ),
                          ),
                          _HeroIconButton(
                            tooltip: balanceVisible
                                ? 'Hide balance'
                                : 'Show balance',
                            icon: balanceVisible
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            onTap: onToggleBalance,
                          ),
                          const SizedBox(width: 8),
                          _HeroIconButton(
                            tooltip: 'Refresh balance',
                            icon: Icons.refresh_rounded,
                            loading: isLoading,
                            onTap: onRefresh,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: Text(
                          balance,
                          key: ValueKey(balance),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: compact ? 27 : 33,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        lastUpdated,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: _HeroPrimaryButton(
                              onTap: onFundWallet,
                              compact: compact,
                            ),
                          ),
                          const SizedBox(width: 10),
                          _HeroSquareButton(
                            icon: Icons.receipt_long_outlined,
                            tooltip: 'Transaction history',
                            onTap: onHistory,
                          ),
                          const SizedBox(width: 10),
                          _HeroSquareButton(
                            icon: Icons.account_balance_wallet_outlined,
                            tooltip: 'Wallet summary',
                            onTap: onWalletSummary,
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletPattern extends CustomPainter {
  const _WalletPattern();

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.055)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final fillPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(size.width - 12, 12), 92, fillPaint);
    canvas.drawCircle(
      Offset(size.width - 18, 18),
      62,
      linePaint..strokeWidth = 18,
    );
    for (var i = -40.0; i < size.width + size.height; i += 26) {
      canvas.drawLine(
        Offset(i, size.height),
        Offset(i + size.height, 0),
        linePaint..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HeroIconButton extends StatelessWidget {
  const _HeroIconButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.loading = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.1),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: loading ? null : onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 36,
            height: 36,
            child: loading
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(icon, color: Colors.white, size: 18),
          ),
        ),
      ),
    );
  }
}

class _HeroPrimaryButton extends StatelessWidget {
  const _HeroPrimaryButton({required this.onTap, required this.compact});

  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.add_rounded, size: 19),
      label: Text(compact ? 'Add money' : 'Fund wallet'),
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        backgroundColor: Colors.white,
        foregroundColor: _NewHomeScreenState._brand,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
      ),
    );
  }
}

class _HeroSquareButton extends StatelessWidget {
  const _HeroSquareButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onFund,
    required this.onWallet,
    required this.onHistory,
  });

  final VoidCallback onFund;
  final VoidCallback onWallet;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _QuickAction(
            icon: Icons.add_card_rounded,
            label: 'Add money',
            onTap: onFund,
          ),
        ),
        Expanded(
          child: _QuickAction(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Wallet',
            onTap: onWallet,
          ),
        ),
        Expanded(
          child: _QuickAction(
            icon: Icons.history_rounded,
            label: 'History',
            onTap: onHistory,
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 21, color: colors.primary),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.35,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: TextStyle(
            color: colors.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ServiceAction {
  const _ServiceAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}

class _ServicesGrid extends StatelessWidget {
  const _ServicesGrid({required this.services});

  final List<_ServiceAction> services;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 840
            ? 8
            : constraints.maxWidth >= 560
            ? 6
            : constraints.maxWidth < 330
            ? 3
            : 4;
        return GridView.builder(
          itemCount: services.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 106,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemBuilder: (context, index) =>
              _ServiceTile(service: services[index]),
        );
      },
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.service});

  final _ServiceAction service;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      label: service.label,
      child: Material(
        color: dark
            ? colors.surfaceContainerHighest.withValues(alpha: 0.48)
            : const Color(0xFFF9F7F7),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: service.onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 12, 6, 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 43,
                  height: 43,
                  decoration: BoxDecoration(
                    color: service.color.withValues(alpha: dark ? 0.22 : 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(service.icon, color: service.color, size: 21),
                ),
                const SizedBox(height: 9),
                Flexible(
                  child: Text(
                    service.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
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
}

class _BankAccountsSection extends StatelessWidget {
  const _BankAccountsSection({required this.accounts, required this.onCopy});

  final List<BankAccount> accounts;
  final ValueChanged<BankAccount> onCopy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          title: 'Fund by bank transfer',
          subtitle: 'Transfers to these accounts reflect automatically',
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 700;
            final cardWidth = wide
                ? (constraints.maxWidth - 12) / 2
                : (constraints.maxWidth * 0.88).clamp(270.0, 390.0);
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  for (var index = 0; index < accounts.length; index++) ...[
                    SizedBox(
                      width: cardWidth,
                      child: _BankAccountCard(
                        account: accounts[index],
                        onCopy: () => onCopy(accounts[index]),
                      ),
                    ),
                    if (index != accounts.length - 1) const SizedBox(width: 12),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _BankAccountCard extends StatelessWidget {
  const _BankAccountCard({required this.account, required this.onCopy});

  final BankAccount account;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bankName = account.bankName.trim().isEmpty
        ? 'Bank account'
        : account.bankName.trim();
    final accountName = account.accountName.trim().isEmpty
        ? 'FavouriteSub user'
        : account.accountName.trim();

    return Container(
      height: 156,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: dark ? colors.surfaceContainerHigh : const Color(0xFFF3EFEF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: dark ? 0.35 : 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.account_balance_rounded,
                  size: 19,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bankName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      accountName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            account.accountNumber,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Your dedicated account',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              InkWell(
                onTap: onCopy,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.copy_rounded, size: 14, color: colors.primary),
                      const SizedBox(width: 5),
                      Text(
                        'Copy',
                        style: TextStyle(
                          color: colors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BankAccountsLoading extends StatelessWidget {
  const _BankAccountsLoading();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          title: 'Fund by bank transfer',
          subtitle: 'Loading your dedicated accounts',
        ),
        const SizedBox(height: 14),
        Container(
          height: 156,
          width: double.infinity,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
        ),
      ],
    );
  }
}

class _TransactionsSection extends StatelessWidget {
  const _TransactionsSection({required this.onViewAll, required this.onOpen});

  final VoidCallback onViewAll;
  final ValueChanged<TransactionItem> onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Expanded(
              child: _SectionTitle(
                title: 'Recent activity',
                subtitle: 'Your latest payments at a glance',
              ),
            ),
            TextButton(onPressed: onViewAll, child: const Text('See all')),
          ],
        ),
        const SizedBox(height: 12),
        Consumer<TransactionProvider>(
          builder: (context, transactions, _) {
            final items = transactions.items.take(4).toList();
            if (transactions.isLoading && items.isEmpty) {
              return Container(
                height: 116,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
              );
            }
            if (items.isEmpty) return const _EmptyTransactions();

            return Container(
              decoration: BoxDecoration(
                color: colors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: 0.45),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var index = 0; index < items.length; index++) ...[
                    _RecentTransactionTile(
                      item: items[index],
                      onTap: () => onOpen(items[index]),
                    ),
                    if (index != items.length - 1)
                      Divider(
                        height: 1,
                        indent: 72,
                        color: colors.outlineVariant.withValues(alpha: 0.45),
                      ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _RecentTransactionTile extends StatelessWidget {
  const _RecentTransactionTile({required this.item, required this.onTap});

  final TransactionItem item;
  final VoidCallback onTap;

  String get _amount {
    final value = item.amount.trim();
    if (value.startsWith('₦')) return value;
    return '₦$value';
  }

  String get _date {
    final local = item.timestamp.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(local.year, local.month, local.day);
    final difference = today.difference(date).inDays;
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'PM' : 'AM';
    final time = '$hour:$minute $suffix';
    if (difference == 0) return 'Today · $time';
    if (difference == 1) return 'Yesterday · $time';
    return '${local.day}/${local.month}/${local.year} · $time';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final status = item.status.trim().toLowerCase();
    final successful = status == 'successful' || status == 'success';
    final processing = status == 'processing' || status == 'pending';
    final statusColor = successful
        ? const Color(0xFF16835B)
        : processing
        ? const Color(0xFFB66A05)
        : colors.error;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Image.asset(
                  getAssetForTransactionType(item.transactionType, item),
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Icon(
                    Icons.receipt_long_outlined,
                    size: 21,
                    color: colors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      getTransactionDisplayText(item),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _date,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _amount,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        status.isEmpty ? 'Unknown' : _capitalise(status),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _capitalise(String value) {
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }
}

class _EmptyTransactions extends StatelessWidget {
  const _EmptyTransactions();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              Icons.receipt_long_outlined,
              color: colors.primary,
              size: 22,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'No activity yet',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            'Your latest payments will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _Appear extends StatelessWidget {
  const _Appear({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - value)),
          child: child,
        ),
      ),
    );
  }
}
