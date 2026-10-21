import 'package:flutter/material.dart';
import 'package:favouritesub/models/app_data.dart';
import 'package:favouritesub/providers/app_data_provider.dart';
import 'package:favouritesub/widgets/bank_card.dart';
import 'package:provider/provider.dart';

class ManualFundingScreen extends StatefulWidget {
  const ManualFundingScreen({super.key});

  @override
  State<ManualFundingScreen> createState() => _ManualFundingScreenState();
}

class _ManualFundingScreenState extends State<ManualFundingScreen> {
  @override
  void initState() {
    super.initState();

    Future.microtask(
      () => Provider.of<AppDataProvider>(context, listen: false).refresh(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context, listen: true);

    final banks = appData.data?.banks ?? const <BankAccount>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Manual Funding'), centerTitle: true),
      body: Builder(
        builder: (context) {
          if (banks.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.account_balance,
                      size: 48,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No manu account found',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: banks.length,
            itemBuilder: (context, index) {
              final bank = banks[index];
              return BankCard(bank: bank);
            },
          );
        },
      ),
    );
  }
}
