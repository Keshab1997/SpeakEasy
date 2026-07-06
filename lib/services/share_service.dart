import 'package:share_plus/share_plus.dart';

class ShareService {
  static const String _appLink = 'https://play.google.com/store/apps/details?id=flutter_spoken_english_app';
  static const String _appName = 'SpeakEasy';
  static const String _appTagline = 'বাংলায় ইংলিশ শেখার সেরা অ্যাপ';

  /// Share streak milestone
  static Future<ShareResult> shareStreak(int streakDays) {
    final message = '''
🎉 আমি টানা $streakDays দিন $_appName-তে ইংলিশ প্র্যাকটিস করছি!

$_appTagline — $_appLink

তোমরাও জয়েন করো! 🔥''';
    return Share.share(message);
  }

  /// Share achievement
  static Future<ShareResult> shareAchievement(String title) {
    final message = '''
🏆 আমি $_appName-তে "$title" অ্যাচিভমেন্ট অর্জন করেছি!

$_appTagline — $_appLink

তোমরাও চেষ্টা করো! 💪''';
    return Share.share(message);
  }

  /// Share referral code
  static Future<ShareResult> shareReferralCode(String code) {
    final message = '''
📱 আমার রেফারেল কোড: $code

$_appName দিয়ে বাংলায় ইংলিশ শেখো!
$_appLink

রেজিস্ট্রেশনের সময় আমার কোডটি ব্যবহার করো! 🎁''';
    return Share.share(message);
  }

  /// Share app with referral code
  static Future<ShareResult> shareApp() {
    final message = '''
📚 $_appName — $_appTagline

৭০+ গ্রামার লেসন, ১০+ গেম, AI টিচার, স্পিকিং প্র্যাকটিস!

ডাউনলোড করুন: $_appLink''';
    return Share.share(message);
  }

  /// General share
  static Future<ShareResult> share(String text) {
    return Share.share(text);
  }
}
