import 'hive_service.dart';

class IdleTrackerService {
  static const int maxInAppReminders = 2;
  static const int minGapBetweenInAppReminders = 2; // hours

  static Future<bool> shouldShowInAppReminder() async {
    if (!HiveService.isIdleReminderEnabled()) return false;

    final lastActivity = HiveService.getLastActivityTime();
    if (lastActivity == null) {
      await recordActivity();
      return false;
    }

    final idleDuration = DateTime.now().difference(lastActivity);
    final frequencyHours = HiveService.getIdleReminderFrequencyHours();
    if (idleDuration.inHours < frequencyHours) return false;

    final lastReminder = HiveService.getLastInAppReminderTime();
    if (lastReminder != null) {
      final gap = DateTime.now().difference(lastReminder);
      if (gap.inHours < minGapBetweenInAppReminders) return false;
    }

    final consecutive = HiveService.getConsecutiveIdleReminders();
    if (consecutive >= maxInAppReminders) return false;

    return true;
  }

  static Future<bool> shouldSendNativeNotification() async {
    if (!HiveService.isIdleReminderEnabled()) return false;
    if (!HiveService.isNotificationEnabled()) return false;

    final lastActivity = HiveService.getLastActivityTime();
    if (lastActivity == null) return false;

    final idleDuration = DateTime.now().difference(lastActivity);
    final frequencyHours = HiveService.getIdleReminderFrequencyHours();
    final consecutive = HiveService.getConsecutiveIdleReminders();

    if (idleDuration.inHours >= frequencyHours * 2) return true;
    if (consecutive >= maxInAppReminders && idleDuration.inHours >= frequencyHours) return true;

    return false;
  }

  static Future<void> recordActivity() async {
    await HiveService.setLastActivityTime(DateTime.now());
    await HiveService.setConsecutiveIdleReminders(0);
  }

  static Future<void> markInAppReminderShown() async {
    await HiveService.setLastInAppReminderTime(DateTime.now());
    final consecutive = HiveService.getConsecutiveIdleReminders();
    await HiveService.setConsecutiveIdleReminders(consecutive + 1);
  }

  static Future<Duration> getIdleDuration() async {
    final lastActivity = HiveService.getLastActivityTime();
    if (lastActivity == null) return Duration.zero;
    return DateTime.now().difference(lastActivity);
  }

  static Future<void> resetReminderState() async {
    await recordActivity();
    await HiveService.setConsecutiveIdleReminders(0);
  }

  static String getReminderMessage(int hoursIdle) {
    final messages = [
      'সময় হয়েছে পড়ার! 📚 আপনার আজকের লেসন অপেক্ষা করছে!',
      'আজকে এখনো প্র্যাকটিস করেননি? 🎯 মাত্র ৫ মিনিট সময় নিন!',
      'আপনার Streak বাঁচান! 🔥 এখনই শুরু করুন!',
      'নতুন লেসন যোগ হয়েছে! 📖 দেখে আসুন?',
      'আপনার Daily Word অপেক্ষা করছে! 💪',
      'Time to practice! 📚 Your lesson is waiting!',
      "Haven't practiced today? 🎯 Just 5 minutes!",
      'Save your streak! 🔥 Start now!',
      'New lesson added! 📖 Check it out!',
    ];
    final extraMessages = <String>[];
    if (hoursIdle >= 24) {
      extraMessages.addAll([
        '🚀 ${hoursIdle ~/ 24} দিন হয়ে গেছে! ফিরে আসুন!',
        '⚡ ${hoursIdle ~/ 24} দিন! আপনার প্রোগ্রেস অপেক্ষা করছে!',
      ]);
    }
    final all = [...messages, ...extraMessages];
    return all[DateTime.now().millisecondsSinceEpoch % all.length];
  }
}
