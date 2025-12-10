import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../core/constants/app_constants.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  BannerAd? _bannerAd;
  RewardedAd? _rewardedAd;
  bool _isBannerLoaded = false;
  bool _isRewardedLoaded = false;
  
  // Add preload management
  bool _isPreloadingRewardedAd = false;
  int _rewardedAdRetryCount = 0;
  static const int maxRetryAttempts = 3;

  bool get isBannerLoaded => _isBannerLoaded;
  bool get isRewardedLoaded => _isRewardedLoaded;
  BannerAd? get bannerAd => _bannerAd;

  /// Initialize MobileAds SDK
  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
    if (kDebugMode) {
      // Removed debug print to avoid exposing information in production
    }
  }

  /// Check if device has internet connectivity
  Future<bool> hasInternetConnection() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult.isNotEmpty &&
        !connectivityResult.contains(ConnectivityResult.none);
  }

  /// Get the appropriate banner ad unit ID based on platform
  String get _bannerAdUnitId {
    if (Platform.isAndroid) {
      return AppConstants.bannerAdUnitId;
    } else if (Platform.isIOS) {
      return AppConstants.bannerAdUnitId;
    }
    return '';
  }

  /// Get the appropriate rewarded ad unit ID based on platform
  String get _rewardedAdUnitId {
    if (Platform.isAndroid) {
      return AppConstants.rewardedAdUnitId;
    } else if (Platform.isIOS) {
      return AppConstants.rewardedAdUnitId;
    }
    return '';
  }

  /// Load a banner ad
  Future<void> loadBannerAd({
    Function()? onLoaded,
    Function(String)? onFailed,
  }) async {
    if (!await hasInternetConnection()) {
      onFailed?.call('No internet connection');
      return;
    }

    _bannerAd = BannerAd(
      adUnitId: _bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _isBannerLoaded = true;
          onLoaded?.call();
          if (kDebugMode) {
            // Removed debug print to avoid exposing information in production
          }
        },
        onAdFailedToLoad: (ad, error) {
          _isBannerLoaded = false;
          ad.dispose();
          onFailed?.call(error.message);
          if (kDebugMode) {
            // Removed debug print to avoid exposing information in production
          }
        },
      ),
    );

    await _bannerAd?.load();
  }

  /// Proactive rewarded ad preloading with retry mechanism
  Future<void> preloadRewardedAd() async {
    // Prevent multiple simultaneous preload attempts
    if (_isPreloadingRewardedAd) return;
    
    // If we already have a loaded ad, don't preload another one
    if (_rewardedAd != null && _isRewardedLoaded) return;
    
    _isPreloadingRewardedAd = true;
    
    try {
      if (!await hasInternetConnection()) {
        _isPreloadingRewardedAd = false;
        return;
      }

      await RewardedAd.load(
        adUnitId: _rewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            // Dispose of any existing ad before setting the new one
            _rewardedAd?.dispose();
            
            _rewardedAd = ad;
            _isRewardedLoaded = true;
            _isPreloadingRewardedAd = false;
            _rewardedAdRetryCount = 0; // Reset retry count on success
            
            if (kDebugMode) {
              // Removed debug print to avoid exposing information in production
            }
          },
          onAdFailedToLoad: (error) {
            _isRewardedLoaded = false;
            _isPreloadingRewardedAd = false;
            
            // Implement retry mechanism
            if (_rewardedAdRetryCount < maxRetryAttempts) {
              _rewardedAdRetryCount++;
              // Retry after a short delay
              Future.delayed(const Duration(seconds: 2), preloadRewardedAd);
            }
            
            if (kDebugMode) {
              // Removed debug print to avoid exposing information in production
            }
          },
        ),
      );
    } catch (e) {
      _isPreloadingRewardedAd = false;
      if (_rewardedAdRetryCount < maxRetryAttempts) {
        _rewardedAdRetryCount++;
        Future.delayed(const Duration(seconds: 2), preloadRewardedAd);
      }
    }
  }

  /// Load a rewarded ad (fallback method)
  Future<void> loadRewardedAd({
    Function()? onLoaded,
    Function(String)? onFailed,
  }) async {
    if (!await hasInternetConnection()) {
      onFailed?.call('No internet connection');
      return;
    }

    await RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedLoaded = true;
          onLoaded?.call();
          if (kDebugMode) {
            // Removed debug print to avoid exposing information in production
          }
        },
        onAdFailedToLoad: (error) {
          _isRewardedLoaded = false;
          onFailed?.call(error.message);
          if (kDebugMode) {
            // Removed debug print to avoid exposing information in production
          }
        },
      ),
    );
  }

  /// Show the rewarded ad
  Future<bool> showRewardedAd({
    required Function(RewardItem) onUserEarnedReward,
    Function()? onAdDismissed,
    Function(String)? onFailed,
  }) async {
    if (!await hasInternetConnection()) {
      onFailed?.call('Connect to WiFi/Data to watch ad and unlock.');
      return false;
    }

    // If no ad is loaded, try to preload one immediately
    if (_rewardedAd == null || !_isRewardedLoaded) {
      // Try to load first
      await loadRewardedAd();
      if (_rewardedAd == null) {
        onFailed?.call('Ad not ready. Please try again.');
        // Start preloading for next time
        preloadRewardedAd();
        return false;
      }
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        _isRewardedLoaded = false;
        onAdDismissed?.call();
        // Preload the next ad
        preloadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        _isRewardedLoaded = false;
        onFailed?.call(error.message);
        // Preload the next ad
        preloadRewardedAd();
      },
    );

    await _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        onUserEarnedReward(reward);
      },
    );

    return true;
  }

  /// Dispose banner ad
  void disposeBannerAd() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _isBannerLoaded = false;
  }

  /// Dispose all ads
  void dispose() {
    disposeBannerAd();
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _isRewardedLoaded = false;
    _isPreloadingRewardedAd = false;
    _rewardedAdRetryCount = 0;
  }
}