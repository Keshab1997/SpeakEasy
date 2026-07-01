import 'hive_service.dart';

class InactivityResult {
  final int daysInactive;
  final bool shouldNotify;

  const InactivityResult({
    this.daysInactive = 0,
    required this.shouldNotify,
  });
}

class ReEngagementService {
  /// Checks whether the user has been inactive and should receive a
  /// motivational notification. Uses [HiveService] to read the last
  /// app open date. Returns [InactivityResult] with the number of
  /// inactive days and whether a notification should be sent.
  static Future<InactivityResult> checkInactivity() async {
    final lastOpenDate = HiveService.getLastAppOpenDate();
    final now = DateTime.now();

    // If no record exists yet (first install), treat as active today
    if (lastOpenDate == null) {
      await HiveService.setLastAppOpenDate(now);
      return const InactivityResult(shouldNotify: false);
    }

    // Already opened today → skip notification
    if (lastOpenDate.year == now.year &&
        lastOpenDate.month == now.month &&
        lastOpenDate.day == now.day) {
      return const InactivityResult(shouldNotify: false);
    }

    // Re-engagement toggle off → skip
    if (!HiveService.isReEngagementEnabled()) {
      return InactivityResult(shouldNotify: false);
    }

    final daysInactive = now.difference(lastOpenDate).inDays;

    return InactivityResult(
      daysInactive: daysInactive,
      shouldNotify: daysInactive >= 1,
    );
  }

  /// Returns a motivational message tailored to how many days the user
  /// has been inactive. [userName] is optional — if empty, uses a generic
  /// greeting.
  static String getMessage(int daysInactive, {String userName = ''}) {
    final greeting = userName.isNotEmpty ? userName : '';
    final prefix = greeting.isNotEmpty ? '$greeting, ' : '';

    if (daysInactive == 1) {
      return '${prefix}আপনার আজকের একটি Daily Word অপেক্ষা করছে! 🎯';
    } else if (daysInactive == 2) {
      return '$prefix🔥 ২ দিন ধরে আসেননি! আপনার streak বাঁচান — মাত্র ১ মিনিট সময় নিন!';
    } else if (daysInactive <= 5) {
      return '$prefix💪 $daysInactive দিন হয়ে গেছে! নতুন অধ্যায় যোগ হয়েছে, শুরু করে দেখুন!';
    } else if (daysInactive <= 7) {
      return '$prefix⚡ এক সপ্তাহ! ছেড়ে দেবেন না — ছোট করে হলেও আজই শুরু করুন!';
    } else {
      return '$prefix🚀 $daysInactive দিন! ফিরতে কখনো দেরি হয় না — আপনার জন্য নতুন কন্টেন্ট অপেক্ষা করছে!';
    }
  }
}
