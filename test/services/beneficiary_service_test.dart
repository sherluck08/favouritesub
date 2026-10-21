import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:favouritesub/services/beneficiary_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'saved_username': 'favourite-user',
    });
  });

  test('stores data and airtime beneficiaries independently', () async {
    await BeneficiaryService.save(
      service: BeneficiaryService.data,
      networkId: 1,
      networkName: 'MTN',
      phone: '0803 123 4567',
    );
    await BeneficiaryService.save(
      service: BeneficiaryService.airtime,
      networkId: 2,
      networkName: 'Glo',
      phone: '08051234567',
    );

    final data = await BeneficiaryService.load(
      service: BeneficiaryService.data,
    );
    final airtime = await BeneficiaryService.load(
      service: BeneficiaryService.airtime,
    );

    expect(data.map((item) => item.phone), ['08031234567']);
    expect(airtime.map((item) => item.phone), ['08051234567']);
  });

  test(
    'moves a repeated beneficiary to the front without duplicating it',
    () async {
      await BeneficiaryService.save(
        service: BeneficiaryService.data,
        networkId: 1,
        networkName: 'MTN',
        phone: '08030000001',
      );
      await BeneficiaryService.save(
        service: BeneficiaryService.data,
        networkId: 2,
        networkName: 'Glo',
        phone: '08050000002',
      );
      final items = await BeneficiaryService.save(
        service: BeneficiaryService.data,
        networkId: 1,
        networkName: 'MTN',
        phone: '08030000001',
      );

      expect(items.length, 2);
      expect(items.first.phone, '08030000001');
    },
  );

  test('keeps only the five most recent beneficiaries', () async {
    for (var index = 0; index < 7; index++) {
      await BeneficiaryService.save(
        service: BeneficiaryService.airtime,
        networkId: 1,
        networkName: 'MTN',
        phone: '0803000000$index',
      );
    }

    final items = await BeneficiaryService.load(
      service: BeneficiaryService.airtime,
    );

    expect(items.length, 5);
    expect(items.first.phone, '08030000006');
    expect(items.last.phone, '08030000002');
  });

  test('does not expose one account history to another account', () async {
    await BeneficiaryService.save(
      service: BeneficiaryService.data,
      networkId: 1,
      networkName: 'MTN',
      phone: '08030000001',
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_username', 'another-user');

    final items = await BeneficiaryService.load(
      service: BeneficiaryService.data,
    );

    expect(items, isEmpty);
  });
}
