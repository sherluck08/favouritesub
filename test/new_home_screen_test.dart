import 'package:favouritesub/config/app_theme.dart';
import 'package:favouritesub/main.dart';
import 'package:favouritesub/providers/app_data_provider.dart';
import 'package:favouritesub/providers/settings_provider.dart';
import 'package:favouritesub/providers/transaction_provider.dart';
import 'package:favouritesub/providers/user_provider.dart';
import 'package:favouritesub/screens/new_home_screen.dart';
import 'package:favouritesub/services/notification_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> pumpDashboard(WidgetTester tester, {required Size size}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    SharedPreferences.setMockInitialValues(const {});

    final settings = SettingsProvider();
    await settings.load();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => UserProvider()),
          ChangeNotifierProvider(create: (_) => AppDataProvider()),
          ChangeNotifierProvider(create: (_) => TransactionProvider()),
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<NotificationStore>.value(
            value: NotificationStore.instance,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          navigatorObservers: [routeObserver],
          home: const NewHomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.clearAllTestValues();
  });

  testWidgets('dashboard renders without overflow on a narrow phone', (
    tester,
  ) async {
    await pumpDashboard(tester, size: const Size(320, 700));

    expect(find.text('Everyday services'), findsOneWidget);
    expect(find.text('Buy data'), findsOneWidget);
    expect(find.text('Airtime to cash'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard renders its wide responsive layout', (tester) async {
    await pumpDashboard(tester, size: const Size(1024, 900));

    expect(find.text('Everyday services'), findsOneWidget);
    expect(find.text('Recent activity'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
