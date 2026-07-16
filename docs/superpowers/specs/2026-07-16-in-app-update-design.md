# In-App Soft Update — Google Play In-App Update API

**Date:** 2026-07-16
**App:** SpeakEasy (flutter_spoken_english_app)
**Author:** Kesh

## Problem

When a new version of SpeakEasy is published on Google Play Store, existing users do not receive any in-app notification about the update. Users may continue using an outdated version indefinitely, missing new features, improvements, and critical fixes.

## Goal

Integrate Google Play In-App Update API to show a native update prompt when a newer version is available on the Play Store. The update should be **soft (flexible)** — users can dismiss it and continue using the current version.

## Background

SpeakEasy already has a Force Update system via Firebase Remote Config (`ForceUpdateScreen` + `RemoteConfigService`), but it is a **hard-blocking** screen that prevents app usage. There is no soft/recommended update mechanism.

## Solution: Google Play In-App Update API

### Why this approach

- **Native Play Store experience** — uses Google's own update dialog
- **Automatic version detection** — no manual version tracking in Firebase
- **Flexible mode** — user can dismiss (soft update)
- **Immediate mode** — available for future force-update needs
- **Minimal code** — the Play Store handles all UI and state management

### Architecture

```
┌──────────────────────────────────────────────────────────┐
│                    App Startup Flow                       │
├──────────────────────────────────────────────────────────┤
│  1. main() initializes Firebase, Hive, services          │
│  2. runApp() → MaterialApp → SplashScreen                │
│                                                          │
│  SplashScreen._navigateToNext():                         │
│    ├── RemoteConfigService.getConfig() (existing)        │
│    │   ├── maintenanceMode? → MaintenanceScreen          │
│    │   ├── forceUpdate.enabled? → ForceUpdateScreen      │
│    │   └── (both existing)                               │
│    │                                                      │
│    └── NEW: InAppUpdateService.checkForUpdate()          │
│        ├── Play Store returns UPDATE_AVAILABLE?          │
│        │   ├── No → navigate normally                    │
│        │   ├── Yes (Flexible) → show native dialog       │
│        │   │   ├── User taps "Update" → Play Store       │
│        │   │   └── User taps "Later" → snooze 24h        │
│        │   └── Yes (Immediate) → full-screen forced      │
│        │                                                 │
│        └── Complete update → navigate normally           │
└──────────────────────────────────────────────────────────┘
```

### New Components

#### 1. `InAppUpdateService` (`lib/services/in_app_update_service.dart`)

A service class that wraps the `in_app_update` (or `google_play_in_app_update`) package.

**Methods:**

| Method | Description |
|--------|-------------|
| `checkForUpdate()` | Queries Play Store for available update. Returns whether update is available. |
| `startFlexibleUpdate()` | Shows native flexible update dialog (dismissible). |
| `startImmediateUpdate()` | Shows full-screen immediate update (non-dismissible). |
| `completeFlexibleUpdate()` | Completes a downloaded flexible update (restarts app). |
| `isUpdateAvailable()` | Quick check if an update exists (no UI). |

**Snooze Logic:**
- If user taps "Later", store current timestamp + 24 hours in Hive
- On next app open, check if snooze expired
- If not expired, skip the update check
- Snooze duration can be controlled via Remote Config

#### 2. Integration Point — `SplashScreen._navigateToNext()`

Insert update check after maintenance/force-update checks but before normal navigation.

```dart
// After force update check...
final inAppUpdateService = InAppUpdateService();
final hasUpdate = await inAppUpdateService.checkForUpdate();

// shouldShowUpdate() checks Remote Config enabled flag + snooze status
if (hasUpdate && await inAppUpdateService.shouldShowUpdate()) {
  await inAppUpdateService.startFlexibleUpdate();
  // Dialog dismissed (Later or Update) → continue to normal navigation
}

// Navigate normally
```

### Remote Config Changes

Add to Firestore `Config/app_settings`:

```json
{
  "inAppUpdate": {
    "enabled": true,
    "mode": "flexible",
    "snoozeHours": 24
  }
}
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `enabled` | bool | `true` | Master toggle for in-app update feature |
| `mode` | string | `"flexible"` | `"flexible"` (soft) or `"immediate"` (force) |
| `snoozeHours` | int | `24` | Hours before showing update prompt again after "Later" |

### Existing Code Changes

| File | Change |
|------|--------|
| `pubspec.yaml` | Add `in_app_update` dependency |
| `lib/services/in_app_update_service.dart` | **NEW** — create service |
| `lib/features/auth/screens/splash_screen.dart` | Insert update check in `_navigateToNext()` |
| `lib/services/remote_config_service.dart` | Add `getInAppUpdateConfig()` method |
| `lib/models/config/app_config_model.dart` | Add `InAppUpdateConfig` model |
| `lib/features/admin/screens/admin_config_screen.dart` | Add in-app update toggle to admin panel |

### User Experience

**Flexible Update (Soft):**

```
User opens app
  ↓
Native Google Play dialog appears:
┌──────────────────────────────────────┐
│  🔄 Update available                 │
│  A new version of SpeakEasy          │
│  is available. Update now?           │
│                                      │
│  Size: ~15 MB                        │
│                                      │
│      [Later]    [Update]             │
└──────────────────────────────────────┘
  ↓
[Later] → dismiss, snooze 24h
[Update] → opens Play Store page
  ↓
After update downloaded:
  "Install" button → app restarts with new version
```

### Testing

| Test Scenario | Method |
|---------------|--------|
| No update available | Set `inAppUpdate.enabled = false` in Remote Config |
| Soft update available | Internal Test Track on Play Console |
| User taps "Later" | Verify Hive snooze timestamp |
| Snooze expired | Fast-forward Hive timestamp |
| Immediate mode | Set `mode: "immediate"` in Remote Config |
| Error handling | No internet → gracefully skip, navigate normally |

### Future Considerations

- **iOS Support**: If iOS is added later, use a separate in-app update mechanism (App Store doesn't offer a native API for this; would need server-side version check)
- **Version Notes**: Could show changelog/release notes before the update dialog
- **In-app Banner**: Instead of full dialog, could show a dismissible top banner (but native dialog is simpler and better UX)

### Out of Scope (for this iteration)

- iOS support
- In-app update banner widget
- Changelog display before update
- Play Store review prompting
