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
  Future<bool> isUpdateAvailable() async {
    try {
      final updateInfo = await InAppUpdate.checkForUpdate();
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
    final config = await RemoteConfigService.getInAppUpdateConfig();
    if (!config.enabled) return false;
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
      return true;
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
      final result = await InAppUpdate.startFlexibleUpdate();

      if (result == AppUpdateResult.success) {
        await InAppUpdate.completeFlexibleUpdate();
        debugPrint('InAppUpdateService: update completed');
      }

      // Set snooze regardless (in case user dismissed it)
      await setSnooze(config.snoozeHours);
    } catch (e) {
      debugPrint('InAppUpdateService: flexible update failed — $e');
    }
  }

  /// Starts an immediate (forced) update flow.
  ///
  /// Full-screen native UI — user cannot dismiss.
  Future<void> startImmediateUpdate() async {
    try {
      await InAppUpdate.performImmediateUpdate();
    } catch (e) {
      debugPrint('InAppUpdateService: immediate update failed — $e');
    }
  }
}
