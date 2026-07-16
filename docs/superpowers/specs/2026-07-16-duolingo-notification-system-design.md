# SpeaKEasy Duolingo-Style Custom Sound Notification System

**Date:** 2026-07-16
**Status:** Design Spec

## Overview

Duolingo-র মতো কাস্টম সাউন্ড সহ নোটিফিকেশন সিস্টেম তৈরি করতে হবে। ইউজার যখন অ্যাপ ব্যবহার করছে না, তখন তাকে রিমাইন্ডার দিয়ে অ্যাপে ফিরিয়ে আনা — কিন্তু অতিরিক্ত মিনতি না করে। নোটিফিকেশনের সাউন্ড এমন হবে যা শুনলেই ইউজার বুঝতে পারে এটা SpeakEasy-র নোটিফিকেশন।

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    SpeakEasy Notification System              │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────────────┐     ┌──────────────────────────┐   │
│  │  In-App Reminder     │     │  Background Notification  │   │
│  │  (App খোলা থাকলে)     │◄───►│  (App বন্ধ থাকলে)         │   │
│  │                     │     │                          │   │
│  │  Duolingo-style      │     │  Custom Notification     │   │
│  │  green banner        │     │  Channel + Sound Asset   │   │
│  │  + audioplayers      │     │  + rich content          │   │
│  └──────────┬──────────┘     └───────────┬──────────────┘   │
│             │                            │                  │
│             └──────────┬─────────────────┘                  │
│                        ▼                                    │
│  ┌──────────────────────────────────────────────────┐      │
│  │           IdleTrackerService                      │      │
│  │  ট্র্যাক করে ইউজার কতক্ষণ idle (last activity)     │      │
│  │  Hive-তে সেভ করে last_activity_time               │      │
│  └──────────────────────────────────────────────────┘      │
│                        ▲                                    │
│              ┌─────────┴──────────┐                        │
│              │   Custom Sound      │                        │
│              │   Assets (User)     │                        │
│              │   notification.mp3  │                        │
│              │   character.mp3    │                        │
│              └────────────────────┘                        │
└──────────────────────────────────────────────────────────────┘
```

## Components

### 1. IdleTrackerService (New File)
`lib/services/idle_tracker_service.dart`

ইউজারের শেষ অ্যাক্টিভিটি ট্র্যাক করে এবং নির্দিষ্ট সময় পর রিমাইন্ডার ট্রিগার করে।

```dart
class IdleTrackerService {
  static const _lastActivityKey = 'last_activity_time';
  static const _consecutiveRemindersKey = 'consecutive_idle_reminders';
  static const _lastInAppReminderKey = 'last_in_app_reminder_time';
  
  // Thresholds
  static const int inAppReminderHours = 4;     // ৪ ঘণ্টা পর in-app reminder
  static const int nativeReminderHours = 12;    // ১২ ঘণ্টা পর native notification
  static const int maxInAppReminders = 2;       // ২ বার in-app reminder, তারপর native
  
  // Methods
  static Future<void> recordActivity() async {}     // HomeScreen, QuizScreen ইত্যাদি থেকে কল
  static Future<bool> shouldShowInAppReminder() async {}  // In-app reminder দেখাবে?
  static Future<bool> shouldSendNativeNotification() async {}  // Native notification পাঠাবে?
  static Future<Duration> getIdleDuration() async {}  // কতক্ষণ idle?
  static Future<void> dismissReminder() async {}      // রিমাইন্ডার dismiss করলে রেকর্ড
}
```

**Hive Keys:**
- `last_activity_time` (String ISO8601) — শেষ অ্যাক্টিভিটি
- `consecutive_idle_reminders` (int) — কতবার consecutive reminder দেখানো হয়েছে
- `last_in_app_reminder_time` (String ISO8601) — শেষ In-app reminder কখন দেখানো হয়েছে

### 2. NotificationService Extension
`lib/services/notification_service.dart` — Existing file, edit

#### 2a. Custom Notification Channel (Native)

Android-এর জন্য আলাদা notification channel তৈরি করতে হবে যেখানে user-এর দেওয়া custom sound asset থাকবে।

```dart
// Android: User asset → android/app/src/main/res/raw/speakeasy_notification.mp3
// Android: ছোট .mp3 ফাইল (< 5 সেকেন্ড, high-quality)

