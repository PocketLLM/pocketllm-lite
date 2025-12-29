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
  RewardedAd? _deletionRewardedAd;
  RewardedAd? _promptEnhancementRewardedAd;
  RewardedAd? _chatCreationRewardedAd;
  bool _isBannerLoaded = false;
  bool _isRewardedLoaded = false;
  bool _isDeletionRewardedLoaded = false;
  bool _isPromptEnhancementRewardedLoaded = false;
  bool _isChatCreationRewardedLoaded = false;
  
  // Add preload management
  bool _isPreloadingRewardedAd = false;
  bool _isPreloadingDeletionRewardedAd = false;
  bool _isPreloadingPromptEnhancementRewardedAd = false;
  bool _isPreloadingChatCreationRewardedAd = false;
  int _rewardedAdRetryCount = 0;
  int _deletionRewardedAdRetryCount = 0;
  int _promptEnhancementRewardedAdRetryCount = 0;
  int _chatCreationRewardedAdRetryCount = 0;
  static const int maxRetryAttempts = 3;

  bool get isBannerLoaded => _isBannerLoaded;
  bool get isRewardedLoaded => _isRewardedLoaded;
  bool get isDeletionRewardedLoaded => _isDeletionRewardedLoaded;
  bool get isPromptEnhancementRewardedLoaded => _isPromptEnhancementRewardedLoaded;
  bool get isChatCreationRewardedLoaded => _isChatCreationRewardedLoaded;
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

  /// Get the appropriate deletion rewarded ad unit ID based on platform
  String get _deletionRewardedAdUnitId {
    if (Platform.isAndroid) {
      return AppConstants.deletionRewardedAdUnitId;
    } else if (Platform.isIOS) {
      return AppConstants.deletionRewardedAdUnitId;
    }
    return '';
  }

  /// Get the appropriate prompt enhancement rewarded ad unit ID based on platform
  String get _promptEnhancementRewardedAdUnitId {
    if (Platform.isAndroid) {
      return AppConstants.promptEnhancementRewardedAdUnitId;
    } else if (Platform.isIOS) {
      return AppConstants.promptEnhancementRewardedAdUnitId;
    }
    return '';
  }

  /// Get the appropriate chat creation rewarded ad unit ID based on platform
  String get _chatCreationRewardedAdUnitId {
    if (Platform.isAndroid) {
      return AppConstants.chatCreationRewardedAdUnitId;
    } else if (Platform.isIOS) {
      return AppConstants.chatCreationRewardedAdUnitId;
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

  /// Proactive deletion rewarded ad preloading with retry mechanism
  Future<void> preloadDeletionRewardedAd() async {
    // Prevent multiple simultaneous preload attempts
    if (_isPreloadingDeletionRewardedAd) return;
    
    // If we already have a loaded ad, don't preload another one
    if (_deletionRewardedAd != null && _isDeletionRewardedLoaded) return;
    
    _isPreloadingDeletionRewardedAd = true;
    
    try {
      if (!await hasInternetConnection()) {
        _isPreloadingDeletionRewardedAd = false;
        return;
      }

      await RewardedAd.load(
        adUnitId: _deletionRewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            // Dispose of any existing ad before setting the new one
            _deletionRewardedAd?.dispose();
            
            _deletionRewardedAd = ad;
            _isDeletionRewardedLoaded = true;
            _isPreloadingDeletionRewardedAd = false;
            _deletionRewardedAdRetryCount = 0; // Reset retry count on success
            
            if (kDebugMode) {
              // Removed debug print to avoid exposing information in production
            }
          },
          onAdFailedToLoad: (error) {
            _isDeletionRewardedLoaded = false;
            _isPreloadingDeletionRewardedAd = false;
            
            // Implement retry mechanism
            if (_deletionRewardedAdRetryCount < maxRetryAttempts) {
              _deletionRewardedAdRetryCount++;
              // Retry after a short delay
              Future.delayed(const Duration(seconds: 2), preloadDeletionRewardedAd);
            }
            
            if (kDebugMode) {
              // Removed debug print to avoid exposing information in production
            }
          },
        ),
      );
    } catch (e) {
      _isPreloadingDeletionRewardedAd = false;
      if (_deletionRewardedAdRetryCount < maxRetryAttempts) {
        _deletionRewardedAdRetryCount++;
        Future.delayed(const Duration(seconds: 2), preloadDeletionRewardedAd);
      }
    }
  }

  /// Proactive prompt enhancement rewarded ad preloading with retry mechanism
  Future<void> preloadPromptEnhancementRewardedAd() async {
    // Prevent multiple simultaneous preload attempts
    if (_isPreloadingPromptEnhancementRewardedAd) return;
    
    // If we already have a loaded ad, don't preload another one
    if (_promptEnhancementRewardedAd != null && _isPromptEnhancementRewardedLoaded) return;
    
    _isPreloadingPromptEnhancementRewardedAd = true;
    
    try {
      if (!await hasInternetConnection()) {
        _isPreloadingPromptEnhancementRewardedAd = false;
        return;
      }

      await RewardedAd.load(
        adUnitId: _promptEnhancementRewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            // Dispose of any existing ad before setting the new one
            _promptEnhancementRewardedAd?.dispose();
            
            _promptEnhancementRewardedAd = ad;
            _isPromptEnhancementRewardedLoaded = true;
            _isPreloadingPromptEnhancementRewardedAd = false;
            _promptEnhancementRewardedAdRetryCount = 0; // Reset retry count on success
            
            if (kDebugMode) {
              // Removed debug print to avoid exposing information in production
            }
          },
          onAdFailedToLoad: (error) {
            _isPromptEnhancementRewardedLoaded = false;
            _isPreloadingPromptEnhancementRewardedAd = false;
            
            // Implement retry mechanism
            if (_promptEnhancementRewardedAdRetryCount < maxRetryAttempts) {
              _promptEnhancementRewardedAdRetryCount++;
              // Retry after a short delay
              Future.delayed(const Duration(seconds: 2), preloadPromptEnhancementRewardedAd);
            }
            
            if (kDebugMode) {
              // Removed debug print to avoid exposing information in production
            }
          },
        ),
      );
    } catch (e) {
      _isPreloadingPromptEnhancementRewardedAd = false;
      if (_promptEnhancementRewardedAdRetryCount < maxRetryAttempts) {
        _promptEnhancementRewardedAdRetryCount++;
        Future.delayed(const Duration(seconds: 2), preloadPromptEnhancementRewardedAd);
      }
    }
  }

  /// Proactive chat creation rewarded ad preloading with retry mechanism
  Future<void> preloadChatCreationRewardedAd() async {
    // Prevent multiple simultaneous preload attempts
    if (_isPreloadingChatCreationRewardedAd) return;
    
    // If we already have a loaded ad, don't preload another one
    if (_chatCreationRewardedAd != null && _isChatCreationRewardedLoaded) return;
    
    _isPreloadingChatCreationRewardedAd = true;
    
    try {
      if (!await hasInternetConnection()) {
        _isPreloadingChatCreationRewardedAd = false;
        return;
      }

      await RewardedAd.load(
        adUnitId: _chatCreationRewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            // Dispose of any existing ad before setting the new one
            _chatCreationRewardedAd?.dispose();
            
            _chatCreationRewardedAd = ad;
            _isChatCreationRewardedLoaded = true;
            _isPreloadingChatCreationRewardedAd = false;
            _chatCreationRewardedAdRetryCount = 0; // Reset retry count on success
            
            if (kDebugMode) {
              // Removed debug print to avoid exposing information in production
            }
          },
          onAdFailedToLoad: (error) {
            _isChatCreationRewardedLoaded = false;
            _isPreloadingChatCreationRewardedAd = false;
            
            // Implement retry mechanism
            if (_chatCreationRewardedAdRetryCount < maxRetryAttempts) {
              _chatCreationRewardedAdRetryCount++;
              // Retry after a short delay
              Future.delayed(const Duration(seconds: 2), preloadChatCreationRewardedAd);
            }
            
            if (kDebugMode) {
              // Removed debug print to avoid exposing information in production
            }
          },
        ),
      );
    } catch (e) {
      _isPreloadingChatCreationRewardedAd = false;
      if (_chatCreationRewardedAdRetryCount < maxRetryAttempts) {
        _chatCreationRewardedAdRetryCount++;
        Future.delayed(const Duration(seconds: 2), preloadChatCreationRewardedAd);
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

  /// Load a deletion rewarded ad
  Future<void> loadDeletionRewardedAd({
    Function()? onLoaded,
    Function(String)? onFailed,
  }) async {
    if (!await hasInternetConnection()) {
      onFailed?.call('No internet connection');
      return;
    }

    await RewardedAd.load(
      adUnitId: _deletionRewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _deletionRewardedAd = ad;
          _isDeletionRewardedLoaded = true;
          onLoaded?.call();
          if (kDebugMode) {
            // Removed debug print to avoid exposing information in production
          }
        },
        onAdFailedToLoad: (error) {
          _isDeletionRewardedLoaded = false;
          onFailed?.call(error.message);
          if (kDebugMode) {
            // Removed debug print to avoid exposing information in production
          }
        },
      ),
    );
  }

  /// Load a prompt enhancement rewarded ad
  Future<void> loadPromptEnhancementRewardedAd({
    Function()? onLoaded,
    Function(String)? onFailed,
  }) async {
    if (!await hasInternetConnection()) {
      onFailed?.call('No internet connection');
      return;
    }

    await RewardedAd.load(
      adUnitId: _promptEnhancementRewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _promptEnhancementRewardedAd = ad;
          _isPromptEnhancementRewardedLoaded = true;
          onLoaded?.call();
          if (kDebugMode) {
            // Removed debug print to avoid exposing information in production
          }
        },
        onAdFailedToLoad: (error) {
          _isPromptEnhancementRewardedLoaded = false;
          onFailed?.call(error.message);
          if (kDebugMode) {
            // Removed debug print to avoid exposing information in production
          }
        },
      ),
    );
  }

  /// Load a chat creation rewarded ad
  Future<void> loadChatCreationRewardedAd({
    Function()? onLoaded,
    Function(String)? onFailed,
  }) async {
    if (!await hasInternetConnection()) {
      onFailed?.call('No internet connection');
      return;
    }

    await RewardedAd.load(
      adUnitId: _chatCreationRewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _chatCreationRewardedAd = ad;
          _isChatCreationRewardedLoaded = true;
          onLoaded?.call();
          if (kDebugMode) {
            // Removed debug print to avoid exposing information in production
          }
        },
        onAdFailedToLoad: (error) {
          _isChatCreationRewardedLoaded = false;
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

  /// Show the deletion rewarded ad
  Future<bool> showDeletionRewardedAd({
    required Function(RewardItem) onUserEarnedReward,
    Function()? onAdDismissed,
    Function(String)? onFailed,
  }) async {
    if (!await hasInternetConnection()) {
      onFailed?.call('Connect to WiFi/Data to watch ad and unlock deletion feature.');
      return false;
    }

    // If no ad is loaded, try to load one immediately
    if (_deletionRewardedAd == null || !_isDeletionRewardedLoaded) {
      // Try to load first
      await loadDeletionRewardedAd();
      if (_deletionRewardedAd == null) {
        onFailed?.call('Ad not ready. Please try again.');
        // Start preloading for next time
        preloadDeletionRewardedAd();
        return false;
      }
    }

    _deletionRewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _deletionRewardedAd = null;
        _isDeletionRewardedLoaded = false;
        onAdDismissed?.call();
        // Preload the next ad
        preloadDeletionRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _deletionRewardedAd = null;
        _isDeletionRewardedLoaded = false;
        onFailed?.call(error.message);
        // Preload the next ad
        preloadDeletionRewardedAd();
      },
    );

    await _deletionRewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        onUserEarnedReward(reward);
      },
    );

    return true;
  }

  /// Show the prompt enhancement rewarded ad
  Future<bool> showPromptEnhancementRewardedAd({
    required Function(RewardItem) onUserEarnedReward,
    Function()? onAdDismissed,
    Function(String)? onFailed,
  }) async {
    if (!await hasInternetConnection()) {
      onFailed?.call('Connect to WiFi/Data to watch ad and unlock prompt enhancement feature.');
      return false;
    }

    // If no ad is loaded, try to load one immediately
    if (_promptEnhancementRewardedAd == null || !_isPromptEnhancementRewardedLoaded) {
      // Try to load first
      await loadPromptEnhancementRewardedAd();
      if (_promptEnhancementRewardedAd == null) {
        onFailed?.call('Ad not ready. Please try again.');
        // Start preloading for next time
        preloadPromptEnhancementRewardedAd();
        return false;
      }
    }

    _promptEnhancementRewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _promptEnhancementRewardedAd = null;
        _isPromptEnhancementRewardedLoaded = false;
        onAdDismissed?.call();
        // Preload the next ad
        preloadPromptEnhancementRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _promptEnhancementRewardedAd = null;
        _isPromptEnhancementRewardedLoaded = false;
        onFailed?.call(error.message);
        // Preload the next ad
        preloadPromptEnhancementRewardedAd();
      },
    );

    await _promptEnhancementRewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        onUserEarnedReward(reward);
      },
    );

    return true;
  }

  /// Show the chat creation rewarded ad
  Future<bool> showChatCreationRewardedAd({
    required Function(RewardItem) onUserEarnedReward,
    Function()? onAdDismissed,
    Function(String)? onFailed,
  }) async {
    if (!await hasInternetConnection()) {
      onFailed?.call('Connect to WiFi/Data to watch ad and unlock chat creation feature.');
      return false;
    }

    // If no ad is loaded, try to load one immediately
    if (_chatCreationRewardedAd == null || !_isChatCreationRewardedLoaded) {
      // Try to load first
      await loadChatCreationRewardedAd();
      if (_chatCreationRewardedAd == null) {
        onFailed?.call('Ad not ready. Please try again.');
        // Start preloading for next time
        preloadChatCreationRewardedAd();
        return false;
      }
    }

    _chatCreationRewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _chatCreationRewardedAd = null;
        _isChatCreationRewardedLoaded = false;
        onAdDismissed?.call();
        // Preload the next ad
        preloadChatCreationRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _chatCreationRewardedAd = null;
        _isChatCreationRewardedLoaded = false;
        onFailed?.call(error.message);
        // Preload the next ad
        preloadChatCreationRewardedAd();
      },
    );

    await _chatCreationRewardedAd!.show(
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
    _deletionRewardedAd?.dispose();
    _deletionRewardedAd = null;
    _promptEnhancementRewardedAd?.dispose();
    _promptEnhancementRewardedAd = null;
    _chatCreationRewardedAd?.dispose();
    _chatCreationRewardedAd = null;
    _isRewardedLoaded = false;
    _isDeletionRewardedLoaded = false;
    _isPromptEnhancementRewardedLoaded = false;
    _isChatCreationRewardedLoaded = false;
    _isPreloadingRewardedAd = false;
    _isPreloadingDeletionRewardedAd = false;
    _isPreloadingPromptEnhancementRewardedAd = false;
    _isPreloadingChatCreationRewardedAd = false;
    _rewardedAdRetryCount = 0;
    _deletionRewardedAdRetryCount = 0;
    _promptEnhancementRewardedAdRetryCount = 0;
    _chatCreationRewardedAdRetryCount = 0;
  }
}