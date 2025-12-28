import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static const String testBannerId = 'ca-app-pub-3940256099942544/6300978111';
  static const String testInterstitialId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String testRewardedId = 'ca-app-pub-3940256099942544/5224354917';
  static const String testNativeId = 'ca-app-pub-3940256099942544/2247696110';

  static DateTime? _lastInterstitialTime;

  static Future<void> showInterstitial(VoidCallback onComplete) async {
    // 2-minute frequency cap
    if (_lastInterstitialTime != null &&
        DateTime.now().difference(_lastInterstitialTime!).inMinutes < 2) {
      onComplete();
      return;
    }

    await InterstitialAd.load(
      adUnitId: testInterstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              _lastInterstitialTime = DateTime.now();
              onComplete();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              onComplete();
            },
          );
          ad.show();
        },
        onAdFailedToLoad: (error) {
          onComplete();
        },
      ),
    );
  }

  static Future<void> showRewarded(Function(bool) onResult) async {
    await RewardedAd.load(
      adUnitId: testRewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              // Note: Result handled via onUserEarnedReward
            },
          );
          ad.show(
            onUserEarnedReward: (ad, reward) {
              onResult(true);
            },
          );
        },
        onAdFailedToLoad: (error) {
          onResult(false);
        },
      ),
    );
  }

  static Widget getBannerWidget() {
    return const BannerAdWidget();
  }
}

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    _bannerAd = BannerAd(
      adUnitId: AdService.testBannerId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('BannerAd failed to load: $error');
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _bannerAd == null) {
      return const SizedBox(height: 50);
    }
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
