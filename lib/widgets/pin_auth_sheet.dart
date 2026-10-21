import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../services/pin_service.dart';

class PinAuthResult {
  final bool success;
  final bool usedBiometric;
  const PinAuthResult({required this.success, this.usedBiometric = false});
}

Future<PinAuthResult?> showPinAuthSheet(
  BuildContext context, {
  required bool allowBiometric,
  required Future<bool> Function() biometricAuth,
}) {
  return showModalBottomSheet<PinAuthResult>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _PinAuthSheet(
      allowBiometric: allowBiometric,
      biometricAuth: biometricAuth,
    ),
  );
}

class _PinAuthSheet extends StatefulWidget {
  final bool allowBiometric;
  final Future<bool> Function() biometricAuth;
  const _PinAuthSheet({
    required this.allowBiometric,
    required this.biometricAuth,
  });
  @override
  State<_PinAuthSheet> createState() => _PinAuthSheetState();
}

class _PinAuthSheetState extends State<_PinAuthSheet> {
  final List<String> _digits = [];
  String? _error;
  bool _submitting = false;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      final auth = LocalAuthentication();
      final canCheck = await auth.canCheckBiometrics;
      final supported = await auth.isDeviceSupported();
      final types = await auth.getAvailableBiometrics();
      if (mounted) {
        setState(() {
          _biometricAvailable = canCheck && supported && types.isNotEmpty;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _biometricAvailable = false);
    }
  }

  Future<void> _submitPin() async {
    if (_digits.length != 5) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final ok = await PinService.verifyPin(_digits.join());
      if (!mounted) return;
      if (ok) {
        FocusScope.of(context).unfocus();
        Navigator.of(context).pop(const PinAuthResult(success: true));
        return;
      }

      setState(() {
        _error = 'PIN is not correct';
        _digits.clear();
      });
    } catch (e) {
      setState(() {
        _error = 'PIN is not correct';
        _digits.clear();
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  void _onKey(String key) {
    if (_submitting) return;
    if (key == 'del') {
      if (_digits.isNotEmpty) setState(() => _digits.removeLast());
      return;
    }
    if (_digits.length >= 5) return;
    setState(() => _digits.add(key));
    if (_digits.length == 5) {
      _submitPin();
    }
  }

  @override
  Widget build(BuildContext context) {
    final keys = [
      '1',
      '2',
      '3',
      '4',
      '5',
      '6',
      '7',
      '8',
      '9',
      'biometric',
      '0',
      'del',
    ];
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_submitting) ...[
            const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(height: 10),
          ],
          const Text(
            'Confirm with PIN',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 6),
          const Text(
            'Enter your 5-digit passcode',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                5,
                (i) => Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _digits.length
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade300,
                  ),
                ),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Colors.redAccent.shade200, fontSize: 13),
            ),
          ],
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.6,
            ),
            itemCount: keys.length,
            itemBuilder: (context, index) {
              final k = keys[index];
              if (k == 'biometric') {
                return Visibility(
                  visible: _biometricAvailable,
                  child: _KeyButton(
                    label: const Icon(
                      Icons.fingerprint,
                      size: 40,
                      color: Colors.white,
                    ),
                    onTap: () async {
                      if (_submitting) return;
                      final ok = await widget.biometricAuth();
                      if (!mounted) return;
                      if (ok)
                        Navigator.of(context).pop(
                          const PinAuthResult(
                            success: true,
                            usedBiometric: true,
                          ),
                        );
                    },
                  ),
                );
              }
              if (k == 'del') {
                return _KeyButton(
                  label: const Icon(
                    Icons.backspace_outlined,
                    color: Colors.white,
                  ),
                  onTap: () => _onKey('del'),
                );
              }
              return _KeyButton(
                label: Text(
                  k,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () => _onKey(k),
              );
            },
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _KeyButton extends StatelessWidget {
  final Widget label;
  final VoidCallback onTap;
  const _KeyButton({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(10),
        ),
        child: label,
      ),
    );
  }
}
