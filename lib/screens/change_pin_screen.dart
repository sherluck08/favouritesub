import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:favouritesub/widgets/my_textfield.dart';
import 'package:favouritesub/services/change_passcode_service.dart';
import 'package:favouritesub/widgets/primary_result_sheet.dart';

class ChangePinScreen extends StatefulWidget {
  const ChangePinScreen({super.key});

  @override
  State<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends State<ChangePinScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _newController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _submitting = false;
  String? _oldPinError;
  String? _formError;

  @override
  void dispose() {
    _passwordController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    final oldPinOk = _passwordController.text.trim().length == 5;
    final pinOk = _newController.text.trim().length == 5;
    final confirmOk = _confirmController.text.trim().length == 5;
    final match = _newController.text.trim() == _confirmController.text.trim();

    return oldPinOk && pinOk && confirmOk && match;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_canSubmit) return;
    setState(() {
      _submitting = true;
      _oldPinError = null;
      _formError = null;
    });
    context.loaderOverlay.show();
    try {
      final res = await ChangePasscodeService.changePasscode(
        oldPin: _passwordController.text.trim(),
        newPin: _newController.text.trim(),
        confirmPin: _confirmController.text.trim(),
      );
      if (!mounted) return;
      context.loaderOverlay.hide();
      setState(() => _submitting = false);

      final err = res['error']?.toString();
      if (err != null && err.isNotEmpty) {
        await showPrimaryResultSheet(
          context,
          title: 'Change pin failed',
          message: err,
          icon: Icons.error_outline,
          color: Colors.redAccent,
          primaryButtonLabel: 'Close',
        );
      } else {
        await showPrimaryResultSheet(
          context,
          title: 'Pin changed',
          message:
              res['message']?.toString() ??
              'Your pin has been updated successfully.',
          icon: Icons.check_circle,
          color: Colors.green,
          primaryButtonLabel: 'Done',
          onPrimaryPressed: () => Navigator.of(context).pop(),
        );
      }
    } catch (e) {
      if (!mounted) return;
      context.loaderOverlay.hide();
      setState(() => _submitting = false);
      await showPrimaryResultSheet(
        context,
        title: 'Change pin failed',
        message: e.toString().replaceFirst('Exception: ', ''),
        icon: Icons.error_outline,
        color: Colors.redAccent,
        primaryButtonLabel: 'Close',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Change pin'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: LoaderOverlay(
        overlayColor: Theme.of(
          context,
        ).colorScheme.primary.withValues(alpha: 0.08),
        overlayWidgetBuilder: (_) => Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const SizedBox(height: 8),
            const Text(
              'Enter your old pin and set a new one.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            MyTextfield(
              hintText: 'Enter your old pin',
              textController: _passwordController,
              obscureText: true,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(5),
              ],
              onChanged: (_) {
                setState(() {
                  _oldPinError = null;
                });
              },
            ),
            if (_oldPinError != null) ...[
              const SizedBox(height: 6),
              Text(
                _oldPinError!,
                style: TextStyle(color: Colors.red[400], fontSize: 13),
              ),
            ],
            const SizedBox(height: 16),
            MyTextfield(
              hintText: 'Enter new pin',
              textController: _newController,
              obscureText: true,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(5),
              ],
              onChanged: (_) {
                setState(() {});
              },
            ),
            const SizedBox(height: 16),
            MyTextfield(
              hintText: 'Confirm new pin',
              textController: _confirmController,
              obscureText: true,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(5),
              ],
              onChanged: (_) {
                setState(() {});
              },
            ),
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final newPin = _newController.text.trim();
                final confirmPin = _confirmController.text.trim();
                if (newPin.isEmpty || confirmPin.isEmpty)
                  return const SizedBox();
                if (newPin.length != 5 || confirmPin.length != 5) {
                  return const Text(
                    'Passcode must be 5 digits',
                    style: TextStyle(color: Colors.redAccent, fontSize: 12),
                  );
                }
                final match = newPin == confirmPin;
                return match
                    ? const SizedBox()
                    : const Text(
                        'Passcodes do not match',
                        style: TextStyle(color: Colors.redAccent, fontSize: 12),
                      );
              },
            ),
            if (_formError != null) ...[
              const SizedBox(height: 6),
              Text(
                _formError!,
                style: TextStyle(color: Colors.red[400], fontSize: 13),
              ),
            ],
            const SizedBox(height: 24),
            Container(
              width: MediaQuery.of(context).size.width,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _canSubmit
                      ? [
                          Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.85),
                          Theme.of(context).colorScheme.primary,
                        ]
                      : [Colors.grey.shade300, Colors.grey.shade400],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: ElevatedButton(
                onPressed: _submitting || !_canSubmit ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Text(
                  'Change pin',
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
