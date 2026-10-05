// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get loginTitle => 'GearStock';

  @override
  String get loginSubtitle => 'Bicycle Workshop & Inventory Management';

  @override
  String get emailLabel => 'Workshop Email';

  @override
  String get emailHint => 'staff@gearstock.in';

  @override
  String get passwordLabel => 'Mechanic Password';

  @override
  String get passwordHint => '••••••••••••';

  @override
  String get forgotPassword => 'Forgot?';

  @override
  String get loginButton => 'Login to Shop';

  @override
  String get helpText => 'Need help? Contact Shop Admin';

  @override
  String get serverStatus => 'Workshop Server Live';

  @override
  String get appVersion => 'GearStock OS v3.4.1';

  @override
  String get errorEmailRequired => 'Email is required';

  @override
  String get errorEmailInvalid => 'Enter a valid email address';

  @override
  String get errorPasswordRequired => 'Password is required';

  @override
  String get errorPasswordTooShort => 'Password must be at least 6 characters';

  @override
  String get errorWrongCredentials =>
      'Incorrect email or password. Please try again.';

  @override
  String get errorNoInternet =>
      'No internet connection. Check your network and retry.';

  @override
  String errorRateLimited(int seconds) {
    return 'Too many login attempts. Wait $seconds seconds and try again.';
  }

  @override
  String errorServer(String message) {
    return 'Server error: $message';
  }

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';
}
