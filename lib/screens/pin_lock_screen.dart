import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/app_data_provider.dart';
import '../services/biometric_service.dart';
import '../services/pin_service.dart';
import '../utils/session_expiry.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';

class PinLockScreen extends StatefulWidget {
  const PinLockScreen({super.key});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen>
    with SingleTickerProviderStateMixin {
  static const _pinLength = 5;

  final _digits = <String>[];

  bool _submitting = false;
  BiometricAvailability _bioStatus = BiometricAvailability.unknown;
  bool _autoPromptedBio = false;
  String? _error;

  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  bool get _bioAvailable => _bioStatus == BiometricAvailability.available;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn));
    _checkBiometrics();
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkBiometrics() async {
    final status = await BiometricService.check();
    if (!mounted) return;
    setState(() => _bioStatus = status);

    // Auto-prompt biometric on first frame when available — most users
    // expect a fingerprint app to immediately ask, not require a tap.
    if (status == BiometricAvailability.available && !_autoPromptedBio) {
      _autoPromptedBio = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _handleBiometric();
      });
    }
  }

  // --------------- key input ---------------

  void _onKey(String key) {
    if (_submitting) return;
    HapticFeedback.lightImpact();

    if (key == 'del') {
      if (_digits.isNotEmpty) setState(() => _digits.removeLast());
      setState(() => _error = null);
      return;
    }
    if (_digits.length >= _pinLength) return;
    setState(() {
      _digits.add(key);
      _error = null;
    });
    if (_digits.length == _pinLength) _verifyPin();
  }

  // --------------- verify PIN ---------------

  Future<void> _verifyPin() async {
    setState(() => _submitting = true);
    try {
      final ok = await PinService.verifyPin(_digits.join());
      if (!mounted) return;
      if (ok) {
        await _loadDataAndNavigate();
      } else {
        _showError('Incorrect passcode');
      }
    } catch (e) {
      if (!mounted) return;
      if (isSessionExpiredError(e)) {
        await _refreshAndRetryPinOrLogout();
      } else {
        _showError('Incorrect passcode');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _refreshAndRetryPinOrLogout() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final refreshed = await auth.biometricLogin();
    if (!mounted) return;
    if (!refreshed) {
      if (isSessionRefreshFailure(auth.error)) {
        await logoutToLogin(context);
      } else {
        _showError(auth.error ?? 'Could not refresh your session.');
      }
      return;
    }

    try {
      final verified = await PinService.verifyPin(_digits.join());
      if (!mounted) return;
      if (verified) {
        await _loadDataAndNavigate();
      } else {
        _showError('Incorrect passcode');
      }
    } catch (e) {
      if (!mounted) return;
      if (isSessionExpiredError(e)) {
        await logoutToLogin(context);
      } else {
        _showError('Incorrect passcode');
      }
    }
  }

  void _showError(String msg) {
    setState(() {
      _error = msg;
      _digits.clear();
    });
    _shakeCtrl.forward(from: 0);
  }

  // --------------- biometric ---------------

  Future<void> _handleBiometric() async {
    if (_submitting) return;
    HapticFeedback.mediumImpact();

    final result = await BiometricService.tryAuthenticate(
      reason: 'Authenticate to unlock',
      biometricOnly: false,
    );
    if (!mounted) return;

    if (result.outcome == BiometricOutcome.notAvailable) {
      // Re-sync our cached status (it may have changed).
      final fresh = await BiometricService.check(forceRefresh: true);
      if (!mounted) return;
      setState(() => _bioStatus = fresh);
      _showBiometricUnavailableSheet(fresh);
      return;
    }
    if (!result.success) {
      // Cancelled, failed, or error — silent for cancel, brief for the rest.
      if (result.outcome == BiometricOutcome.error && result.message != null) {
        _showError(result.message!);
      }
      return;
    }

    setState(() => _submitting = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final ok = await auth.biometricLogin();
      if (ok && auth.token != null && mounted) {
        await _loadDataAndNavigate();
      } else if (mounted) {
        if (isSessionRefreshFailure(auth.error)) {
          await logoutToLogin(context);
          return;
        }
        _showError(auth.error ?? 'Authentication failed');
        setState(() => _submitting = false);
      }
    } catch (e) {
      if (!mounted) return;
      if (isSessionExpiredError(e)) {
        await logoutToLogin(context);
        return;
      }
      _showError('Sign-in failed');
      setState(() => _submitting = false);
    }
  }

  void _showBiometricUnavailableSheet(BiometricAvailability state) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.fingerprint_rounded,
                      size: 42,
                      color: cs.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  BiometricService.titleFor(state),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  BiometricService.messageFor(state),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.5,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('Use my passcode'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --------------- nav helpers ---------------

  Future<void> _loadDataAndNavigate() async {
    try {
      await Future.wait([
        Provider.of<UserProvider>(context, listen: false).loadUserData(),
        Provider.of<TransactionProvider>(context, listen: false).load(),
        Provider.of<AppDataProvider>(context, listen: false).refresh(),
      ]);
    } catch (_) {}
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  Future<void> _signOut() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.logout();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  // --------------- build ---------------

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final safePad = MediaQuery.of(context).padding;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),

            // ---- logo ----
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
              ),
              padding: const EdgeInsets.all(8),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/Logo_2.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ---- heading ----
            Text(
              'Enter Passcode',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 24),

            // ---- PIN dots ----
            AnimatedBuilder(
              animation: _shakeAnim,
              builder: (_, child) {
                final dx =
                    _shakeAnim.value *
                    8 *
                    ((_shakeCtrl.value * 6).toInt().isEven ? 1 : -1);
                return Transform.translate(offset: Offset(dx, 0), child: child);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pinLength, (i) {
                  final filled = i < _digits.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: filled ? 16 : 14,
                    height: filled ? 16 : 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? cs.onSurface : Colors.transparent,
                      border: Border.all(
                        color: filled
                            ? cs.onSurface
                            : cs.onSurfaceVariant.withValues(alpha: 0.35),
                        width: 1.8,
                      ),
                    ),
                  );
                }),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!, style: TextStyle(fontSize: 13, color: cs.error)),
            ],

            if (_submitting) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cs.primary,
                ),
              ),
            ],

            const Spacer(flex: 2),

            // ---- keypad ----
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: _buildKeypad(cs),
            ),

            const Spacer(flex: 1),

            // ---- sign out ----
            GestureDetector(
              onTap: _signOut,
              child: Padding(
                padding: EdgeInsets.only(bottom: safePad.bottom + 12),
                child: Text(
                  'Sign out',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypad(ColorScheme cs) {
    const keys = [
      '1',
      '2',
      '3',
      '4',
      '5',
      '6',
      '7',
      '8',
      '9',
      'bio',
      '0',
      'del',
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.5,
      ),
      itemCount: keys.length,
      itemBuilder: (_, i) {
        final k = keys[i];

        if (k == 'bio') {
          // Always rendered. When unavailable, the icon is dimmed and tapping
          // shows a friendly explanation sheet (no-op platform dialog).
          final available = _bioAvailable;
          return _PadKey(
            onTap: _handleBiometric,
            cs: cs,
            child: Opacity(
              opacity: available ? 1.0 : 0.45,
              child: Icon(
                Icons.fingerprint_rounded,
                size: 32,
                color: available ? cs.primary : cs.onSurfaceVariant,
              ),
            ),
          );
        }

        if (k == 'del') {
          return _PadKey(
            onTap: () => _onKey('del'),
            cs: cs,
            child: Icon(
              Icons.arrow_back_rounded,
              size: 26,
              color: cs.onSurfaceVariant,
            ),
          );
        }

        return _PadKey(
          onTap: () => _onKey(k),
          cs: cs,
          child: Text(
            k,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
            ),
          ),
        );
      },
    );
  }
}

class _PadKey extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  final ColorScheme cs;
  const _PadKey({required this.onTap, required this.child, required this.cs});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Subtle adaptive disc behind each key — invisible-ish in light mode,
    // gives the keypad real "tactile" presence in dark mode.
    final tile = isDark
        ? cs.surfaceContainerHigh.withValues(alpha: 0.55)
        : cs.surfaceContainer.withValues(alpha: 0.45);

    return Center(
      child: AspectRatio(
        aspectRatio: 1,
        child: Material(
          color: tile,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            splashColor: cs.primary.withValues(alpha: 0.18),
            highlightColor: cs.primary.withValues(alpha: 0.08),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
