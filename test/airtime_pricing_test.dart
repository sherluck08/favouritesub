import 'package:favouritesub/models/app_data.dart';
import 'package:favouritesub/models/transaction_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('quotes a tier-specific airtime discount from API percentages', () {
    final pricing = AirtimePricing.fromJson({
      'MTN': {'VTU': 99, 'Share and Sell': 98},
    });

    final quote = pricing.quote(
      network: 'mtn',
      airtimeType: 'VTU',
      faceValue: 100,
    );

    expect(quote.discountPercent, 1);
    expect(quote.discountAmount, 1);
    expect(quote.amountToPay, 99);
  });

  test('accepts legacy multiplier rates when ported to another project', () {
    final pricing = AirtimePricing.fromJson({
      'AIRTEL': {'VTU': 0.97},
    });

    final quote = pricing.quote(
      network: 'Airtel',
      airtimeType: 'vtu',
      faceValue: 1000,
    );

    expect(quote.amountToPay, 970);
  });

  test('reads discount percentages from the favouritesub network API', () {
    final pricing = AirtimePricing.fromAppData({
      'network': [
        {
          'name': 'GLO',
          'topup_percentage': {'vtu_percentage': 1, 'sns_percentage': 2},
        },
      ],
    });

    final quote = pricing.quote(
      network: 'GLO',
      airtimeType: 'Share and Sell',
      faceValue: 500,
    );

    expect(quote.discountPercent, 2);
    expect(quote.amountToPay, 490);
  });

  test('airtime receipt keeps face value and actual paid amount separate', () {
    final item = TransactionItem.fromJson({
      'id': 7,
      'service': 'Airtime',
      'network_name': 'MTN',
      'amount': '100.00',
      'paid_amount': '99.00',
      'Status': 'successful',
      'mobile_number': '08030000000',
    });

    expect(item.transactionType, TransactionType.airtime);
    expect(item.amount, '100.00');
    expect(item.receiptAmount, '99.00');
    expect(item.airtimeDiscountAmount, 1);
  });
}
