import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:favouritesub/main.dart';
import 'package:favouritesub/providers/settings_provider.dart';

void main() {
  testWidgets('app starts with its provider tree', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'has_seen_onboarding': true});
    final settings = SettingsProvider();
    await settings.load();

    await tester.pumpWidget(AppBootstrap(settings: settings));

    expect(find.byType(MyApp), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
