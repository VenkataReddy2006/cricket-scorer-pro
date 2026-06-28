import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? bannerAd;
  bool isLoaded = false;

  @override
  void initState() {
    super.initState();

    bannerAd = BannerAd(
      size: AdSize.banner,
      adUnitId: 'ca-app-pub-1868484230733894/2586419869',
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          print('BannerAd failed to load: $error');
          ad.dispose();
        },
      ),
      request: const AdRequest(),
    );

    bannerAd!.load();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoaded) {
      return SizedBox(
        height: bannerAd!.size.height.toDouble(),
        width: bannerAd!.size.width.toDouble(),
        child: AdWidget(ad: bannerAd!),
      );
    }

    return const SizedBox();
  }
}
