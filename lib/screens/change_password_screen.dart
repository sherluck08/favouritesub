import '../widgets/my_textfield.dart';
import 'package:flutter/material.dart';

import 'package:loader_overlay/loader_overlay.dart';
import 'package:favouritesub/widgets/primary_result_sheet.dart';
import 'package:favouritesub/services/change_password_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _submitting = false;
  String? _oldError;
  String? _newError;
  String? _confirmError;

  bool get _isFormValid =>
      (_oldError == null && _newError == null && _confirmError == null) &&
      _oldController.text.trim().isNotEmpty &&
      _newController.text.trim().isNotEmpty &&
      _confirmController.text.trim().isNotEmpty;

  void _recomputeValidation() {
    final oldP = _oldController.text.trim();
    final newP = _newController.text.trim();
    final confirmP = _confirmController.text.trim();

    _oldError = oldP.isEmpty ? 'Old password is required' : null;

    if (newP.isEmpty) {
      _newError = 'New password is required';
    } else if (newP.length < 6) {
      _newError = 'New password must be at least 6 characters';
    } else if (newP == oldP) {
      _newError = 'New password must be different from old password';
    } else {
      _newError = null;
    }

    if (confirmP.isEmpty) {
      _confirmError = 'Confirm password is required';
    } else if (confirmP != newP) {
      _confirmError = 'New password and confirm password do not match';
    } else {
      _confirmError = null;
    }
  }

  @override
  void dispose() {
    _oldController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Change password'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: LoaderOverlay(
        overlayColor: const Color.fromRGBO(0, 0, 0, 0.1),
        overlayWidgetBuilder: (_) => Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                MyTextfield(
                  textController: _oldController,
                  hintText: 'Old password',
                  obscureText: true,
                  onChanged: (_) => setState(_recomputeValidation),
                ),
                if (_oldError != null) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _oldError!,
                      style: TextStyle(
                        color: Colors.redAccent.shade200,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                MyTextfield(
                  textController: _newController,
                  hintText: 'New password',
                  obscureText: true,
                  onChanged: (_) => setState(_recomputeValidation),
                ),
                if (_newError != null) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _newError!,
                      style: TextStyle(
                        color: Colors.redAccent.shade200,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                MyTextfield(
                  textController: _confirmController,
                  hintText: 'Confirm password',
                  obscureText: true,
                  onChanged: (_) => setState(_recomputeValidation),
                ),
                if (_confirmError != null) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _confirmError!,
                      style: TextStyle(
                        color: Colors.redAccent.shade200,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Container(
                  width: MediaQuery.of(context).size.width,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isFormValid && !_submitting
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
                    onPressed: (_isFormValid && !_submitting) ? _submit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text(
                      'Change Password',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(_recomputeValidation);
    if (!_isFormValid) return;

    final oldP = _oldController.text.trim();
    final newP = _newController.text.trim();
    final confirmP = _confirmController.text.trim();

    setState(() => _submitting = true);
    if (mounted) context.loaderOverlay.show();

    try {
      final res = await ChangePasswordService.changePassword(
        oldPassword: oldP,
        newPassword: newP,
        confirmPassword: confirmP,
      );
      if (!mounted) return;
      context.loaderOverlay.hide();
      setState(() => _submitting = false);

      final err = res['error']?.toString();
      if (err != null && err.isNotEmpty) {
        await showPrimaryResultSheet(
          context,
          color: Theme.of(context).colorScheme.primary,
          title: 'Change Password Failed',
          message: err,
          icon: Icons.error_outline,
          primaryButtonLabel: 'Close',
        );
        return;
      }

      await showPrimaryResultSheet(
        context,
        color: Theme.of(context).colorScheme.primary,
        title: 'Password Updated',
        message:
            res['message']?.toString() ??
            'Your password has been changed successfully.',
        icon: Icons.check_circle,
        primaryButtonLabel: 'Done',
        onPrimaryPressed: () => Navigator.pop(context),
      );
    } catch (e) {
      if (!mounted) return;
      context.loaderOverlay.hide();
      setState(() => _submitting = false);
      await showPrimaryResultSheet(
        context,
        color: Theme.of(context).colorScheme.primary,
        title: 'Change Password Failed',
        message: e.toString(),
        icon: Icons.error_outline,
        primaryButtonLabel: 'Close',
      );
    }
  }
}
