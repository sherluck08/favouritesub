import 'package:favouritesub/config/app_theme.dart';
import 'package:favouritesub/models/referral_member.dart';
import 'package:favouritesub/providers/app_data_provider.dart';
import 'package:favouritesub/screens/referral_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.clearAllTestValues();
  });

  testWidgets('referral screen renders a real referral on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppDataProvider(),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: ReferralScreen(
            loadReferrals: () async => [
              ReferralMember(
                id: 1,
                username: 'new_customer',
                joinedAt: DateTime(2026, 10, 20),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('My referrals'), findsOneWidget);
    expect(find.text('1 total'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -650));
    await tester.pumpAndSettle();
    expect(find.text('new_customer'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
