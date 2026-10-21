import 'package:favouritesub/screens/change_pin_screen.dart';
import 'package:favouritesub/screens/reset_lost_pin_screen.dart';
import 'package:favouritesub/screens/delete_account_screen.dart';
import 'package:favouritesub/providers/settings_provider.dart';
import 'package:favouritesub/services/biometric_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'change_password_screen.dart';

class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account security'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Consumer<SettingsProvider>(
            builder: (context, settings, _) => Card(
              elevation: 0,
              child: SwitchListTile.adaptive(
                secondary: const Icon(Icons.fingerprint_rounded),
                title: const Text('Pay with fingerprint'),
                subtitle: const Text(
                  'Confirm purchases securely with your fingerprint or face',
                ),
                value: settings.biometricPayEnabled,
                onChanged: (enabled) =>
                    _setBiometricPayments(context, settings, enabled),
              ),
            ),
          ),
          _navTile(
            context,
            Icons.lock_reset,
            'Change password',
            const ChangePasswordScreen(),
          ),
          _navTile(
            context,
            Icons.lock_reset,
            'Change Pin',
            const ChangePinScreen(),
          ),
          _navTile(
            context,
            Icons.cached,
            'Reset Lost pin',
            const ResetPinLostPinScreen(),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              'Danger Zone',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          _navTile(
            context,
            Icons.delete_forever,
            'Delete Account',
            const DeleteAccountScreen(),
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Future<void> _setBiometricPayments(
    BuildContext context,
    SettingsProvider settings,
    bool enabled,
  ) async {
    if (!enabled) {
      await settings.setBiometricPayEnabled(false);
      return;
    }

    final availability = await BiometricService.check(forceRefresh: true);
    if (!context.mounted) return;
    if (availability == BiometricAvailability.available) {
      await settings.setBiometricPayEnabled(true);
      return;
    }

    await settings.setBiometricPayEnabled(false);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(BiometricService.messageFor(availability))),
    );
  }

  Widget _navTile(
    BuildContext context,
    IconData icon,
    String title,
    Widget? page, {
    bool isDestructive = false,
  }) {
    return Card(
      elevation: 0,
      color: isDestructive ? Colors.red.shade50 : null,
      child: ListTile(
        leading: Icon(icon, color: isDestructive ? Colors.red : null),
        title: Text(
          title,
          style: TextStyle(color: isDestructive ? Colors.red.shade900 : null),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: isDestructive ? Colors.red : null,
        ),
        onTap: page == null
            ? null
            : () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => page),
              ),
      ),
    );
  }
}
