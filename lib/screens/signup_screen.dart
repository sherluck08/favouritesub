import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:favouritesub/screens/login_screen.dart';
import 'package:provider/provider.dart';
import 'package:favouritesub/providers/auth_provider.dart';
import 'package:favouritesub/providers/locale_provider.dart';
import 'package:favouritesub/widgets/branded_loader.dart';
import 'package:favouritesub/widgets/whatsapp_support_fabs.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  final _fullNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _referralCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  final _fullNameFocus = FocusNode();
  final _usernameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _addressFocus = FocusNode();
  final _referralFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _hidePassword = true;
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
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _fullNameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _referralCtrl.dispose();
    _passwordCtrl.dispose();
    _fullNameFocus.dispose();
    _usernameFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _addressFocus.dispose();
    _referralFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  String _cleanErrorText(String message) {
    String s = message.trim();
    if (s.startsWith('[') && s.endsWith(']') && s.length >= 2) {
      s = s.substring(1, s.length - 1).trim();
    }
    if ((s.startsWith('"') && s.endsWith('"')) ||
        (s.startsWith("'") && s.endsWith("'"))) {
      s = s.substring(1, s.length - 1).trim();
    }
    return s;
  }

  String? _validateEmail(String v) {
    final r = RegExp(r'^[\w\.-]+@[\w\.-]+\.[A-Za-z]{2,}$');
    if (!r.hasMatch(v.trim())) return 'valid_email';
    return null;
  }

  String? _validatePhone(String v) {
    final digits = v.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) return 'valid_phone';
    return null;
  }

  String? _validatePassword(String v) {
    if (v.length < 8) return 'password_length';
    return null;
  }

  void _handleRegister() async {
    setState(() => _submitted = true);

    final locale = Provider.of<LocaleProvider>(context, listen: false);
    final errors = <String>[];

    if (_fullNameCtrl.text.trim().isEmpty) errors.add('full_name');
    if (_usernameCtrl.text.trim().isEmpty) errors.add('username');
    if (_emailCtrl.text.trim().isEmpty) {
      errors.add('email');
    } else {
      final emailErr = _validateEmail(_emailCtrl.text);
      if (emailErr != null) errors.add(emailErr);
    }
    if (_phoneCtrl.text.trim().isEmpty) {
      errors.add('phone');
    } else {
      final phoneErr = _validatePhone(_phoneCtrl.text);
      if (phoneErr != null) errors.add(phoneErr);
    }
    if (_addressCtrl.text.trim().isEmpty) errors.add('address');
    if (_passwordCtrl.text.isEmpty) {
      errors.add('password');
    } else {
      final passErr = _validatePassword(_passwordCtrl.text);
      if (passErr != null) errors.add(passErr);
    }

    if (errors.isNotEmpty) return;

    FocusScope.of(context).unfocus();
    final auth = context.read<AuthProvider>();
    if (auth.isLoading) return;

    context.loaderOverlay.show();
    final success = await auth.signup(
      fullName: _fullNameCtrl.text,
      username: _usernameCtrl.text,
      email: _emailCtrl.text,
      phone: _phoneCtrl.text,
      address: _addressCtrl.text,
      referralUsername: _referralCtrl.text.trim().isEmpty
          ? null
          : _referralCtrl.text,
      password: _passwordCtrl.text,
    );
    if (!mounted) return;
    context.loaderOverlay.hide();

    if (success) {
      _showSuccessSheet(locale);
    } else {
      final msg = auth.state.error ?? 'Sign up failed';
      _showErrorSheet(_cleanErrorText(msg), locale);
    }
  }

  void _showSuccessSheet(LocaleProvider locale) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 28),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.green,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              locale.tr('account_created'),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              locale.tr('account_created_msg'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  locale.tr('continue_sign_in'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorSheet(String message, LocaleProvider locale) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 28),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: cs.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close_rounded, color: cs.error, size: 36),
            ),
            const SizedBox(height: 20),
            Text(
              locale.tr('something_wrong'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: cs.error,
                  foregroundColor: cs.onError,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  locale.tr('dismiss'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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

  Widget _buildField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required FocusNode focusNode,
    required ColorScheme cs,
    FocusNode? nextFocus,
    String? errorKey,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool obscure = false,
    Widget? suffixIcon,
    String? Function(String)? extraValidator,
  }) {
    final locale = Provider.of<LocaleProvider>(context, listen: false);
    final isEmpty = _submitted && controller.text.trim().isEmpty;
    String? extraError;
    if (_submitted && !isEmpty && extraValidator != null) {
      extraError = extraValidator(controller.text);
    }
    final showError = isEmpty || extraError != null;
    final errorText = isEmpty
        ? (errorKey != null ? locale.tr(errorKey) : '')
        : (extraError != null ? locale.tr(extraError) : '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscure,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          textInputAction: nextFocus != null
              ? TextInputAction.next
              : TextInputAction.done,
          onSubmitted: (_) {
            if (nextFocus != null) {
              nextFocus.requestFocus();
            } else {
              FocusScope.of(context).unfocus();
            }
          },
          onChanged: (_) {
            if (_submitted) setState(() {});
          },
          decoration: _inputDecoration(
            hint: hint,
            cs: cs,
            suffixIcon: suffixIcon,
          ),
        ),
        if (showError && errorText.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(errorText, style: TextStyle(fontSize: 12, color: cs.error)),
        ],
      ],
    );
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mq = MediaQuery.of(context);
    final bottomInset = mq.viewInsets.bottom;
    final locale = Provider.of<LocaleProvider>(context);

    return Scaffold(
      backgroundColor: cs.surface,
      floatingActionButton: const WhatsAppSupportFabs(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: LoaderOverlay(
        overlayColor: cs.surface.withValues(alpha: 0.85),
        overlayWidgetBuilder: (_) =>
            BrandedLoader(message: locale.tr('registering')),
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SafeArea(
            child: Column(
              children: [
                // ── top bar ──
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.arrow_back,
                          color: cs.onSurface,
                          size: 22,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: cs.surfaceContainerHighest
                              .withValues(alpha: 0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const Spacer(),
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
                              color: cs.outlineVariant.withValues(alpha: 0.35),
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
                      const SizedBox(width: 8),
                    ],
                  ),
                ),

                // ── scrollable content ──
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeIn,
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(
                        left: 24,
                        right: 24,
                        bottom: 24 + bottomInset,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),

                          // ── heading ──
                          Text(
                            locale.tr('create_account'),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: cs.onSurface,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text.rich(
                            TextSpan(
                              style: TextStyle(
                                fontSize: 15,
                                color: cs.onSurfaceVariant,
                                height: 1.4,
                              ),
                              children: [
                                TextSpan(
                                  text: '${locale.tr('already_have_account')} ',
                                ),
                                TextSpan(
                                  text: locale.tr('sign_in'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: cs.primary,
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () => Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const LoginScreen(),
                                      ),
                                    ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 36),

                          // ── fields ──
                          _buildField(
                            label: locale.tr('full_name'),
                            hint: locale.tr('enter_full_name'),
                            controller: _fullNameCtrl,
                            focusNode: _fullNameFocus,
                            nextFocus: _usernameFocus,
                            errorKey: 'full_name_error',
                            textCapitalization: TextCapitalization.words,
                            cs: cs,
                          ),
                          const SizedBox(height: 18),

                          _buildField(
                            label: locale.tr('username'),
                            hint: locale.tr('enter_username'),
                            controller: _usernameCtrl,
                            focusNode: _usernameFocus,
                            nextFocus: _emailFocus,
                            errorKey: 'username_error',
                            cs: cs,
                          ),
                          const SizedBox(height: 18),

                          _buildField(
                            label: locale.tr('email'),
                            hint: locale.tr('enter_email'),
                            controller: _emailCtrl,
                            focusNode: _emailFocus,
                            nextFocus: _phoneFocus,
                            errorKey: 'email_error',
                            keyboardType: TextInputType.emailAddress,
                            extraValidator: _validateEmail,
                            cs: cs,
                          ),
                          const SizedBox(height: 18),

                          _buildField(
                            label: locale.tr('phone'),
                            hint: locale.tr('enter_phone'),
                            controller: _phoneCtrl,
                            focusNode: _phoneFocus,
                            nextFocus: _addressFocus,
                            errorKey: 'phone_error',
                            keyboardType: TextInputType.phone,
                            extraValidator: _validatePhone,
                            cs: cs,
                          ),
                          const SizedBox(height: 18),

                          _buildField(
                            label: locale.tr('address'),
                            hint: locale.tr('enter_address'),
                            controller: _addressCtrl,
                            focusNode: _addressFocus,
                            nextFocus: _referralFocus,
                            errorKey: 'address_error',
                            textCapitalization: TextCapitalization.sentences,
                            cs: cs,
                          ),
                          const SizedBox(height: 18),

                          _buildField(
                            label: locale.tr('referral'),
                            hint: locale.tr('enter_referral'),
                            controller: _referralCtrl,
                            focusNode: _referralFocus,
                            nextFocus: _passwordFocus,
                            cs: cs,
                          ),
                          const SizedBox(height: 18),

                          _buildField(
                            label: locale.tr('password'),
                            hint: locale.tr('password'),
                            controller: _passwordCtrl,
                            focusNode: _passwordFocus,
                            errorKey: 'password_error',
                            obscure: _hidePassword,
                            extraValidator: _validatePassword,
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

                          const SizedBox(height: 32),

                          Consumer<AuthProvider>(
                            builder: (context, auth, _) {
                              return _RegisterButton(
                                isLoading: auth.isLoading,
                                label: locale.tr('register'),
                                onPressed: auth.isLoading
                                    ? null
                                    : _handleRegister,
                              );
                            },
                          ),

                          const SizedBox(height: 24),

                          // ── login link ──
                          Center(
                            child: Text.rich(
                              TextSpan(
                                style: TextStyle(
                                  fontSize: 14,
                                  color: cs.onSurfaceVariant,
                                ),
                                children: [
                                  TextSpan(
                                    text:
                                        '${locale.tr('already_have_account')} ',
                                  ),
                                  TextSpan(
                                    text: locale.tr('sign_in'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: cs.primary,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () => Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const LoginScreen(),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RegisterButton extends StatelessWidget {
  final bool isLoading;
  final String label;
  final VoidCallback? onPressed;

  const _RegisterButton({
    required this.isLoading,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          disabledBackgroundColor: cs.primary.withValues(alpha: 0.7),
          disabledForegroundColor: cs.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
          child: isLoading
              ? SizedBox(
                  key: const ValueKey('loader'),
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation<Color>(cs.onPrimary),
                  ),
                )
              : Text(label, key: const ValueKey('label')),
        ),
      ),
    );
  }
}
