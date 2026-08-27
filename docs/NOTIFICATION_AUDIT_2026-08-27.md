# 🔔 Automatic Notification System — Audit Report
**Date:** 2026-08-27 · **Repo:** Keshab1997/SpeakEasy @ `6f6c0ab` (v1.0.22+22)
**Scope:** local scheduled notifications, WorkManager background tasks, idle/re-engagement reminders, OneSignal push, notification history + badge.

> Static code review only — Flutter SDK is not installed in the sandbox, so no `flutter analyze` / device test was run.

---

## Summary

| # | Issue | Severity | Symptom user dekhbe |
|---|---|---|---|
| 1 | Settings sub-toggles never reschedule/cancel alarms | 🔴 Critical | Toggle off korleo notification ashe; on korleo ashe na |
| 2 | Scheduled notifications never saved to history | 🔴 Critical | Notification ase, kintu history/badge khali |
| 3 | Push received in background/killed state not saved to history | 🔴 Critical | Same as above, OneSignal push er jonno |
| 4 | Word of the Day content freezes (stale repeat) | 🟠 High | Roj same word show kore |
| 5 | Notification tap → no navigation (no navigatorKey) | 🟠 High | Tap korle sudhu app khole, screen e jay na |
| 6 | Cold-start tap (app killed) completely unhandled | 🟠 High | Same |
| 7 | Badge count stale until app restart | 🟠 High | Unread badge update hoy na |
| 8 | `ExistingPeriodicWorkPolicy.keep` freezes old schedule | 🟡 Medium | Purono user der frequency change kokhono apply hoy na |
| 9 | Background isolate calls `requestPermissions()` + network | 🟡 Medium | WorkManager task fail/slow, Hive lock risk |
| 10 | Re-engagement `networkType.connected` constraint | 🟡 Medium | Offline thakle reminder ashe na |
| 11 | Streak milestone notification dead code | 🟢 Low | Feature bondho |
| 12 | Missing `<service>`/exact-alarm fallback + POST_NOTIFICATIONS flow gaps | 🟢 Low | Android 14/15 e ochena behaviour |

---

## 🔴 1. Settings toggles Hive te lekhe, kintu schedule update kore na
**File:** `lib/features/settings/screens/settings_screen.dart:152,164,176,200,220`

```dart
await HiveService.setDailyWordNotification(val);   // ← that's all
```

`_scheduleAll()` sudhu `initialize()` ar `rescheduleOnAppOpen()` theke call hoy.
Consequence:
- **OFF kora → notification bondho hoy na.** Alarm already `zonedSchedule`-e boshe ache with `DateTimeComponents.time`, tai seta rojkar moto firte thakbe.
- **ON kora → kichu hoy na** porer app-launch porjonto.
- Idle-reminder frequency slider change → next 6h WorkManager cycle porjonto (or restart) effect nei.

**Fix:** `NotificationService`-e ekta public `rescheduleNow()` (wrapper over `_scheduleAll`) add koro ebong protita toggle/slider `onChanged`-e Hive write er por seta await koro.

---

## 🔴 2. Scheduled (daily) notification kokhono history te save hoy na
**File:** `lib/services/notification_service.dart:409-475` (`_scheduleDailyAt`)

`showCustomNotification`, `showLocalNotification`, `scheduleIdleReminder`, `showStreakMilestoneNotification` — shob `_saveNotificationToHistory()` call kore.
Kintu `_scheduleDailyAt()` kore **na**. Word of the Day (9 AM), Practice Reminder (7 PM), Streak Saver (8 PM) — ei 3-tai app er main automatic notification, ar egulo history te ashe na, unread badge o bare na.

Docs (`NOTIFICATION_SYSTEM_GUIDE.md`) claim kore "Automatic history saving for all notifications" — code er sathe mismatch.

**Kono easy fix nei ekdom same jaygay**, karon alarm fire hoy OS level e (app dead thakte pare). Two options:
- **(a)** `flutter_local_notifications`-er `onDidReceiveBackgroundNotificationResponse` sudhu *tap*-e fire kore — sufficient noy.
- **(b) Recommended:** app open howar somoy "catch-up" logic — je scheduled slots (9:00/19:00/20:00) last-seen timestamp er pore pass hoye geche, segulo history te backfill kore dao (`saveNotificationToHistoryIfNew` diye dedupe, id = `daily_word_2026-08-27` format).

---

## 🔴 3. Killed/background state-e asha OneSignal push history te ashe na
**File:** `lib/services/onesignal_service.dart:61` (`addForegroundWillDisplayListener`)

Sudhu **foreground** listener theke `_saveToHistory()` call hoy. App background/killed thakle native OneSignal service notification dekhay kintu Dart listener chole na → history missed.

**Fix:** `addClickListener`-eo `_saveToHistory(notif)` call koro (dedupe already ache via `saveNotificationToHistoryIfNew`), ebong app resume-e OneSignal REST/`OneSignal.Notifications` cached list na thakle at least tap-based backfill rakho.

---

## 🟠 4. Word of the Day er content prothom schedule-e freeze hoye jay
**File:** `lib/services/notification_service.dart:337-370`

```dart
final todayWord = await DailyWordService.getTodayWord();
... _scheduleDailyAt(..., body: '${todayWord.word} → ...',
      matchDateTimeComponents: DateTimeComponents.time)
```

`DateTimeComponents.time` mane ekta **static text** roj repeat hobe. User jodi 5 din app na khole, 5 din-i **same word** notification ashbe. "Word of the **Day**" er point-tai chole jay.

