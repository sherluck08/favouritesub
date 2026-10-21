import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:favouritesub/utils/utils.dart';
import 'package:provider/provider.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:favouritesub/providers/auth_provider.dart';
import 'package:favouritesub/screens/dashboard_screen.dart';
import 'package:favouritesub/providers/user_provider.dart';
import 'package:favouritesub/screens/password_reset_screen.dart';
import 'package:favouritesub/providers/transaction_provider.dart';
import 'package:favouritesub/providers/app_data_provider.dart';
import 'package:favouritesub/providers/locale_provider.dart';
import 'package:local_auth/local_auth.dart';
import 'package:favouritesub/screens/signup_screen.dart';
import 'package:favouritesub/config/brand.dart';
import 'package:favouritesub/widgets/branded_loader.dart';
import 'package:favouritesub/widgets/whatsapp_support_fabs.dart';

class LoginScreen extends StatefulWidget {
  final String? flashMessage;

  const LoginScreen({super.key, this.flashMessage});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _localAuth = LocalAuthentication();

  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _hidePassword = true;
  bool _hasSavedUsername = false;
  String? _savedUsername;
  bool _submitted = false;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeIn = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    _checkSavedUsername();

    if (widget.flashMessage != null && widget.flashMessage!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.flashMessage!),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      });
    }
  }

  Future<void> _checkSavedUsername() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final username = await auth.getSavedUsername();
    if (username != null && username.isNotEmpty) {
      setState(() {
        _hasSavedUsername = true;
        _savedUsername = username;
        _usernameCtrl.text = username;
      });
    }
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() => _submitted = true);

    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (username.isEmpty || password.isEmpty) return;

    context.loaderOverlay.show();
    final auth = context.read<AuthProvider>();
    try {
      await auth.login(username, password);
    } finally {
      if (mounted) context.loaderOverlay.hide();
    }

    if (!mounted) return;
    if (auth.token != null) {
      _hydrateDashboardInBackground();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const DashboardScreen()),
      );
      return;
    }
    if (auth.error != null) {
      Utils.showErrorModal(auth.error!, context);
    }
  }

  void _hydrateDashboardInBackground() {
    final user = context.read<UserProvider>();
    final transactions = context.read<TransactionProvider>();
    final appData = context.read<AppDataProvider>();
    unawaited(_hydrateDashboard(user, transactions, appData));
  }

  Future<void> _hydrateDashboard(
    UserProvider user,
    TransactionProvider transactions,
    AppDataProvider appData,
  ) async {
    try {
      await Future.wait([
        user.loadUserData(),
        transactions.load(),
        appData.refresh(),
      ]).timeout(const Duration(seconds: 20));
    } catch (error) {
      if (kDebugMode) debugPrint('Dashboard background load: $error');
    }
  }

  Future<void> _handleBiometricLogin() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      final biometrics = await _localAuth.getAvailableBiometrics();

      if (!isAvailable || biometrics.isEmpty) {
        if (mounted) {
          Utils.showErrorModal(
            'Biometric authentication is not available on this device',
            context,
          );
        }
        return;
      }

      final didAuth = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to login with your biometric',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );

      if (!mounted) return;
      if (didAuth) {
        context.loaderOverlay.show();
        final auth = context.read<AuthProvider>();
        bool success;
        try {
          success = await auth.biometricLogin();
        } finally {
          if (mounted) context.loaderOverlay.hide();
        }

        if (!mounted) return;
        if (success && auth.token != null) {
          _hydrateDashboardInBackground();
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(builder: (_) => const DashboardScreen()),
          );
        } else {
          if (auth.error != null) {
            Utils.showErrorModal(auth.error!, context);
          }
        }
      } else {
        if (mounted) {
          Utils.showErrorModal(
            'Biometric authentication was cancelled or failed',
            context,
          );
        }
      }
    } catch (e) {
      debugPrint('Biometric login error: $e');
      if (mounted) {
        String msg = 'Biometric authentication failed';
        if (e.toString().contains('no_fragment_activity')) {
          msg = 'Please restart the app to enable biometric authentication';
        } else if (e.toString().contains('NotAvailable')) {
          msg = 'Biometric authentication is not available on this device';
        } else if (e.toString().contains('NotEnrolled')) {
          msg =
              'No biometric data found. Please set up biometric authentication in device settings';
        }
        Utils.showErrorModal(msg, context);
      }
    }
  }

  Future<void> _handleLogout() async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      await auth.logout();
      setState(() {
        _hasSavedUsername = false;
        _savedUsername = null;
        _usernameCtrl.clear();
        _passwordCtrl.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Logged out successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Utils.showErrorModal('Logout failed: ${e.toString()}', context);
      }
    }
  }

  void _showLanguageSheet() {
    final locale = Provider.of<LocaleProvider>(context, listen: false);
    String selected = locale.langCode;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final loc = Provider.of<LocaleProvider>(ctx, listen: false);
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        loc.tr('select_language'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: const Icon(Icons.close, size: 24),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ...LocaleProvider.supportedCodes.map((code) {
                    final isSelected = selected == code;
                    return InkWell(
                      onTap: () => setSheetState(() => selected = code),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          children: [
                            Text(
                              '${LocaleProvider.nameFor(code)} ${LocaleProvider.flagFor(code)}',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const Spacer(),
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Theme.of(ctx).colorScheme.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: isSelected
                                      ? Theme.of(ctx).colorScheme.primary
                                      : Colors.grey.shade400,
                                  width: 2,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check,
                                      size: 16,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        loc.setLocale(selected);
                        Navigator.pop(ctx);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(ctx).colorScheme.primary,
                        foregroundColor: Theme.of(ctx).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: Text(loc.tr('save')),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required ColorScheme cs,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: cs.onSurfaceVariant.withValues(alpha: 0.45),
        fontSize: 15,
        fontWeight: FontWeight.w400,
      ),
      filled: true,
      fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.25),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.primary, width: 1.5),
      ),
      suffixIcon: suffixIcon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mq = MediaQuery.of(context);
    final bottomInset = mq.viewInsets.bottom;
    final locale = Provider.of<LocaleProvider>(context);

    final usernameEmpty = _submitted && _usernameCtrl.text.trim().isEmpty;
    final passwordEmpty = _submitted && _passwordCtrl.text.isEmpty;

    return Scaffold(
      backgroundColor: cs.surface,
      floatingActionButton: const WhatsAppSupportFabs(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: LoaderOverlay(
        overlayColor: cs.surface.withValues(alpha: 0.85),
        overlayWidgetBuilder: (_) =>
            BrandedLoader(message: locale.tr('logging_in')),
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: 24 + bottomInset),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 24 - bottomInset,
                    ),
                    child: FadeTransition(
                      opacity: _fadeIn,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 12),

                            // ── top bar: logo + language ──
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Image.asset(
                                      'assets/images/Logo_2.png',
                                      width: 36,
                                      height: 36,
                                      fit: BoxFit.contain,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      Brand.current.appName.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: cs.onSurface,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                                InkWell(
                                  onTap: _showLanguageSheet,
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: cs.outlineVariant.withValues(
                                          alpha: 0.35,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          locale.langFlag,
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          locale.langCode.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: cs.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: _hasSavedUsername ? 48 : 56),

                            // ── heading ──
                            if (_hasSavedUsername) ...[
                              Text(
                                locale.tr('welcome_back_user'),
                                style: TextStyle(
                                  fontSize: 15,
                                  color: cs.onSurfaceVariant,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _savedUsername ?? '',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: cs.onSurface,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ] else ...[
                              Text(
                                locale.tr('welcome_back'),
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: cs.onSurface,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                locale.tr('sign_in_subtitle'),
                                style: TextStyle(
                                  fontSize: 15,
                                  color: cs.onSurfaceVariant,
                                  height: 1.4,
                                ),
                              ),
                            ],

                            const SizedBox(height: 40),

                            // ── form ──
                            if (!_hasSavedUsername) ...[
                              Text(
                                locale.tr('username'),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurface,
                                  letterSpacing: 0.1,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _usernameCtrl,
                                focusNode: _usernameFocus,
                                textInputAction: TextInputAction.next,
                                onSubmitted: (_) =>
                                    _passwordFocus.requestFocus(),
                                onChanged: (_) {
                                  if (_submitted) setState(() {});
                                },
                                decoration: _inputDecoration(
                                  hint: locale.tr('username'),
                                  cs: cs,
                                ),
                              ),
                              if (usernameEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  locale.tr('username_error'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.error,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),
                            ],

                            Text(
                              locale.tr('password'),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                                letterSpacing: 0.1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _passwordCtrl,
                              focusNode: _passwordFocus,
                              obscureText: _hidePassword,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) {
                                FocusScope.of(context).unfocus();
                                _handleLogin();
                              },
                              onChanged: (_) {
                                if (_submitted) setState(() {});
                              },
                              decoration: _inputDecoration(
                                hint: locale.tr('password'),
                                cs: cs,
                                suffixIcon: GestureDetector(
                                  onTap: () => setState(
                                    () => _hidePassword = !_hidePassword,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: Icon(
                                      _hidePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      size: 20,
                                      color: cs.onSurfaceVariant.withValues(
                                        alpha: 0.6,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (passwordEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                locale.tr('password_error'),
                                style: TextStyle(fontSize: 12, color: cs.error),
                              ),
                            ],

                            const SizedBox(height: 8),

                            Align(
                              alignment: Alignment.centerRight,
                              child: GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const PasswordResetScreen(),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Text(
                                    locale.tr('forget_password'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: cs.primary,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 28),

                            // ── login button ──
                            Consumer<AuthProvider>(
                              builder: (context, auth, _) {
                                return SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: FilledButton(
                                    onPressed: auth.isLoading
                                        ? null
                                        : () {
                                            FocusScope.of(context).unfocus();
                                            _handleLogin();
                                          },
                                    style: FilledButton.styleFrom(
                                      backgroundColor: cs.primary,
                                      foregroundColor: cs.onPrimary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      textStyle: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    child: Text(locale.tr('sign_in')),
                                  ),
                                );
                              },
                            ),

                            // ── biometric / switch account ──
                            if (_hasSavedUsername) ...[
                              const SizedBox(height: 32),
                              Row(
                                children: [
                                  Expanded(
                                    child: Divider(
                                      color: cs.outlineVariant.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Text(
                                      locale.tr('or_continue_with'),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: cs.onSurfaceVariant.withValues(
                                          alpha: 0.7,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(
                                      color: cs.outlineVariant.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              Center(
                                child: GestureDetector(
                                  onTap: _handleBiometricLogin,
                                  child: Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: cs.outlineVariant.withValues(
                                          alpha: 0.35,
                                        ),
                                      ),
                                      color: cs.primary.withValues(alpha: 0.04),
                                    ),
                                    child: Icon(
                                      Icons.fingerprint_rounded,
                                      size: 32,
                                      color: cs.primary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Center(
                                child: Text(
                                  locale.tr('biometrics'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Center(
                                child: GestureDetector(
                                  onTap: _handleLogout,
                                  child: Text(
                                    '${locale.tr('not_user')} $_savedUsername? ${locale.tr('switch_account')}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: cs.error,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 40),

                            // ── sign up link ──
                            Center(
                              child: Text.rich(
                                TextSpan(
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: cs.onSurfaceVariant,
                                  ),
                                  children: [
                                    TextSpan(text: locale.tr('no_account')),
                                    TextSpan(
                                      text: locale.tr('sign_up'),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: cs.primary,
                                      ),
                                      recognizer: TapGestureRecognizer()
                                        ..onTap = () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const SignupScreen(),
                                          ),
                                        ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
