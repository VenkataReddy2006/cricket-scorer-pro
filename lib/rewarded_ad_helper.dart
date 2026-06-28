import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';

class RewardedAdHelper {
  static RewardedAd? rewardedAd;

  static void loadAd() {
    if (kIsWeb) return;
    RewardedAd.load(
      adUnitId: 'ca-app-pub-1868484230733894/6886194314',
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          rewardedAd = ad;
          print("Rewarded Ad Loaded");
        },
        onAdFailedToLoad: (error) {
          print("Rewarded Ad Failed: ${error.message}");
          rewardedAd = null;
        },
      ),
    );
  }

  static void showAd({Function? onComplete}) {
    if (kIsWeb) {
      if (onComplete != null) onComplete();
      return;
    }
    
    if (rewardedAd != null) {
      rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          rewardedAd = null;
          loadAd();
          if (onComplete != null) onComplete();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          rewardedAd = null;
          loadAd();
          if (onComplete != null) onComplete();
        },
      );
      
      rewardedAd!.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          print("User earned reward");
        },
      );
    } else {
      loadAd();
      if (onComplete != null) onComplete();
    }
  }
}
