import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static final AdService _instance = AdService._();
  factory AdService() => _instance;
  AdService._();

  bool _initialized = false;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;

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

  /// Show the loaded interstitial ad. Returns true if ad was shown.
  Future<bool> showInterstitialAd() async {
    if (_interstitialAd == null) {
      // Try loading one on demand
      await loadInterstitialAd();
      // Wait a bit for it to load, then try again
      await Future.delayed(const Duration(seconds: 1));
    }

    final ad = _interstitialAd;
    if (ad == null) return false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        // Pre-load next ad
        loadInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
      },
    );

    ad.show();
    return true;
  }

  // ════════════════════════════════════════════
  //  REWARDED AD
  // ════════════════════════════════════════════

  /// Load a rewarded ad
  Future<void> loadRewardedAd() async {
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
    if (_rewardedAd == null) {
      await loadRewardedAd();
      await Future.delayed(const Duration(seconds: 1));
    }

    final ad = _rewardedAd;
    if (ad == null) return false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
      },
    );

    ad.show(onUserEarnedReward: (ad, reward) {
      onRewardEarned();
    });

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
