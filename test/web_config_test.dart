import 'package:favouritesub/models/app_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads the airtime-to-cash minimum from website configuration', () {
    final config = WebConfig.fromJson({
      'airtime_to_cash_minimum_amount': '1500',
    });

    expect(config.airtimeToCashMinimumAmount, 1500);
  });

  test('uses the safe default when the configured minimum is invalid', () {
    final config = WebConfig.fromJson({'airtime_to_cash_minimum_amount': 0});

    expect(config.airtimeToCashMinimumAmount, 500);
  });
}