**Fix:** WorkManager-e ekta daily task (or `_scheduleDailyAt` er bodole next-24h one-shot chain) diye protidin fresh word niye re-schedule koro; othoba generic body ("আজকের নতুন শব্দ দেখুন") use koro jate stale na dekhay.

---

## 🟠 5 & 6. Notification tap → navigation kaj kore na
**File:** `lib/services/notification_service.dart:69-88`, `lib/services/onesignal_service.dart:97-115`

Duitai comment kore rekheche: *"navigation requires a global navigator key... Since the app doesn't have one"* — ar sotti-i codebase-e kono `navigatorKey` nei (grep: 0 hit). Tap korle sudhu `debugPrint` hoy.
Ekta pura `NotificationRouter` (`lib/features/home/widgets/notification_router.dart`) lekha ache — kintu seta **sudhu in-app history screen** theke use hoy.

Aro: `getNotificationAppLaunchDetails()` kothao call hoy na → app **killed** obosthay notification tap korle payload puropuri hariye jay.
`onDidReceiveBackgroundNotificationResponse` o set kora nei.

**Fix:**
1. `final navigatorKey = GlobalKey<NavigatorState>();` → `MaterialApp(navigatorKey: navigatorKey)`.
2. `_navigateFromPayload` → `NotificationRouter.navigate(navigatorKey.currentContext!, item)`.
3. `main()`-e `getNotificationAppLaunchDetails()` check kore pending payload first frame er por handle koro.

---

## 🟠 7. Unread badge stale thake
**File:** `lib/providers/notification_provider.dart:79-87`

`refreshFromHive()` ar `notifyExternalUpdate()` — **kothao call hoy na** (dead code). Kono `AppLifecycleState.resumed` listener nei (grep: 0 hit).
Fole background isolate / OneSignal jodi Hive te notification lekhe, home screen er badge ekhono purono count dekhabe next full restart porjonto.

**Extra risk:** Hive **isolate-safe noy**. WorkManager background isolate ar main isolate duitai same box open kore likhle **write loss / lock exception** hote pare. Background isolate theke direct Hive write ta risky — better: background isolate sudhu notification dekhak, ar "pending" info ekta small separate file/box e likhuk, main isolate resume-e merge koruk.

---

## 🟡 8. `ExistingPeriodicWorkPolicy.keep`
**File:** `lib/main.dart:142,155`

workmanager 0.10 er changelog explicitly bole: default `KEEP` → `UPDATE` change kora hoyeche karon *"periodic tasks running at wrong frequency when re-registered"*. `keep` rekhe dile purono install e frequency/constraints change kokhono apply hobe na.
**Fix:** `ExistingPeriodicWorkPolicy.update`.

---

## 🟡 9. Background isolate-e bhari kaj
**File:** `lib/services/workmanager_tasks.dart:48-52` → `NotificationService().initialize()`

`initialize()` background isolate-e:
- `requestPermissions()` call kore → Android e permission dialog er jonno **Activity dorkar**, background e eta fail kore (best case) ba hang kore.
- tarpor `_scheduleAll()` → `DailyWordService.getTodayWord()` (**network call**) → constraint `networkType.notRequired` er idle task offline chalale exception, ar `cancelAllScheduled()` age-i chole geche → **shob alarm cancel hoye reschedule fail** hote pare. Eta "notification hothat bondho hoye gelo" er strong candidate.

**Fix:** ekta `initializeForBackground()` variant banaw je sudhu plugin init + channel create kore — permission request ar `_scheduleAll()` chara.

---

## 🟡 10. Re-engagement task-e `networkType.connected`
**File:** `lib/main.dart:139-141`
Re-engagement check-e kono network lagena (sudhu Hive date compare + local notification). Constraint thakle offline user — jara ekdom-i inactive — tarai notification pabe na. **Fix:** `NetworkType.notRequired`.

---

## 🟢 11. Streak milestone notification dead code
`showStreakMilestoneNotification()` (line 282) codebase-er kothao call hoy na. `_streakMilestoneId` (1002) `cancelAllScheduled()`-e cancel hoy jodio seta kokhono schedule-i hoy na.

## 🟢 12. Chhoto jinis
- `AndroidManifest.xml`-e `ScheduledNotificationReceiver` + boot receiver ache ✅, kintu `com.dexterous...ActionBroadcastReceiver` nei (action buttons add korle lagbe).
- `USE_EXACT_ALARM` declare kora ache — Play Store ei permission er jonno **justification** chay; SpeakEasy er use-case (reminder) Google er allowed list-e nei, `SCHEDULE_EXACT_ALARM` + inexact fallback safer. Rejection risk.
- `canScheduleExactNotifications()` false hole `requestExactAlarmsPermission()` call kore, kintu result ignore kore exact mode-eই schedule kore → Android 14+ e silently fail korte pare. `AndroidScheduleMode.inexactAllowWhileIdle` fallback rakho.
- `tz.setLocalLocation('Asia/Kolkata')` hardcoded — bidesher user der jonno somoy off hobe (target audience Bengali, tai probably intentional).

---

## Suggested fix order (impact ÷ effort)
1. **#1** toggle → `rescheduleNow()` (30 min, biggest visible fix)
2. **#8 + #10** WorkManager policy/constraint (5 min)
3. **#9** background-safe init (30 min, stops silent breakage)
4. **#5/#6** navigatorKey + launch details (1 hr)
5. **#2/#3/#7** history backfill + lifecycle refresh (2 hr)
6. **#4** daily word freshness (1 hr)
