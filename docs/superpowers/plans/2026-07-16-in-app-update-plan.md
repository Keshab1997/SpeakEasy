# In-App Soft Update — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate Google Play In-App Update API so users see a native update dialog when a new version is available on Play Store.

**Architecture:** A new `InAppUpdateService` wraps the `in_app_update` package. The `SplashScreen._navigateToNext()` method calls it after the existing maintenance/force-update checks. A new `InAppUpdateConfig` model lives under the existing `AppConfig` in Firestore remote config. The admin config screen gains a toggle for the feature.

**Tech Stack:** Flutter, `in_app_update` package, Firebase Firestore (Remote Config), Hive (snooze persistence)

---

### Task 1: Add `in_app_update` dependency

**Files:**
- Modify: `pubspec.yaml:50-70`

- [ ] **Step 1: Add dependency**

Edit `pubspec.yaml` — after the existing `url_launcher` line, add:

```yaml
  in_app_update: ^4.1.1
```

- [ ] **Step 2: Install the package**

Run:
```bash
cd "/Users/keshabsarkar/Vs Code Apps/SpeakEasy" && flutter pub get
```

Expected: Package resolves and downloads successfully.

- [ ] **Step 3: Commit**

```bash
cd "/Users/keshabsarkar/Vs Code Apps/SpeakEasy" && git add pubspec.yaml pubspec.lock && git commit -m "chore: add in_app_update dependency"
```

---

### Task 2: Add InAppUpdateConfig model

**Files:**
- Modify: `lib/models/config/app_config_model.dart`

Add a new model class `InAppUpdateConfig` and reference it from `AppConfig`.

- [ ] **Step 1: Add InAppUpdateConfig class**

After the `ForceUpdateInfo` class (around line 175), add:

```dart
@immutable
class InAppUpdateConfig {
  final bool enabled;
  final String mode; // "flexible" or "immediate"
  final int snoozeHours;

  const InAppUpdateConfig({
    this.enabled = true,
    this.mode = 'flexible',
    this.snoozeHours = 24,
  });

  factory InAppUpdateConfig.fromMap(Map<String, dynamic> map) {
    return InAppUpdateConfig(
      enabled: map['enabled'] as bool? ?? true,
      mode: map['mode'] as String? ?? 'flexible',
      snoozeHours: map['snoozeHours'] as int? ?? 24,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'mode': mode,
      'snoozeHours': snoozeHours,
    };
  }
}
```

- [ ] **Step 2: Wire into AppConfig**

Modify the `AppConfig` class — add the `inAppUpdate` field and update `fromMap`/`toMap`:

```dart
class AppConfig {
  final FeatureToggles featureToggles;
  final ForceUpdateInfo forceUpdate;
  final MaintenanceModeInfo maintenanceMode;
  final GameplaySettings gameplay;
  final InAppUpdateConfig inAppUpdate; // ← NEW

  const AppConfig({
    this.featureToggles = const FeatureToggles(),
    this.forceUpdate = const ForceUpdateInfo(),
    this.maintenanceMode = const MaintenanceModeInfo(),
    this.gameplay = const GameplaySettings(),
    this.inAppUpdate = const InAppUpdateConfig(), // ← NEW
  });

  factory AppConfig.fromMap(Map<String, dynamic> map) {
    return AppConfig(
      featureToggles: FeatureToggles.fromMap(
        map['featureToggles'] as Map<String, dynamic>? ?? {},
      ),
      forceUpdate: ForceUpdateInfo.fromMap(
        map['forceUpdate'] as Map<String, dynamic>? ?? {},
      ),
      maintenanceMode: MaintenanceModeInfo.fromMap(
        map['maintenanceMode'] as Map<String, dynamic>? ?? {},
      ),
      gameplay: GameplaySettings.fromMap(
        map['gameplay'] as Map<String, dynamic>? ?? {},
      ),
      inAppUpdate: InAppUpdateConfig.fromMap( // ← NEW
        map['inAppUpdate'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'featureToggles': featureToggles.toMap(),
      'forceUpdate': forceUpdate.toMap(),
      'maintenanceMode': maintenanceMode.toMap(),
      'gameplay': gameplay.toMap(),
      'inAppUpdate': inAppUpdate.toMap(), // ← NEW
    };
  }
}
```

- [ ] **Step 3: Add import**

Ensure `package:flutter/foundation.dart` is imported at the top of `app_config_model.dart` (for `@immutable`):

```dart
import 'package:flutter/foundation.dart';
```

- [ ] **Step 4: Commit**

```bash
cd "/Users/keshabsarkar/Vs Code Apps/SpeakEasy" && git add lib/models/config/app_config_model.dart && git commit -m "feat: add InAppUpdateConfig model"
```

---

### Task 3: Add getInAppUpdateConfig to RemoteConfigService

**Files:**
- Modify: `lib/services/remote_config_service.dart`

- [ ] **Step 1: Add method**

After `getForceUpdateInfo()` (around line 73), add:

