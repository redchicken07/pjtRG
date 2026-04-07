// lib/core/ads/ad_helper.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'; // ◀️ 필수 추가
import 'package:flutter_riverpod/flutter_riverpod.dart'; // ◀️ 필수 추가
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdHelper {
  // ❗ 중요: 아래 ID들은 구글 테스트 ID입니다. 추후 AdMob에서 발급받은 실제 광고 단위 ID로 교체해야 합니다.
  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-1774538472895080/8582690222';
    } else if (Platform.isIOS) {
      // iOS는 테스트 ID를 기본값으로 둡니다.
      return 'ca-app-pub-3940256099942544/2934735716';
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  static String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return "ca-app-pub-1774538472895080/2094702299";
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/4411468910';
    } else {
      throw UnsupportedError("Unsupported platform");
    }
  }

  static String get rewardedAdUnitId {
    if (Platform.isAndroid) {
      return "ca-app-pub-1774538472895080/6770915101";
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/1712485313';
    } else {
      throw UnsupportedError("Unsupported platform");
    }
  }

  static int _gamePlayCount = 0;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;

  AdHelper() {
    if (_supportsMobileAds) {
      _loadInterstitialAd();
      _loadRewardedAd();
    }
  }

  bool get _supportsMobileAds =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  void dispose() {
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialAd?.fullScreenContentCallback =
              FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _loadInterstitialAd(); // 다음 광고 미리 로드
            },
            onAdFailedToShowFullScreenContent: (ad, err) {
              ad.dispose();
              _loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (err) {
          _interstitialAd = null;
          debugPrint('InterstitialAd failed to load: $err');
        },
      ),
    );
  }

  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _rewardedAd?.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _loadRewardedAd(); // 다음 광고 미리 로드
            },
            onAdFailedToShowFullScreenContent: (ad, err) {
              ad.dispose();
              _loadRewardedAd();
            },
          );
        },
        onAdFailedToLoad: (err) {
          _rewardedAd = null;
          debugPrint('RewardedAd failed to load: $err');
        },
      ),
    );
  }

  void handleGameEnd() {
    if (!_supportsMobileAds) return;

    _gamePlayCount++;
    debugPrint("Game play count: $_gamePlayCount");

    if (_gamePlayCount % 10 == 0) {
      // 보상형 광고
      _rewardedAd?.show(onUserEarnedReward: (ad, reward) {
        debugPrint("Reward earned: ${reward.amount} ${reward.type}");
      });
    } else if (_gamePlayCount % 5 == 0) {
      // 전면 광고
      _interstitialAd?.show();
    }
  }
}

final adHelperProvider = Provider<AdHelper>((ref) {
  final adHelper = AdHelper();
  ref.onDispose(() => adHelper.dispose());
  return adHelper;
});

// 배너 광고 위젯
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadAd();
  }

  void _loadAd() {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
    if (_bannerAd != null) return;

    final adUnitId = AdHelper.bannerAdUnitId;
    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint('BannerAd failed to load: $err');
          ad.dispose();
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
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      return const SizedBox.shrink();
    }

    if (_isLoaded && _bannerAd != null) {
      return SizedBox(
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      );
    }
    return const SizedBox(height: 50); // 광고 로딩 중일 때 높이만 차지
  }
}
