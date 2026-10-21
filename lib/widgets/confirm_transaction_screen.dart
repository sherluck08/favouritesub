import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/biometric_service.dart';
import '../services/pin_service.dart';
import '../services/transaction_notifier.dart';
import '../providers/settings_provider.dart';
import '../providers/user_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/app_data_provider.dart';
import '../screens/dashboard_screen.dart';
import '../screens/transaction_screen.dart';
import '../utils/friendly_error.dart';
import '../utils/session_expiry.dart';

// ====================================================================
// Data model for transaction details
// ====================================================================

class TxDetail {
  final String label;
  final String value;
  const TxDetail(this.label, this.value);
}

// ====================================================================
// Main entry point — push this as a full-screen route
// ====================================================================

/// Navigates to the confirm → PIN → processing → result flow.
///
/// [networkImage] : widget for the network logo (use Image.asset)
/// [details]      : list of label/value pairs (To, Amount, Network, etc.)
/// [onExecute]    : the actual purchase call — should return a result map
/// [successTitle] : e.g. "Transaction Successful!"
/// [successMsg]   : e.g. "You've successfully purchased 08067… for MTN"
Future<void> pushConfirmTransaction(
  BuildContext context, {
  required Widget networkImage,
  required List<TxDetail> details,
  required Future<Map<String, dynamic>> Function() onExecute,
  String successTitle = 'Transaction Successful!',
  String Function(Map<String, dynamic> res)? buildSuccessMsg,
  String? successMsg,
  TxInfo? notify,
}) {
  return Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => _ConfirmScreen(
        networkImage: networkImage,
        details: details,
        onExecute: onExecute,
        successTitle: successTitle,
        successMsg: successMsg,
        buildSuccessMsg: buildSuccessMsg,
        notify: notify,
      ),
    ),
  );
}

// ====================================================================
// Step 1 — Confirm screen (shows details + "Tap to Confirm")
// ====================================================================

class _ConfirmScreen extends StatelessWidget {
  final Widget networkImage;
  final List<TxDetail> details;
  final Future<Map<String, dynamic>> Function() onExecute;
  final String successTitle;
  final String? successMsg;
  final String Function(Map<String, dynamic>)? buildSuccessMsg;
  final TxInfo? notify;

  const _ConfirmScreen({
    required this.networkImage,
    required this.details,
    required this.onExecute,
    this.successTitle = 'Transaction Successful!',
    this.successMsg,
    this.buildSuccessMsg,
    this.notify,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cs.onPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          'Confirm',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: cs.onPrimary,
          ),
        ),
      ),
      body: Column(
        children: [
          const Spacer(flex: 1),

          // --- network logo ---
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(width: 72, height: 72, child: networkImage),
            ),
          ),
          const SizedBox(height: 24),

          // --- details card ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < details.length; i++) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${details[i].label}:',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Flexible(
                          child: Text(
                            details[i].value,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (i < details.length - 1) const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),

          const Spacer(flex: 2),

          // --- tap to confirm + pin dots ---
          Text(
            'Tap to Confirm your Transaction',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              5,
              (_) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 200,
            child: FilledButton(
              onPressed: () => _openPinSheet(context),
              style: FilledButton.styleFrom(
                backgroundColor: cs.onSurface,
                foregroundColor: cs.surface,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Confirm',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),

          const Spacer(flex: 2),
        ],
      ),
    );
  }

  void _openPinSheet(BuildContext context) {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TransactionPinSheet(),
    ).then((success) {
      if (success == true && context.mounted) {
        _runPurchase(context);
      }
    });
  }

  void _runPurchase(BuildContext ctx) {
    Navigator.pushReplacement(
      ctx,
      MaterialPageRoute(
        builder: (_) => _ProcessingScreen(
          networkImage: networkImage,
          details: details,
          onExecute: onExecute,
          successTitle: successTitle,
          successMsg: successMsg,
          buildSuccessMsg: buildSuccessMsg,
          notify: notify,
        ),
      ),
    );
  }
}

// ====================================================================
// Step 2 — Transaction PIN bottom sheet (clean minimal design)
// ====================================================================

class _TransactionPinSheet extends StatefulWidget {
  @override
  State<_TransactionPinSheet> createState() => _TransactionPinSheetState();
}

class _TransactionPinSheetState extends State<_TransactionPinSheet> {
  final _digits = <String>[];
  bool _submitting = false;
  BiometricAvailability _bioStatus = BiometricAvailability.unknown;
  bool _autoPrompted = false;
  String? _error;

  bool get _bioAvailable => _bioStatus == BiometricAvailability.available;

  bool get _allowBiometric =>
      Provider.of<SettingsProvider>(context, listen: false).biometricPayEnabled;

  @override
  void initState() {
    super.initState();
    _initBiometrics();
  }

