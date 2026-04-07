import 'dart:ui' show VoidCallback;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Manages AdMob ads for free-tier users.
/// Premium users (active RevenueCat entitlement) see no ads.
class AdService {
  AdService._();
  static final instance = AdService._();

  bool _initialized = false;
  bool _isPremium = false;

  /// Test ad unit IDs (replace with real IDs before production).
  static const _testBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
  static const _testInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';

  String get bannerAdUnitId => _testBannerAdUnitId;
  String get interstitialAdUnitId => _testInterstitialAdUnitId;

  bool get isPremium => _isPremium;
  bool get shouldShowAds => !_isPremium;

  /// Initialize the Mobile Ads SDK and check premium status.
  Future<void> initialize() async {
    if (_initialized) return;
    await MobileAds.instance.initialize();
    _initialized = true;
    await refreshPremiumStatus();
  }

  /// Check RevenueCat for active premium entitlement.
  Future<void> refreshPremiumStatus() async {
    try {
      if (!await Purchases.isConfigured) {
        _isPremium = false;
        return;
      }
      final customerInfo = await Purchases.getCustomerInfo();
      _isPremium =
          customerInfo.entitlements.all['premium']?.isActive ?? false;
    } catch (_) {
      // If RevenueCat is not configured yet, default to free-tier.
      _isPremium = false;
    }
  }

  /// Load and return a banner ad widget for free-tier users.
  /// Returns null if user is premium.
  BannerAd? createBannerAd({VoidCallback? onLoaded}) {
    if (_isPremium) return null;

    return BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) => onLoaded?.call(),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    )..load();
  }

  /// Load an interstitial ad. Calls [onLoaded] when ready to show.
  void loadInterstitialAd({
    required void Function(InterstitialAd ad) onLoaded,
  }) {
    if (_isPremium) return;

    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: onLoaded,
        onAdFailedToLoad: (_) {},
      ),
    );
  }
}