const androidIdleDetails = AndroidNotificationDetails(
  'speakeasy_idle_reminder',
  'স্পিকইজি রিমাইন্ডার',
  channelDescription: 'ইউজারকে অ্যাপে ফিরিয়ে আনার জন্য রিমাইন্ডার',
  importance: Importance.high,
  priority: Priority.high,
  sound: RawResourceAndroidNotificationSound('speakeasy_notification'),
  icon: '@mipmap/ic_launcher',
);
```

#### 2b. New Method: `scheduleIdleReminder()`

```dart
Future<void> scheduleIdleReminder() async {
  // ইউজারের idle সময় অনুযায়ী মেসেজ জেনারেট করবে
  // Duolingo-র মতো একাধিক মেসেজ ভেরিয়েশন থাকবে
  // কাস্টম সাউন্ড চ্যানেলে নোটিফিকেশন দেখাবে
}
```

#### 2c. New Method: `cancelIdleReminders()`

User অ্যাপে ফিরলে পেন্ডিং ইডল নোটিফিকেশন ক্যান্সেল করবে।

### 3. SoundService Extension
`lib/services/sound_service.dart` — Existing file, edit

Notification সাউন্ডের জন্য নতুন এনাম এবং মেথড যোগ:

```dart
// New enum values in existing GameSoundEffect or separate enum
enum NotificationSound {
  reminder,
  characterCall,
}

// New methods
Future<void> playNotificationReminder() async {}  // user-এর musical tone
Future<void> playCharacterCall() async {}          // user-এর character sound
```

**Asset Paths:**
- `notification_reminder.mp3` → user-এর ভারতীয় মিউজিক্যাল টিউন
- `character_sound.mp3` → user-এর ক্যারেক্টার সাউন্ড

### 4. InAppReminderWidget (New File)
`lib/core/widgets/reminder_overlay.dart`

Duolingo-স্টাইল ইন-অ্যাপ রিমাইন্ডার ব্যানার।

**Features:**
- নিচ থেকে স্লাইড করে আসা সবুজ ব্যানার
- ইমোজি/ক্যারেক্টার আইকন
- টেক্সট: "সময় হয়েছে পড়ার! 📚" / "আজকে এখনো প্র্যাকটিস করেননি!"
- Custom sound `audioplayers` দিয়ে বাজবে
- ২টি বাটন: "শুরু করুন 🎯" (রুটিন) / "পরে ⏰" (dismiss)
- Auto-dismiss: ১০ সেকেন্ড পর নিজে থেকে চলে যাবে

**States:**
- `hidden` — দেখা যাচ্ছে না
- `showing` — ব্যানার visible
- `dismissed` — ইউজার dismiss করেছে (কিছুক্ষণের জন্য দেখাবে না)

### 5. IdleTrackerProvider (New File)
`lib/providers/idle_tracker_provider.dart`

Riverpod StateNotifier Provider:

```dart
class IdleTrackerState {
  final bool isIdle;
  final Duration idleDuration;
  final bool showingReminder;
}

class IdleTrackerNotifier extends StateNotifier<IdleTrackerState> {
  // IdleTrackerService কল করবে
  // Timer সেট করবে প্রতি ১৫ মিনিট পর চেক করবে
  // Reminder দেখানোর সিদ্ধান্ত নেবে
}
```

### 6. Provider Observers (HomeScreen)
`lib/features/home/screens/home_screen.dart` — Edit

- `HomeScreen.initState()`-এ IdleTrackerProvider সাবস্ক্রাইব করবে
- ইউজার কোনো screen এ গেলে `IdleTrackerService.recordActivity()` কল করবে
- Provider চেঞ্জ হলে `InAppReminderWidget` দেখাবে

### 7. Settings & Admin Togles
`lib/features/settings/screens/settings_screen.dart` — Edit

Settings screen-এ নতুন টগল:
- ইডল রিমাইন্ডার চালু/বন্ধ (ডিফল্ট: চালু)
- রিমাইন্ডার ফ্রিকোয়েন্সি: ৪/৮/১২/২৪ ঘণ্টা
- রিমাইন্ডার সাউন্ড চালু/বন্ধ

Admin config screen-এ optional toggle (যদি Firestore config থেকে কন্ট্রোল দরকার হয়)

## Data Flow

```
[অ্যাপ Öffnen]
    │
    ├──► IdleTrackerService.recordActivity()
    │       │
    │       └──► Hive: last_activity_time = now
    │
    ├──► Timer (প্রতি ১৫ মিনিট)
    │       │
    │       ├──► IdleTrackerService.shouldShowInAppReminder()
    │       │       │
    │       │       ├── true  → InAppReminderWidget.show() + SoundService.playNotificationReminder()
    │       │       │
    │       │       └── false → do nothing
    │       │
    │       └──► IdleTrackerService.shouldSendNativeNotification()
    │               │
    │               ├── true  → NotificationService.scheduleIdleReminder()
    │               │
    │               └── false → do nothing
    │
    └──► [ইউজার ব্যাক]
            │
            ├──► IdleTrackerService.recordActivity()
            ├──► NotificationService.cancelIdleReminders()
            └──► IdleTrackerService.resetConsecutiveReminders()
