import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// UMP (User Messaging Platform) consent manager.
///
/// Implements Google's required ad-consent flow BEFORE any ad request is
/// made:
///   1. Request consent info update (no-op cost for non-EEA users).
///   2. Show the Google-rendered consent form if/when required (EEA/UK).
///   3. Expose [canRequestAds] so AdService only initialises when allowed.
///   4. Provide a re-openable privacy options entry point for Settings.
///
/// The consent form itself (and the privacy policy URL it links to) is
/// configured remotely in AdMob → Privacy & messaging. Nothing to hardcode
/// here — this class only drives the SDK.
class ConsentService {
  static final ConsentService _instance = ConsentService._();
  factory ConsentService() => _instance;
  ConsentService._();

  final ConsentInformation _consentInfo = ConsentInformation.instance;

  bool _gatheredThisSession = false;

  /// True once consent info was refreshed (and the form, if required,
  /// was shown) at least once in this app session.
  bool get gatheredThisSession => _gatheredThisSession;

  /// Debug-only: set to true to simulate an EEA device and preview the
  /// consent form on an emulator. NEVER enable in release builds.
  static const bool _debugForceEeaGeography = false;

  /// Whether Google currently requires a privacy-options entry point
  /// (true for EEA/UK users — the Settings screen must then show a
  /// "Privacy Options" tile).
  Future<bool> isPrivacyOptionsRequired() async =>
      await _consentInfo.getPrivacyOptionsRequirementStatus() ==
      PrivacyOptionsRequirementStatus.required;

  /// Whether the app is allowed to make ad requests right now.
  Future<bool> canRequestAds() => _consentInfo.canRequestAds();

  /// Step 1 + 2 of Google's flow. Safe to call on every app start —
  /// the form only appears when Google determines consent is required
  /// and not yet given; otherwise this completes silently in <1s.
  ///
  /// Always completes (never throws), even offline — callers should then
  /// consult [canRequestAds] which may still be true from a prior session.
  Future<void> gatherConsent() {
    if (_gatheredThisSession) return Future.value();
    _gatheredThisSession = true; // set early so concurrent callers coalesce

    final completer = Completer<void>();

    final params = ConsentRequestParameters(
      consentDebugSettings: kDebugMode && _debugForceEeaGeography
          ? ConsentDebugSettings(
              debugGeography: DebugGeography.debugGeographyEea,
            )
          : null,
    );

    _consentInfo.requestConsentInfoUpdate(
      params,
      () async {
        try {
          await ConsentForm.loadAndShowConsentFormIfRequired((formError) {
            if (formError != null) {
              debugPrint('ConsentService: form error — $formError');
            }
          });
          _gatheredThisSession = true;
        } catch (e) {
          debugPrint('ConsentService: loadAndShowConsentFormIfRequired threw — $e');
        }
        if (!completer.isCompleted) completer.complete();
      },
      (FormError error) {
        // Offline / transient failures: continue so the caller can still
        // check canRequestAds() (carried over from a previous session).
        debugPrint('ConsentService: consent info update failed — $error');
        if (!completer.isCompleted) completer.complete();
      },
    );

    return completer.future;
  }

  /// Opens the privacy-options form from the Settings entry point.
  /// Errors are surfaced via the callback and logged (never thrown).
  Future<void> showPrivacyOptionsForm() async {
    try {
      await ConsentForm.showPrivacyOptionsForm((formError) {
        if (formError != null) {
          debugPrint('ConsentService: privacy options form error — $formError');
        }
      });
    } catch (e) {
      debugPrint('ConsentService: showPrivacyOptionsForm threw — $e');
    }
  }
}
