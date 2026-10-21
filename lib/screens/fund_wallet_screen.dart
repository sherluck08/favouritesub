import 'package:flutter/material.dart';
import 'package:favouritesub/screens/manual_funding_screen.dart';
import 'package:provider/provider.dart';
import 'package:favouritesub/providers/app_data_provider.dart';

import 'funding/automated_funding_screen.dart';

class FundWalletScreen extends StatelessWidget {
  const FundWalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context);

    if (!appData.isLoading) {
      Future.microtask(
        () => Provider.of<AppDataProvider>(context, listen: false).refresh(),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Fund Wallet'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            tileColor: Colors.white,
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.account_balance,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            title: const Text(
              'Automated Funding',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              'Transfer to your dedicated account. Instant auto-credit 24/7.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AutomatedFundingScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            tileColor: Colors.white,
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.account_balance,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            title: const Text(
              'Manual Funding',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              'Transfer to admin account. Instant manual-credit 24/7.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManualFundingScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}