  Future<void> _initBiometrics() async {
    final status = await BiometricService.check();
    if (!mounted) return;
    setState(() => _bioStatus = status);

    if (_allowBiometric &&
        status == BiometricAvailability.available &&
        !_autoPrompted) {
      _autoPrompted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _handleBiometric();
      });
    }
  }

  void _onKey(String key) {
    if (_submitting) return;
    HapticFeedback.lightImpact();
    if (key == 'del') {
      if (_digits.isNotEmpty) {
        setState(() {
          _digits.removeLast();
          _error = null;
        });
      }
      return;
    }
    if (_digits.length >= 5) return;
    setState(() {
      _digits.add(key);
      _error = null;
    });
    if (_digits.length == 5) _submit();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final ok = await PinService.verifyPin(_digits.join());
      if (!mounted) return;
      if (ok) {
        Navigator.pop(context, true);
        return;
      }
      setState(() {
        _error = 'Incorrect PIN';
        _digits.clear();
      });
    } catch (e) {
      if (!mounted) return;
      if (isSessionExpiredError(e)) {
        await logoutToLogin(context);
        return;
      }
      setState(() {
        _error = 'Incorrect PIN';
        _digits.clear();
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _handleBiometric() async {
    if (_submitting) return;

    if (!_allowBiometric) {
      _showFriendlySheet(
        title: 'Pay with fingerprint is off',
        body:
            "Turn on Pay with fingerprint in your account settings to confirm transactions with biometrics.",
      );
      return;
    }

    if (!_bioAvailable) {
      final fresh = await BiometricService.check(forceRefresh: true);
      if (!mounted) return;
      setState(() => _bioStatus = fresh);
      if (fresh != BiometricAvailability.available) {
        _showFriendlySheet(
          title: BiometricService.titleFor(fresh),
          body: BiometricService.messageFor(fresh),
        );
        return;
      }
    }

    HapticFeedback.mediumImpact();
    final result = await BiometricService.tryAuthenticate(
      reason: 'Confirm your transaction',
    );
    if (!mounted) return;
    if (result.success) {
      Navigator.pop(context, true);
    } else if (!result.cancelled && result.message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message!)));
    }
  }

  void _showFriendlySheet({required String title, required String body}) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
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
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.fingerprint_rounded,
                    size: 38,
                    color: cs.primary,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                body,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.of(sheetCtx).pop(),
                child: const Text('Use my PIN instead'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Transaction Pin',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 16),

          // dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final filled = i < _digits.length;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: filled ? 16 : 14,
                height: filled ? 16 : 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: filled ? cs.onSurface : Colors.transparent,
                  border: Border.all(
                    color: filled
                        ? cs.onSurface
                        : cs.onSurfaceVariant.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                ),
              );
            }),
          ),

          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: TextStyle(fontSize: 13, color: cs.error)),
          ],

          if (_submitting) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: cs.primary,
              ),
            ),
          ],

          const SizedBox(height: 20),

          // keypad
          _buildKeypad(cs),
          const SizedBox(height: 8),
        ],
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
      'del',
      '0',
      'bio',
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: 1.7,
      ),
      itemCount: keys.length,
      itemBuilder: (_, i) {
        final k = keys[i];
        if (k == 'del') {
          return _PadKey(
            onTap: () => _onKey('del'),
            child: Icon(
              Icons.arrow_back_rounded,
              size: 24,
              color: cs.onSurfaceVariant,
            ),
          );
        }
        if (k == 'bio') {
          final enabled = _allowBiometric && _bioAvailable;
          return _PadKey(
            onTap: _handleBiometric,
            child: Opacity(
              opacity: enabled ? 1.0 : 0.4,
              child: Icon(
                Icons.fingerprint_rounded,
                size: 30,
                color: enabled ? cs.primary : cs.onSurfaceVariant,
              ),
            ),
          );
        }
        return _PadKey(
          onTap: () => _onKey(k),
          child: Text(
            k,
            style: TextStyle(
              fontSize: 26,
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
  const _PadKey({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
        child: Center(child: child),
      ),
    );
  }
}

// ====================================================================
// Step 3 — Processing screen (branded spinner over confirm details)
// ====================================================================

class _ProcessingScreen extends StatefulWidget {
  final Widget networkImage;
  final List<TxDetail> details;
  final Future<Map<String, dynamic>> Function() onExecute;
  final String successTitle;
  final String? successMsg;
  final String Function(Map<String, dynamic>)? buildSuccessMsg;
  final TxInfo? notify;

  const _ProcessingScreen({
    required this.networkImage,
    required this.details,
    required this.onExecute,
    required this.successTitle,
    this.successMsg,
    this.buildSuccessMsg,
    this.notify,
  });

  @override
  State<_ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<_ProcessingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _spinCtrl;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _execute();
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    super.dispose();
  }

  Future<void> _execute() async {
    try {
      final res = await widget.onExecute();
      if (!mounted) return;
      final status = (res['status'] ?? res['Status'] ?? '')
          .toString()
          .toLowerCase();

      if (status.contains('success')) {
        final baseMessage = widget.buildSuccessMsg != null
            ? widget.buildSuccessMsg!(res)
            : (widget.successMsg ?? 'Your transaction was successful.');
        final cashback = _extractCashback(res);
        final msg = cashback != null && cashback > 0
            ? '$baseMessage\n\nYou earned ${_formatCashback(cashback)} cashback 🎁'
            : baseMessage;
        _fire(TxOutcome.success, result: res);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => _ResultScreen(
              success: true,
              title: widget.successTitle,
              message: msg,
            ),
          ),
        );
      } else if (status.contains('process')) {
        _fire(TxOutcome.processing, result: res);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => _ResultScreen(
              success: true,
              title: 'Transaction Processing',
              message:
                  'Your transaction is being processed. Check transactions shortly.',
              color: Colors.orange,
            ),
          ),
        );
      } else {
        final raw = _extractError(res);
        final errMsg = FriendlyError.sanitize(
          raw,
          fallback: 'Transaction could not be completed.',
        );
        _fire(TxOutcome.failed, raw: raw, result: res);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => _ResultScreen(
              success: false,
              title: 'Transaction Failed',
              message: errMsg,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString();
      final friendly = FriendlyError.from(
        e,
        fallback: 'Transaction could not be completed.',
      );
      _fire(TxOutcome.failed, raw: raw);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => _ResultScreen(
            success: false,
            title: 'Transaction Failed',
            message: friendly,
          ),
        ),
      );
    }
  }

  void _fire(TxOutcome outcome, {String? raw, Map<String, dynamic>? result}) {
    final info = widget.notify;
    if (info == null) return;
    TransactionNotifier.notify(
      info: info,
      outcome: outcome,
      rawError: raw,
      cashbackEarned: result == null ? null : _extractCashback(result),
    );
  }

  double? _extractCashback(Map<String, dynamic> result) {
    dynamic value = result['cashback_earned'];
    final data = result['data'];
    if (value == null && data is Map) value = data['cashback_earned'];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  String _formatCashback(double value) {
    final fixed = value.toStringAsFixed(2);
    final parts = fixed.split('.');
    final whole = parts.first.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
    return '₦$whole.${parts.last}';
  }

  String _extractError(Map<String, dynamic> res) {
    final msg = res['message'];
    if (msg is String) return msg;
    if (msg is Map) {
      final err = msg['error'];
      if (err is List && err.isNotEmpty) return err.first.toString();
      return msg.values.first?.toString() ?? 'Transaction failed';
    }
    final apiResp = res['api_response'];
    if (apiResp is String) return apiResp;
    return 'Transaction could not be completed.';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- details card (dimmed) ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surface.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 60,
                        height: 60,
                        child: widget.networkImage,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final d in widget.details) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${d.label}:',
                            style: TextStyle(fontSize: 14, color: cs.onSurface),
                          ),
                          Flexible(
                            child: Text(
                              d.value,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // --- spinner ---
            RotationTransition(
              turns: _spinCtrl,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/images/Logo_2.png',
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Transaction Processing....',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.green.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ====================================================================
// Step 4 — Result screen (success / failure)
// ====================================================================

class _ResultScreen extends StatelessWidget {
  final bool success;
  final String title;
  final String message;
  final Color? color;

  const _ResultScreen({
    required this.success,
    required this.title,
    required this.message,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final resultColor = color ?? (success ? Colors.green : Colors.red);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),

            // --- animated icon ---
            Center(
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      resultColor.withValues(alpha: 0.7),
                      resultColor.withValues(alpha: 0.25),
                      resultColor.withValues(alpha: 0.08),
                    ],
                    stops: const [0.4, 0.7, 1.0],
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: resultColor,
                    ),
                    child: Icon(
                      success ? Icons.check_rounded : Icons.close_rounded,
                      size: 52,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
              ),
            ),

            const Spacer(flex: 3),

            // --- buttons ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => _goHome(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TransactionScreen(),
                          ),
                          (route) => route.isFirst,
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: cs.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: cs.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'View Receipt',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _goHome(BuildContext context) {
    final userProv = Provider.of<UserProvider>(context, listen: false);
    final txProv = Provider.of<TransactionProvider>(context, listen: false);
    final appProv = Provider.of<AppDataProvider>(context, listen: false);

    userProv.loadUserData();
    txProv.load();
    appProv.refresh();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
      (_) => false,
    );
  }
}