```dart
  /// Returns the in-app update configuration.
  static Future<InAppUpdateConfig> getInAppUpdateConfig() async {
    final config = await getConfig();
    return config.inAppUpdate;
  }
```

Also add the import at the top of the file if not present:

```dart
import '../models/config/app_config_model.dart';
```

- [ ] **Step 2: Commit**

```bash
cd "/Users/keshabsarkar/Vs Code Apps/SpeakEasy" && git add lib/services/remote_config_service.dart && git commit -m "feat: add getInAppUpdateConfig to RemoteConfigService"
```

---

### Task 4: Create InAppUpdateService

**Files:**
- Create: `lib/services/in_app_update_service.dart`

This is the core service that wraps the `in_app_update` package and handles snooze logic via Hive.

- [ ] **Step 1: Write the full service**

Create `lib/services/in_app_update_service.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/config/app_config_model.dart';
import 'remote_config_service.dart';

/// Manages Google Play In-App Update flows.
///
/// Supports both flexible (soft) and immediate (force) update modes.
/// Snooze logic is persisted via Hive to avoid prompting too often.
class InAppUpdateService {
  static const _snoozeBoxName = 'in_app_update';
  static const _snoozeKey = 'snooze_until';

  /// Checks if an update is available on Google Play Store.
  ///
  /// Returns true if an update is available and ready to show.
  /// Returns false on error or if no update is available.
  Future<bool> isUpdateAvailable() async {
    try {
      final updateInfo = await InAppUpdateManager.checkForUpdate();
      return updateInfo.updateAvailability == UpdateAvailability.updateAvailable;
    } catch (e) {
      debugPrint('InAppUpdateService: check failed — $e');
      return false;
    }
  }

  /// Checks whether the update prompt should be shown based on:
  /// 1. Remote Config [InAppUpdateConfig.enabled] flag
  /// 2. Snooze expiry status
  Future<bool> shouldShowUpdate() async {
    // Check remote config enable flag
    final config = await RemoteConfigService.getInAppUpdateConfig();
    if (!config.enabled) return false;

    // Check snooze
    return isSnoozeExpired();
  }

  /// Returns true if the snooze period has elapsed (or no snooze is set).
  bool isSnoozeExpired() {
    try {
      final box = Hive.box(_snoozeBoxName);
      final snoozeUntil = box.get(_snoozeKey) as DateTime?;
      if (snoozeUntil == null) return true;
      return DateTime.now().isAfter(snoozeUntil);
    } catch (e) {
      debugPrint('InAppUpdateService: snooze check failed — $e');
      return true; // On error, allow showing
    }
  }

  /// Sets a snooze timestamp [hours] from now.
  Future<void> setSnooze(int hours) async {
    try {
      final box = await Hive.openBox(_snoozeBoxName);
      await box.put(_snoozeKey, DateTime.now().add(Duration(hours: hours)));
    } catch (e) {
      debugPrint('InAppUpdateService: snooze save failed — $e');
    }
  }

  /// Clears any existing snooze (for testing/admin reset).
  Future<void> clearSnooze() async {
    try {
      final box = await Hive.openBox(_snoozeBoxName);
      await box.delete(_snoozeKey);
    } catch (e) {
      debugPrint('InAppUpdateService: snooze clear failed — $e');
    }
  }

  /// Starts a flexible (soft) update flow.
  ///
  /// Displays a native Play Store dialog that the user can dismiss.
  /// If the user dismisses by tapping "Later", [setSnooze] is called.
  Future<void> startFlexibleUpdate() async {
    try {
      final config = await RemoteConfigService.getInAppUpdateConfig();

      await InAppUpdateManager.startFlexibleUpdate(
        listener: (status) {
          // When download completes, prompt user to install
          if (status == FlexibleUpdateUpdateStatus.productUpdateComplete) {
            InAppUpdateManager.completeFlexibleUpdate().then((_) {
              debugPrint('InAppUpdateService: update completed');
            }).catchError((e) {
              debugPrint('InAppUpdateService: complete failed — $e');
            });
          }
        },
      );

      // Set snooze regardless (in case user dismissed it)
      // The snooze ensures we don't show it again too soon
      await setSnooze(config.snoozeHours);
    } catch (e) {
      // If user is on a non-Play Store build or error occurred
      debugPrint('InAppUpdateService: flexible update failed — $e');
    }
  }

  /// Starts an immediate (forced) update flow.
  ///
  /// Full-screen native UI — user cannot dismiss.
  Future<void> startImmediateUpdate() async {
    try {
      await InAppUpdateManager.startImmediateUpdate();
    } catch (e) {
      debugPrint('InAppUpdateService: immediate update failed — $e');
    }
  }
}
```

- [ ] **Step 2: Register the Hive box in main.dart**

In `main.dart`, after `await HiveService.initialize();`, add:

```dart
  // Open the in-app update Hive box for snooze persistence
  await Hive.openBox('in_app_update');
```

- [ ] **Step 3: Commit**

```bash
cd "/Users/keshabsarkar/Vs Code Apps/SpeakEasy" && git add lib/services/in_app_update_service.dart lib/main.dart && git commit -m "feat: create InAppUpdateService with flexible update support"
```

