import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  static const _key = 'app_locale';

  String _langCode = 'en';
  String get langCode => _langCode;

  String get langLabel => _languages[_langCode]?['_name'] ?? 'English';
  String get langFlag => _languages[_langCode]?['_flag'] ?? '🇬🇧';

  static const List<String> supportedCodes = ['en', 'ha'];

  static const Map<String, Map<String, String>> _languages = {
    'en': {
      '_name': 'English',
      '_flag': '🇬🇧',
      'welcome_back': 'Welcome Back',
      'sign_in_subtitle': 'Sign in to your account',
      'username': 'Username',
      'password': 'Password',
      'username_error': 'Please enter valid username',
      'password_error': 'Please enter your password',
      'forget_password': 'Forget Password?',
      'sign_in': 'Sign In',
      'no_account': "Don't have an account?",
      'sign_up': 'Sign up',
      'select_language': 'Select Language',
      'save': 'Save',
      'english': 'English',
      'hausa': 'Hausa',
      'welcome_back_user': 'Welcome back,',
      'or_continue_with': 'or continue with',
      'biometrics': 'Biometrics',
      'not_user': 'Not',
      'switch_account': 'Switch account',
      'forgot_password': 'Forgot password?',
      'create_account': 'Create your account',
      'full_name': 'Full Name',
      'enter_full_name': 'Enter Full Name',
      'full_name_error': 'Please enter valid name',
      'enter_username': 'Enter Username',
      'email': 'Enter your email address',
      'enter_email': 'abc@gmail.com',
      'email_error': 'Please enter your email',
      'phone': 'Phone Number',
      'enter_phone': 'Enter Phone Number',
      'phone_error': 'Please enter your phone number',
      'address': 'Address',
      'enter_address': 'Enter your address',
      'address_error': 'Please enter valid address',
      'referral': 'Referral Username (Optional)',
      'enter_referral': 'Enter referral username',
      'register': 'Register',
      'already_have_account': 'Already have an account?',
      'account_created': 'Account Created!',
      'account_created_msg':
          'Your account has been created successfully.\nYou can now sign in.',
      'continue_sign_in': 'Continue to Sign In',
      'something_wrong': 'Something went wrong',
      'dismiss': 'Dismiss',
      'valid_email': 'Enter a valid email address',
      'valid_phone': 'Enter a valid phone number',
      'password_length': 'Password must be at least 8 characters',
      'logging_in': 'Logging in...',
      'registering': 'Registering...',
    },
    'ha': {
      '_name': 'Hausa',
      '_flag': '🇳🇬',
      'welcome_back': 'Barka da Dawowa',
      'sign_in_subtitle': 'Shiga asusun ka',
      'username': 'Sunan mai amfani',
      'password': 'Kalmar sirri',
      'username_error': 'Da fatan a shigar da sunan mai amfani',
      'password_error': 'Da fatan a shigar da kalmar sirri',
      'forget_password': 'Manta Kalmar sirri?',
      'sign_in': 'Shiga',
      'no_account': 'Ba ku da asusu?',
      'sign_up': 'Yi rajista',
      'select_language': 'Zaɓi Harshe',
      'save': 'Ajiye',
      'english': 'Turanci',
      'hausa': 'Hausa',
      'welcome_back_user': 'Barka da dawowa,',
      'or_continue_with': 'ko ci gaba da',
      'biometrics': 'Na halitta',
      'not_user': 'Ba',
      'switch_account': 'ba ne? Canja asusu',
      'forgot_password': 'Manta kalmar sirri?',
      'create_account': 'Ƙirƙiri asusun ka',
      'full_name': 'Cikakken Suna',
      'enter_full_name': 'Shigar da Cikakken Suna',
      'full_name_error': 'Da fatan a shigar da suna',
      'enter_username': 'Shigar da Sunan mai amfani',
      'email': 'Shigar da adireshin ka',
      'enter_email': 'abc@gmail.com',
      'email_error': 'Da fatan a shigar da imel',
      'phone': 'Lambar Waya',
      'enter_phone': 'Shigar da Lambar Waya',
      'phone_error': 'Da fatan a shigar da lambar waya',
      'address': 'Adireshi',
      'enter_address': 'Shigar da adireshin ka',
      'address_error': 'Da fatan a shigar da adireshi',
      'referral': 'Sunan Mai Ba da Shawara (Zaɓi)',
      'enter_referral': 'Shigar da sunan mai ba da shawara',
      'register': 'Yi Rajista',
      'already_have_account': 'Kuna da asusu?',
      'account_created': 'An Ƙirƙiri Asusu!',
      'account_created_msg':
          'An ƙirƙiri asusun ka cikin nasara.\nYanzu za ka iya shiga.',
      'continue_sign_in': 'Ci gaba zuwa Shiga',
      'something_wrong': 'Wani abu ya faru',
      'dismiss': 'Rufe',
      'valid_email': 'Shigar da ingantaccen adireshin imel',
      'valid_phone': 'Shigar da ingantacciyar lambar waya',
      'password_length': 'Kalmar sirri dole ta kasance aƙalla haruffa 8',
      'logging_in': 'Ana shiga...',
      'registering': 'Ana yin rajista...',
    },
  };

  LocaleProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _langCode = prefs.getString(_key) ?? 'en';
    notifyListeners();
  }

  String tr(String key) =>
      _languages[_langCode]?[key] ?? _languages['en']![key] ?? key;

  static String nameFor(String code) => _languages[code]?['_name'] ?? code;
  static String flagFor(String code) => _languages[code]?['_flag'] ?? '';

  Future<void> setLocale(String code) async {
    if (_langCode == code) return;
    _langCode = code;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, code);
  }
}
