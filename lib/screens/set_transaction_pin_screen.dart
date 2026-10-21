import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:favouritesub/services/pin_service.dart';
import 'package:favouritesub/utils/utils.dart';
import 'package:favouritesub/widgets/my_textfield.dart';

class SetTransactionPinScreen extends StatefulWidget {
  const SetTransactionPinScreen({super.key});

  @override
  State<SetTransactionPinScreen> createState() =>
      _SetTransactionPinScreenState();
}

class _SetTransactionPinScreenState extends State<SetTransactionPinScreen> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _showPin = false;
  bool _showConfirm = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool get _pinsValidAndMatch =>
      Utils.pinsMatch(_pinController.text, _confirmController.text);

  Future<void> _submit() async {
    if (!_pinsValidAndMatch || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    context.loaderOverlay.show();
    try {
      await PinService.setupPin(pin: _pinController.text.trim());
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_outline,
                  color: Colors.green[600],
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'PIN set',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your transaction PIN has been created successfully.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop(_pinController.text.trim());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Done'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        context.loaderOverlay.hide();
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _pinsValidAndMatch && !_submitting;
    final gradientColors = canSubmit
        ? [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
            Theme.of(context).colorScheme.primary,
          ]
        : [Colors.grey.shade300, Colors.grey.shade400];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Set transaction PIN'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: LoaderOverlay(
        overlayColor: const Color.fromRGBO(128, 0, 128, 0.1),
        overlayWidgetBuilder: (context) => Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const SizedBox(height: 8),
            const Text(
              'Create a 5‑digit PIN to authorize transactions.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 20),

            const Text('PIN', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            MyTextfield(
              hintText: 'Enter 5‑digit PIN',
              textController: _pinController,
              obscureText: !_showPin,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(5),
              ],
              onChanged: (_) => setState(() {}),
              suffixIcon: IconButton(
                icon: Icon(
                  _showPin
                      ? Icons.visibility_off_outlined
                      : Icons.remove_red_eye_outlined,
                ),
                onPressed: () => setState(() {
                  _showPin = !_showPin;
                }),
              ),
            ),

            const SizedBox(height: 16),
            const Text(
              'Confirm PIN',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            MyTextfield(
              hintText: 'Re‑enter PIN',
              textController: _confirmController,
              obscureText: !_showConfirm,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(5),
              ],
              onChanged: (_) => setState(() {}),
              suffixIcon: IconButton(
                icon: Icon(
                  _showConfirm
                      ? Icons.visibility_off_outlined
                      : Icons.remove_red_eye_outlined,
                ),
                onPressed: () => setState(() {
                  _showConfirm = !_showConfirm;
                }),
              ),
            ),

            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final bothFilled =
                    _pinController.text.trim().isNotEmpty &&
                    _confirmController.text.trim().isNotEmpty;
                final match =
                    _pinController.text.trim() ==
                    _confirmController.text.trim();
                final validLen =
                    Utils.isValidPin(_pinController.text) &&
                    Utils.isValidPin(_confirmController.text);
                if (!bothFilled) return const SizedBox();
                if (!validLen) {
                  return const Text(
                    'PIN must be exactly 5 digits',
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  );
                }
                return match
                    ? const SizedBox()
                    : const Text(
                        'PINs do not match',
                        style: TextStyle(color: Colors.orange, fontSize: 12),
                      );
              },
            ),

            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(
                _error!,
                style: TextStyle(color: Colors.red[400], fontSize: 13),
              ),
            ],

            const SizedBox(height: 24),
            Container(
              width: MediaQuery.of(context).size.width,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: ElevatedButton(
                onPressed: canSubmit ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Text(
                  'Set PIN',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