---

### Task 5: Integrate into SplashScreen

**Files:**
- Modify: `lib/features/auth/screens/splash_screen.dart`

Insert the in-app update check in `_navigateToNext()` after force update check but before normal navigation.

- [ ] **Step 1: Add import**

At the top of `splash_screen.dart`, add:

```dart
import '../../../services/in_app_update_service.dart';
```

- [ ] **Step 2: Insert update check**

In `_navigateToNext()`, after the force update block (after line 112, before the `catch`), add:

```dart
      // Check for soft / in-app update (Google Play In-App Update)
      final inAppService = InAppUpdateService();
      final hasUpdate = await inAppService.isUpdateAvailable();
      if (hasUpdate && await inAppService.shouldShowUpdate()) {
        await inAppService.startFlexibleUpdate();
        // After dialog is dismissed, continue to normal navigation
      }
```

The complete modified `_navigateToNext()` should look like this:

```dart
  Future<void> _navigateToNext(UserModel? user) async {
    if (_navigated) return;
    _navigated = true;

    // Check if onboarding has been completed
    if (!HiveService.isOnboardingCompleted()) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const IntroScreen()),
        );
      }
      return;
    }

    // Fetch remote config to check maintenance/force-update status
    try {
      final config = await RemoteConfigService.getConfig();

      // Check maintenance mode first
      if (config.maintenanceMode.enabled) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => MaintenanceScreen(
                message: config.maintenanceMode.message,
              ),
            ),
          );
        }
        return;
      }

      // Check force update
      if (config.forceUpdate.enabled) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ForceUpdateScreen(
                updateInfo: config.forceUpdate,
              ),
            ),
          );
        }
        return;
      }

      // ── NEW: Check for soft / in-app update ──
      final inAppService = InAppUpdateService();
      final hasUpdate = await inAppService.isUpdateAvailable();
      if (hasUpdate && await inAppService.shouldShowUpdate()) {
        await inAppService.startFlexibleUpdate();
        // After dialog is dismissed, continue to normal navigation
      }
    } catch (_) {
      // If remote config fails, proceed with normal flow
    }

    // Normal navigation
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => user != null
              ? const MainNavigationScreen()
              : const LoginScreen(),
        ),
      );
    }
  }
```

- [ ] **Step 3: Commit**

```bash
cd "/Users/keshabsarkar/Vs Code Apps/SpeakEasy" && git add lib/features/auth/screens/splash_screen.dart && git commit -m "feat: integrate in-app update check in SplashScreen"
```

---

### Task 6: Add in-app update toggle to Admin Config Screen

**Files:**
- Modify: `lib/features/admin/screens/admin_config_screen.dart`

- [ ] **Step 1: Read current admin config screen to understand pattern**

```bash
cd "/Users/keshabsarkar/Vs Code Apps/SpeakEasy" && grep -n "forceUpdate\|ForceUpdate\|maintenanceMode\|MaintenanceMode" lib/features/admin/screens/admin_config_screen.dart
```

- [ ] **Step 2: Add in-app update toggle section**

Following the existing pattern (e.g., force update or maintenance mode), add a toggle for `inAppUpdate.enabled` and a text field for `snoozeHours`.

(Read the file first to match the exact pattern, then edit accordingly.)

- [ ] **Step 3: Commit**

```bash
cd "/Users/keshabsarkar/Vs Code Apps/SpeakEasy" && git add lib/features/admin/screens/admin_config_screen.dart && git commit -m "feat: add in-app update toggle to admin config"
```

---

### Task 7: Build & verify

- [ ] **Step 1: Run the Flutter analyzer**

```bash
cd "/Users/keshabsarkar/Vs Code Apps/SpeakEasy" && flutter analyze
```

Expected: No errors or warnings related to the new code.

- [ ] **Step 2: Build APK to verify compilation**

```bash
cd "/Users/keshabsarkar/Vs Code Apps/SpeakEasy" && flutter build apk --debug
```

Expected: Build succeeds with no errors.

- [ ] **Step 3: Commit any final fixes**

```bash
cd "/Users/keshabsarkar/Vs Code Apps/SpeakEasy" && git add -A && git commit -m "chore: fix analysis issues after in-app update integration"
```

---

## Self-Review Checklist

- [ ] **Spec coverage:** Does every spec requirement have a corresponding task?
  - ✅ `InAppUpdateService` — Task 4
  - ✅ SplashScreen integration — Task 5
  - ✅ Remote Config integration — Task 3
  - ✅ AppConfig model — Task 2
  - ✅ Admin config toggle — Task 6
  - ✅ Snooze logic — Task 4 (built into InAppUpdateService)
  - ✅ `in_app_update` package — Task 1
- [ ] **Placeholder scan:** No TODOs, TBDs, or vague instructions.
- [ ] **Type consistency:** Method signatures match across tasks (`shouldShowUpdate()`, `isUpdateAvailable()`, `startFlexibleUpdate()`, etc.)
