import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'consent_service.dart';

class AdService {
  static final AdService _instance = AdService._();
  factory AdService() => _instance;
  AdService._();

  bool _initialized = false;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  // Guards so two full-screen ads can never be on screen at once. Showing a
  // second ad while one is still up (or navigating away mid-ad) crashes the
  // native ad SDK on some Android devices.
  bool _interstitialShowing = false;
  bool _rewardedShowing = false;

  // ── Ad Unit IDs ──
  // Debug → test ads, Release → real ads (safe from accidental bans)
  static const String _testBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testInterstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';
  static const String _testRewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917';

  static const String _realBannerAdUnitId = 'ca-app-pub-4216917764852377/2336103429';
  static const String _realInterstitialAdUnitId = 'ca-app-pub-4216917764852377/5836364739';
  static const String _realRewardedAdUnitId = 'ca-app-pub-4216917764852377/1259624233';

  /// Returns appropriate ad unit IDs based on build mode.
  static String get _bannerAdUnitId =>
      kReleaseMode ? _realBannerAdUnitId : _testBannerAdUnitId;
  static String get _interstitialAdUnitId =>
      kReleaseMode ? _realInterstitialAdUnitId : _testInterstitialAdUnitId;
  static String get _rewardedAdUnitId =>
      kReleaseMode ? _realRewardedAdUnitId : _testRewardedAdUnitId;

  /// Google-recommended startup flow:
  /// consent → SDK init → preload fullscreen ads.
  ///
  /// Safe to call on every app start and from multiple places — everything
  /// below is idempotent. Ad requests only happen after consent allows it.
  Future<void>? _initInFlight;

  Future<void> initializeWithConsent() {
    if (_initialized) return Future.value();
    // Collapse concurrent callers (e.g. several banner widgets starting
    // together) into a single consent+init sequence.
    final inFlight = _initInFlight;
    if (inFlight != null) return inFlight;

    final future = _initializeWithConsentInternal();
    _initInFlight = future;
    return future.whenComplete(() => _initInFlight = null);
  }

  Future<void> _initializeWithConsentInternal() async {
    // Refreshes consent info; shows the UMP form only when required (EEA/UK).
    // Never throws — offline failures are handled inside.
    await ConsentService().gatherConsent();

    if (!await ConsentService().canRequestAds()) {
      debugPrint('AdService: consent not obtained — ads disabled this session');
      return;
    }

    await initialize();

    // Preload fullscreen ads so quiz/game-over interstitials and rewarded
    // hints are ready instantly.
    unawaited(loadInterstitialAd());
    unawaited(loadRewardedAd());
  }

  /// Idempotent UI-facing guard. Returns true when the SDK is initialised
  /// AND ad requests are permitted — otherwise no ad request should be made.
  Future<bool> ensureInitialized() async {
    if (!_initialized) await initializeWithConsent();
    return _initialized;
  }

  /// Initialize AdMob SDK
  Future<void> initialize() async {
    if (_initialized) return;
    await MobileAds.instance.initialize();

    // Register test devices so they always receive test ads
    // (even with real ad unit IDs — safe for testing)
    if (!kReleaseMode) {
      final config = RequestConfiguration(
        testDeviceIds: [
          '3C27A9DBAE4BE566F6362A1D2DEC00A1', // Realme RMX3870
        ],
      );
      MobileAds.instance.updateRequestConfiguration(config);
    }

    _initialized = true;
  }

  // ════════════════════════════════════════════
  //  BANNER AD
  // ════════════════════════════════════════════

  /// Create a banner ad widget. Call this inside a StatefulWidget to manage
  /// the [AdWidget] lifecycle properly.
  BannerAd createBannerAd() {
    return BannerAd(
      adUnitId: _bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {},
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    );
  }

  // ════════════════════════════════════════════
  //  INTERSTITIAL AD
  // ════════════════════════════════════════════

  /// Load an interstitial ad
  Future<void> loadInterstitialAd() async {
    if (!await ensureInitialized()) return;
    await InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
        },
      ),
    );
  }

  /// Show the loaded interstitial ad. Returns true if an ad was shown.
  ///
  /// The returned future completes only AFTER the user dismisses the
  /// full-screen ad (or after it fails to show). Callers can therefore
  /// navigate *after* the ad is gone — replacing a route while a full-screen
  /// ad is still on screen is a known cause of native crashes on Android.
  Future<bool> showInterstitialAd() async {
    // Never stack two full-screen ads.
    if (_interstitialShowing) return false;

    if (_interstitialAd == null) {
      // Try loading one on demand, then poll briefly for it to arrive.
      await loadInterstitialAd();
      for (var i = 0; i < 10 && _interstitialAd == null; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    final ad = _interstitialAd;
    if (ad == null) return false;

    _interstitialShowing = true;
    final dismissed = Completer<void>();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _interstitialShowing = false;
        if (!dismissed.isCompleted) dismissed.complete();
        // Pre-load next ad
        loadInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        _interstitialShowing = false;
        if (!dismissed.isCompleted) dismissed.complete();
      },
    );

    // Consume the reference first — an InterstitialAd can only be shown once.
    _interstitialAd = null;
    ad.show();

    // Wait until the ad is closed (bounded, so a stuck callback can never
    // hang the caller forever).
    await dismissed.future
        .timeout(const Duration(seconds: 60), onTimeout: () {});
    return true;
  }

  // ════════════════════════════════════════════
  //  REWARDED AD
  // ════════════════════════════════════════════

  /// Load a rewarded ad
  Future<void> loadRewardedAd() async {
    if (!await ensureInitialized()) return;
    await RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
        },
      ),
    );
  }

  /// Show a rewarded ad. [onRewardEarned] is called when user earns reward.
  /// Returns true if ad was shown.
  Future<bool> showRewardedAd({
    required VoidCallback onRewardEarned,
  }) async {
    // Never stack two full-screen ads.
    if (_rewardedShowing) return false;

    if (_rewardedAd == null) {
      await loadRewardedAd();
      for (var i = 0; i < 10 && _rewardedAd == null; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    final ad = _rewardedAd;
    if (ad == null) return false;

    _rewardedShowing = true;
    final dismissed = Completer<void>();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        _rewardedShowing = false;
        if (!dismissed.isCompleted) dismissed.complete();
        loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        _rewardedShowing = false;
        if (!dismissed.isCompleted) dismissed.complete();
      },
    );

    // Consume the reference first — a RewardedAd can only be shown once.
    _rewardedAd = null;
    ad.show(onUserEarnedReward: (ad, reward) {
      onRewardEarned();
    });

    await dismissed.future
        .timeout(const Duration(seconds: 90), onTimeout: () {});
    return true;
  }

  // ════════════════════════════════════════════
  //  CLEANUP
  // ════════════════════════════════════════════

  void dispose() {
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    _interstitialAd = null;
    _rewardedAd = null;
  }
}