```

## Reminder Messages (Multi-language Support)

ইউজারের idle সময় অনুযায়ী বিভিন্ন মেসেজ র্যান্ডমলি দেখাবে:

**Bangla Messages:**
- "সময় হয়েছে পড়ার! 📚 আজকের লেসন অপেক্ষা করছে!"
- "আজকে এখনো প্র্যাকটিস করেননি? 🎯 মাত্র ৫ মিনিট!"
- "আপনার Streak বাঁচান! 🔥 এখনই শুরু করুন!"
- "নতুন লেসন যোগ হয়েছে! 📖 দেখে আসুন?"
- "আপনার Daily Word অপেক্ষা করছে! 💪"

**English Messages:**
- "Time to practice! 📚 Your lesson is waiting!"
- "Haven't practiced today? 🎯 Just 5 minutes!"
- "Save your streak! 🔥 Start now!"
- "New lesson added! 📖 Check it out!"

## Sound Assets (User Provides)

| Asset | Location | Format | Purpose |
|-------|----------|--------|---------|
| `speakeasy_notification.mp3` | `android/app/src/main/res/raw/` | MP3, < 5 sec, mono | Native notification channel sound |
| `speakeasy_notification.mp3` | `assets/audio/` | MP3 | In-app reminder sound (same or different) |
| `notification_character.mp3` | `assets/audio/` | MP3 | Character-specific sound |
| `speakeasy_notification.caf` | `ios/Runner/` | CAF (converted) | iOS notification sound |

**Android Setup:**
- User-provided .mp3 ফাইল `android/app/src/main/res/raw/speakeasy_notification.mp3`-তে রাখতে হবে
- অথবা ZCode নির্দেশিকা দেবে কোথায় রাখতে হবে

**iOS Setup:**
- iOS কাস্টম সাউন্ড limited (max 30 sec, specific formats)
- User .caf ফাইল তৈরি করে নির্দিষ্ট লোকেশনে রাখতে নির্দেশনা দেওয়া হবে

## File Change Summary

| File | Action | Description |
|------|--------|-------------|
| `lib/services/idle_tracker_service.dart` | **NEW** | Core idle tracking logic |
| `lib/services/notification_service.dart` | **EDIT** | Add custom sound channel + idle reminder methods |
| `lib/services/sound_service.dart` | **EDIT** | Add notification sound enum + play methods |
| `lib/core/widgets/reminder_overlay.dart` | **NEW** | Duolingo-style in-app reminder banner |
| `lib/providers/idle_tracker_provider.dart` | **NEW** | Riverpod state for idle tracking |
| `lib/providers/notification_provider.dart` | **EDIT** | Add idle reminder state/history |
| `lib/features/home/screens/home_screen.dart` | **EDIT** | Integrate idle tracker observer |
| `lib/features/settings/screens/settings_screen.dart` | **EDIT** | Add idle reminder toggles |
| `lib/main.dart` | **EDIT** | Initialize IdleTracker timer |
| `lib/core/constants/app_strings.dart` | **EDIT** | Add reminder message strings |
| `assets/audio/` | **NEW ASSETS** | notification_sound.mp3 (user provides) |
| `android/app/src/main/res/raw/` | **NEW ASSETS** | speakeasy_notification.mp3 (user provides) |

## Edge Cases

1. **User already on app:** যদি ইউজার active থাকে তাহলে native notification পাঠানো হবে না
2. **Multiple reminders একই দিনে:** consecutive_reminders ট্র্যাক করে, limit-এর বেশি না
3. **Notification tapped:** নোটিফিকেশন ট্যাপ করলে অ্যাপ Öffnen হবে, IdleTracker.reset() কল হবে
4. **App force close:** Hive-তে last_activity_time সেভ থাকায় app reopen করলে সঠিক idle time পাবে
5. **Streak already maintained:** আজকে streak maintained থাকলে native reminder না পাঠানো
6. **Settings disabled:** ইউজার যদি settings-এ idle reminder বন্ধ করে, কিছুই দেখানো হবে না

## Testing

1. **Unit Tests:**
   - IdleTrackerService — recordActivity, shouldShowInAppReminder, shouldSendNativeNotification
   - NotificationService — scheduleIdleReminder, cancelIdleReminders

2. **Widget Tests:**
   - InAppReminderWidget — show, hide, button tap, auto-dismiss

3. **Integration:**
   - HomeScreen → idle reminder shows after threshold
   - Settings → toggle on/off works
   - Sound plays on reminder

## iOS Caveat

iOS কাস্টম নোটিফিকেশন সাউন্ড সীমিত। iOS সাউন্ড অ্যাসেট হতে হবে:
- 30 সেকেন্ডের কম
- Specific format: Linear PCM, MA4 (IMA/ADPCM), μLaw, aLaw
- App bundle-তে থাকতে হবে
- User conversion script (`.mp3` → `.caf`) সরবরাহ করা হবে

iOS-এ in-app reminder সবসময় কাজ করবে (audioplayers দিয়ে), কিন্তু ব্যাকগ্রাউন্ড নোটিফিকেশন সাউন্ড iOS সীমাবদ্ধতা অনুযায়ী কাজ করবে।
