// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get loginTitle => 'GearStock';

  @override
  String get loginSubtitle => 'साइकिल वर्कशॉप और इन्वेंटरी प्रबंधन';

  @override
  String get emailLabel => 'वर्कशॉप ईमेल';

  @override
  String get emailHint => 'staff@gearstock.in';

  @override
  String get passwordLabel => 'मैकेनिक पासवर्ड';

  @override
  String get passwordHint => '••••••••••••';

  @override
  String get forgotPassword => 'भूल गए?';

  @override
  String get loginButton => 'शॉप में लॉगिन करें';

  @override
  String get helpText => 'सहायता चाहिए? शॉप एडमिन से संपर्क करें';

  @override
  String get serverStatus => 'वर्कशॉप सर्वर लाइव';

  @override
  String get appVersion => 'GearStock OS v3.4.1';

  @override
  String get errorEmailRequired => 'ईमेल आवश्यक है';

  @override
  String get errorEmailInvalid => 'एक वैध ईमेल पता दर्ज करें';

  @override
  String get errorPasswordRequired => 'पासवर्ड आवश्यक है';

  @override
  String get errorPasswordTooShort =>
      'पासवर्ड कम से कम 6 अक्षरों का होना चाहिए';

  @override
  String get errorWrongCredentials =>
      'गलत ईमेल या पासवर्ड। कृपया पुनः प्रयास करें।';

  @override
  String get errorNoInternet =>
      'कोई इंटरनेट कनेक्शन नहीं। अपना नेटवर्क जाँचें और पुनः प्रयास करें।';

  @override
  String errorRateLimited(int seconds) {
    return 'बहुत अधिक लॉगिन प्रयास हुए। $seconds सेकंड प्रतीक्षा करें और फिर प्रयास करें।';
  }

  @override
  String errorServer(String message) {
    return 'सर्वर त्रुटि: $message';
  }

  @override
  String get errorGeneric => 'कुछ गलत हो गया। कृपया पुनः प्रयास करें।';
}
