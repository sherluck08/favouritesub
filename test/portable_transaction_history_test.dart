import 'package:favouritesub/widgets/portable_transaction_history.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Entry {
  const _Entry({
    required this.title,
    required this.recipient,
    required this.amount,
    required this.date,
    required this.status,
  });

  final String title;
  final String recipient;
  final String amount;
  final DateTime date;
  final TransactionHistoryStatus status;
}

void main() {
  final entries = [
    _Entry(
      title: 'MTN Data',
      recipient: '08012345678',
      amount: '₦1,000',
      date: DateTime.now(),
      status: TransactionHistoryStatus.successful,
    ),
    _Entry(
      title: 'Airtel Airtime',
      recipient: '09012345678',
      amount: '₦500',
      date: DateTime.now().subtract(const Duration(days: 1)),
      status: TransactionHistoryStatus.processing,
    ),
  ];

  Future<void> pumpHistory(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.red),
        home: Scaffold(
          body: PortableTransactionHistory<_Entry>(
            items: entries,
            titleOf: (item) => item.title,
            subtitleOf: (item) => item.recipient,
            amountOf: (item) => item.amount,
            dateOf: (item) => item.date,
            statusOf: (item) => item.status,
            statusLabelOf: (item) => item.status.name,
            searchTextOf: (item) => '${item.title} ${item.recipient}',
            onItemTap: (_) {},
            onRefresh: () async {},
            summaryValue: '₦1,000',
            filters: const [
              TransactionHistoryFilter(
                id: 'data',
                label: 'Data',
                icon: Icons.wifi_rounded,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.clearAllTestValues();
  });

  testWidgets('fits a narrow phone and exposes key history controls', (
    tester,
  ) async {
    await pumpHistory(tester, const Size(320, 700));

    expect(find.text('Successful volume'), findsOneWidget);
    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Data'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('searches using the host app mapper', (tester) async {
    await pumpHistory(tester, const Size(420, 820));

    await tester.enterText(find.byType(TextField), 'airtel');
    await tester.pump();

    expect(find.text('Airtel Airtime'), findsOneWidget);
    expect(find.text('MTN Data'), findsNothing);
    expect(find.text('Search results'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
