import 'dart:async';

import 'package:favouritesub/services/notification_store.dart';
import 'package:favouritesub/services/push_notification_service.dart';
import 'package:favouritesub/services/play_store_update_service.dart';
import 'package:favouritesub/services/session_http.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:favouritesub/screens/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:favouritesub/screens/onboarding_screen.dart';
import 'package:favouritesub/screens/splash_screen.dart';
import 'package:provider/provider.dart';
import 'package:favouritesub/config/app_theme.dart';
import 'package:favouritesub/config/brand.dart';
import 'package:favouritesub/providers/auth_provider.dart';
import 'package:favouritesub/providers/plan_provider.dart';
import 'package:favouritesub/providers/balance_provider.dart';
import 'package:favouritesub/providers/user_provider.dart';
import 'package:favouritesub/providers/app_config_provider.dart';
import 'package:favouritesub/providers/app_data_provider.dart';
import 'package:favouritesub/providers/transaction_provider.dart';
import 'package:favouritesub/providers/settings_provider.dart';
import 'package:favouritesub/providers/profile_provider.dart';
import 'package:favouritesub/providers/wallet_summary_provider.dart';
import 'package:favouritesub/providers/recharge_pin_provider.dart';
import 'package:favouritesub/providers/result_checker_provider.dart';
import 'package:favouritesub/providers/locale_provider.dart';
import 'package:favouritesub/screens/pin_lock_screen.dart';

final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();
final rootNavigatorKey = GlobalKey<NavigatorState>();
final rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SessionCoordinator.instance.configure(
    navigatorKey: rootNavigatorKey,
    messengerKey: rootMessengerKey,
  );
  final settings = SettingsProvider();
  runApp(AppBootstrap(settings: settings));

  // Do not hold the native launch screen while plugins, Firebase, notification
  // permissions, token registration, and backend sync are starting. Flutter can
  // paint the first frame immediately and finish these tasks in the background.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_initializeAppServices(settings));
  });
}

Future<void> _initializeAppServices(SettingsProvider settings) async {
  try {
    await settings.load();
  } catch (error) {
    debugPrint('Could not load app settings: $error');
  }

  try {
    await NotificationStore.instance.ensureLoaded();
    unawaited(NotificationStore.instance.syncFromBackend());
  } catch (error) {
    debugPrint('Could not load notification inbox: $error');
  }

  try {
    await Firebase.initializeApp();
    await PushNotificationService.instance.initialize();
  } catch (error) {
    // Push notifications are optional at launch; the rest of the app must stay
    // usable if Google Play services or the network is temporarily unavailable.
    debugPrint('Could not initialize push notifications: $error');
  }
}

class AppBootstrap extends StatelessWidget {
  final SettingsProvider settings;

  const AppBootstrap({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => PlanProvider()),
        ChangeNotifierProvider(create: (_) => BalanceProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => AppConfigProvider()),
        ChangeNotifierProvider(create: (_) => AppDataProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => WalletSummaryProvider()),
        ChangeNotifierProvider(create: (_) => RechargePinProvider()),
        ChangeNotifierProvider(create: (_) => ResultCheckerProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider<NotificationStore>.value(
          value: NotificationStore.instance,
        ),
      ],
      child: const MyApp(),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Provider.of<SettingsProvider>(context).darkMode;
    return MaterialApp(
      title: Brand.current.appName,
      debugShowCheckedModeBanner: false,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      navigatorKey: rootNavigatorKey,
      scaffoldMessengerKey: rootMessengerKey,
      home: const _StartupRouter(),
      navigatorObservers: [routeObserver],
    );
  }
}

class _StartupRouter extends StatefulWidget {
  const _StartupRouter();
  @override
  State<_StartupRouter> createState() => _StartupRouterState();
}

class _StartupRouterState extends State<_StartupRouter> {
  Widget? _screen;
  bool _updateCheckQueued = false;

  @override
  void initState() {
    super.initState();
    _decideStart();
  }

  Future<void> _decideStart() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
    final access = prefs.getString('access_token');

    if (access != null && access.isNotEmpty) {
      // Keep an existing session protected by the user's transaction PIN or
      // device biometrics before loading any account data.
      _screen = const PinLockScreen();
    } else {
      _screen = hasSeenOnboarding
          ? const LoginScreen()
          : const OnboardingGate();
    }
    if (mounted) setState(() {});
    _queueUpdateCheck();
  }

  void _queueUpdateCheck() {
    if (_updateCheckQueued) return;
    _updateCheckQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        PlayStoreUpdateService.instance.checkForUpdate(
          messenger: rootMessengerKey.currentState,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_screen != null) return _screen!;
    return const SplashScreen();
  }
}

class OnboardingGate extends StatelessWidget {
  const OnboardingGate({super.key});

  Future<void> _markSeen(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    if (!context.mounted) return;
    // Navigate to onboarding, which can in turn go to login or signup
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Immediately mark seen and show onboarding; keeps logic centralized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markSeen(context);
    });
    return const Scaffold(body: SizedBox());
  }
}
