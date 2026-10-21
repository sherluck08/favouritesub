import 'package:favouritesub/config/brand.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/user_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/app_data_provider.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/gradient_button.dart';
import 'login_screen.dart';

import 'security_screen.dart';
import 'edit_profile_screen.dart';
import 'referral_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/delete_account_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _openWhatsApp() async {
    final appData = Provider.of<AppDataProvider>(context, listen: false).data;
    final rawPhone = appData?.webconfig?.supportPhoneNumber?.trim() ?? '';
    final groupLink = appData?.webconfig?.whatsappGroupLink?.trim() ?? '';

    final digits = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');

    Uri? target;
    if (digits.isNotEmpty) {
      target = Uri.parse('https://wa.me/$digits');
    } else if (groupLink.isNotEmpty && groupLink != 'https://wa.me') {
      target = Uri.parse(groupLink);
    }

    if (target != null) {
      final ok = await launchUrl(target, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp')),
        );
      }
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WhatsApp contact not available')),
      );
    }
  }

  Future<void> _openWebsite() async {
    final website = Brand.current.domain;
    if (website.isNotEmpty) {
      await launchUrl(Uri.parse(website), mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openPrivacyPolicy() async {
    final url = Uri.parse('${Brand.current.domain}/privacy-policy');
    final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Privacy Policy')),
      );
    }
  }

  Future<void> _openTermsOfService() async {
    final url = Uri.parse('${Brand.current.domain}/terms-of-service');
    final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Terms of Service')),
      );
    }
  }

  Future<void> _showDeleteAccountDialog() async {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Delete Account?'),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This action is permanent and cannot be undone. Your account and personal data will be deleted.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text('Before deleting your account:'),
              const SizedBox(height: 8),
              const Text('• Withdraw all funds from your wallet'),
              const Text('• Complete all pending transactions'),
              const Text('• Save any important receipts'),
              const SizedBox(height: 16),
              const Text(
                'Enter your password to confirm:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter your password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Password is required';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _deleteAccount(passwordController.text);
    }
    passwordController.dispose();
  }

  Future<void> _deleteAccount(String password) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Deleting account...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final result = await DeleteAccountService.deleteAccount(
        password: password,
      );

      if (!mounted) return;

      // Close loading dialog
      Navigator.of(context).pop();

      if (result.containsKey('success') && result['success'] == true) {
        // Success - show message and logout
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 8),
                Text('Account Deleted'),
              ],
            ),
            content: Text(
              result['message'] ??
                  'Your account has been successfully deleted.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );

        if (!mounted) return;

        // Logout user
        await Provider.of<AuthProvider>(context, listen: false).logout();

        if (!mounted) return;

        // Navigate to login
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const LoginScreen(
              flashMessage: 'Your account has been deleted successfully.',
            ),
          ),
          (route) => false,
        );
      } else {
        // Error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Failed to delete account'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      // Close loading dialog
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final profile = Provider.of<ProfileProvider>(context, listen: false);
    final appData = Provider.of<AppDataProvider>(context, listen: false);
    Future.microtask(() async {
      await Future.wait([settings.load(), profile.load(), appData.load()]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = Provider.of<UserProvider>(context);
    final profile = Provider.of<ProfileProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);

    final fullName = profile.fullName ?? user.username;
    final email = user.username;
    final phone = profile.phone ?? '';
    final address = profile.address ?? '';
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final bottomNavigationClearance = 112.0 + bottomInset;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottomNavigationClearance),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  ProfileAvatar(
                    imageUrl: null,
                    initials: fullName.isNotEmpty ? fullName[0] : 'U',
                    size: 84,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    fullName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(email, style: TextStyle(color: cs.onSurfaceVariant)),
                ],
              ),
            ),

            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Profile'),
                subtitle: Text(
                  phone.isNotEmpty || address.isNotEmpty
                      ? '$phone  •  $address'
                      : 'Tap to edit',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EditProfileScreen(),
                    ),
                  );
                },
              ),
            ),

            Card(
              child: ListTile(
                leading: const Icon(Icons.group_outlined),
                title: const Text('My referral'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ReferralScreen()),
                  );
                },
              ),
            ),

            _sectionLabel(context, 'Appearance'),
            Card(
              child: SwitchListTile.adaptive(
                value: settings.darkMode,
                onChanged: settings.setDarkMode,
                secondary: Icon(
                  settings.darkMode
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  color: cs.primary,
                ),
                title: const Text('Dark mode'),
                subtitle: Text(
                  settings.darkMode
                      ? 'Easier on the eyes in low light'
                      : 'Bright and clean for daytime',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
              ),
            ),

            _sectionLabel(context, 'Settings'),
            Card(
              child: ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('Account security'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SecurityScreen()),
                  );
                },
              ),
            ),

            _sectionLabel(context, 'Help & Support'),
            _supportCard(
              icon: Icons.chat_bubble,
              title: 'WhatsApp',
              color: const Color(0xFF25D366),
              onTap: _openWhatsApp,
            ),
            _supportCard(
              icon: Icons.public,
              title: 'Website',
              color: cs.primary,
              onTap: _openWebsite,
            ),

            _sectionLabel(context, 'Legal'),
            Card(
              child: ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy Policy'),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: _openPrivacyPolicy,
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Terms of Service'),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: _openTermsOfService,
              ),
            ),

            _sectionLabel(context, 'Account'),
            Card(
              child: ListTile(
                leading: Icon(Icons.delete_forever, color: cs.error),
                title: Text(
                  'Delete Account',
                  style: TextStyle(color: cs.error),
                ),
                subtitle: const Text(
                  'Permanently delete your account and data',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showDeleteAccountDialog,
              ),
            ),

            const SizedBox(height: 16),
            Center(
              child: GradientButton(
                label: 'Logout',
                icon: Icons.logout,
                onPressed: () async {
                  await Provider.of<AuthProvider>(
                    context,
                    listen: false,
                  ).logout();
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => const LoginScreen(
                        flashMessage: 'You have successfully logged out',
                      ),
                    ),
                    (route) => false,
                  );
                },
                borderRadius: 10,
                colors: [Colors.redAccent.shade100, Colors.redAccent.shade200],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String label) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

Widget _supportCard({
  required IconData icon,
  required String title,
  required Color color,
  required VoidCallback onTap,
}) {
  return Card(
    child: ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}
