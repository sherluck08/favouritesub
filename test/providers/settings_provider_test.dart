import 'package:favouritesub/providers/settings_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('biometric payments are enabled when no preference was saved', () async {
    SharedPreferences.setMockInitialValues(const {});
    final settings = SettingsProvider();

    await settings.load();

    expect(settings.biometricPayEnabled, isTrue);
  });

  test('an explicit biometric payment opt-out is preserved', () async {
    SharedPreferences.setMockInitialValues(const {
      'pref_biometric_pay_enabled': false,
    });
    final settings = SettingsProvider();

    await settings.load();

    expect(settings.biometricPayEnabled, isFalse);
  });
}
