import 'package:favouritesub/config/app_theme.dart';
import 'package:favouritesub/providers/app_data_provider.dart';
import 'package:favouritesub/providers/settings_provider.dart';
import 'package:favouritesub/providers/transaction_provider.dart';
import 'package:favouritesub/providers/user_provider.dart';
import 'package:favouritesub/screens/electricity_bill_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    SharedPreferences.setMockInitialValues(const {});

    final settings = SettingsProvider();
    await settings.load();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppDataProvider()),
          ChangeNotifierProvider(create: (_) => TransactionProvider()),
          ChangeNotifierProvider(create: (_) => UserProvider()),
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ElectricityBillScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.clearAllTestValues();
  });

  testWidgets('electricity screen fits a narrow phone', (tester) async {
    await pumpScreen(tester, const Size(320, 700));

    expect(find.text('Electricity'), findsOneWidget);
    expect(find.text('Select electricity provider'), findsOneWidget);
    expect(find.text('Prepaid'), findsOneWidget);
    final exception = tester.takeException();
    expect(
      exception,
      isNull,
      reason: exception is FlutterError
          ? exception.toStringDeep()
          : '$exception',
    );
  });

  testWidgets('electricity screen fits a tablet', (tester) async {
    await pumpScreen(tester, const Size(1024, 900));

    expect(find.text('Choose an amount'), findsOneWidget);
    expect(find.text('₦10,000'), findsOneWidget);
    final exception = tester.takeException();
    expect(
      exception,
      isNull,
      reason: exception is FlutterError
          ? exception.toStringDeep()
          : '$exception',
    );
  });
}
