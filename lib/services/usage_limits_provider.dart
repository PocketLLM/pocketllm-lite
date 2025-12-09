import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers.dart';

class UsageLimitsState {
  final int tokenBalance;
  final int totalTokensUsed;
  final int enhancerUsesToday;
  final DateTime? lastEnhancerReset;

  UsageLimitsState({
    this.tokenBalance = AppConstants.initialTokenBalance,
    this.totalTokensUsed = 0,
    this.enhancerUsesToday = 0,
    this.lastEnhancerReset,
  });

  UsageLimitsState copyWith({
    int? tokenBalance,
    int? totalTokensUsed,
    int? enhancerUsesToday,
    DateTime? lastEnhancerReset,
  }) {
    return UsageLimitsState(
      tokenBalance: tokenBalance ?? this.tokenBalance,
      totalTokensUsed: totalTokensUsed ?? this.totalTokensUsed,
      enhancerUsesToday: enhancerUsesToday ?? this.enhancerUsesToday,
      lastEnhancerReset: lastEnhancerReset ?? this.lastEnhancerReset,
    );
  }

  int get remainingTokens => tokenBalance - totalTokensUsed;
  int get enhancerRemaining =>
      AppConstants.freeEnhancementsPerDay - enhancerUsesToday;
  bool get hasTokens => remainingTokens > 0;
  bool get hasEnhancerUses =>
      enhancerUsesToday < AppConstants.freeEnhancementsPerDay;

  /// Time until enhancer resets (in hours)
  int get hoursUntilEnhancerReset {
    if (lastEnhancerReset == null) return 0;
    final resetTime = lastEnhancerReset!.add(const Duration(hours: 24));
    final now = DateTime.now();
    if (resetTime.isBefore(now)) return 0;
    return resetTime.difference(now).inHours + 1;
  }
}

class UsageLimitsNotifier extends Notifier<UsageLimitsState> {
  @override
  UsageLimitsState build() {
    _loadFromStorage();
    return UsageLimitsState();
  }

  void _loadFromStorage() {
    final storage = ref.read(storageServiceProvider);

    final tokenBalance = storage.getSetting(
      AppConstants.tokenBalanceKey,
      defaultValue: AppConstants.initialTokenBalance,
    );
    final totalTokensUsed = storage.getSetting(
      AppConstants.totalTokensUsedKey,
      defaultValue: 0,
    );
    final enhancerUsesToday = storage.getSetting(
      AppConstants.enhancerUsesTodayKey,
      defaultValue: 0,
    );
    final lastResetString = storage.getSetting(
      AppConstants.lastEnhancerResetKey,
      defaultValue: null,
    );

    DateTime? lastEnhancerReset;
    if (lastResetString != null) {
      lastEnhancerReset = DateTime.tryParse(lastResetString);
    }

    // Check if 24 hours have passed and reset enhancer uses
    if (lastEnhancerReset != null) {
      final now = DateTime.now();
      if (now.difference(lastEnhancerReset).inHours >= 24) {
        // Reset enhancer uses
        _saveEnhancerReset(0, now);
        state = UsageLimitsState(
          tokenBalance: tokenBalance,
          totalTokensUsed: totalTokensUsed,
          enhancerUsesToday: 0,
          lastEnhancerReset: now,
        );
        return;
      }
    }

    state = UsageLimitsState(
      tokenBalance: tokenBalance,
      totalTokensUsed: totalTokensUsed,
      enhancerUsesToday: enhancerUsesToday,
      lastEnhancerReset: lastEnhancerReset,
    );
  }

  Future<void> _saveEnhancerReset(int uses, DateTime resetTime) async {
    final storage = ref.read(storageServiceProvider);
    await storage.saveSetting(AppConstants.enhancerUsesTodayKey, uses);
    await storage.saveSetting(
      AppConstants.lastEnhancerResetKey,
      resetTime.toIso8601String(),
    );
  }

  /// Check if user can use enhancer (returns true if allowed)
  bool canUseEnhancer() {
    // Check if 24 hours have passed since last reset
    if (state.lastEnhancerReset != null) {
      final now = DateTime.now();
      if (now.difference(state.lastEnhancerReset!).inHours >= 24) {
        // Reset
        _saveEnhancerReset(0, now);
        state = state.copyWith(enhancerUsesToday: 0, lastEnhancerReset: now);
        return true;
      }
    }
    return state.hasEnhancerUses;
  }

  /// Consume one enhancer use
  Future<void> useEnhancer() async {
    final newUses = state.enhancerUsesToday + 1;
    final resetTime = state.lastEnhancerReset ?? DateTime.now();

    state = state.copyWith(
      enhancerUsesToday: newUses,
      lastEnhancerReset: resetTime,
    );

    final storage = ref.read(storageServiceProvider);
    await storage.saveSetting(AppConstants.enhancerUsesTodayKey, newUses);
    if (state.lastEnhancerReset == null) {
      await storage.saveSetting(
        AppConstants.lastEnhancerResetKey,
        resetTime.toIso8601String(),
      );
    }
  }

  /// Add enhancer uses (after watching ad)
  Future<void> addEnhancerUses(int count) async {
    // Reset uses and set new 24h window
    final now = DateTime.now();
    state = state.copyWith(enhancerUsesToday: 0, lastEnhancerReset: now);

    final storage = ref.read(storageServiceProvider);
    await storage.saveSetting(AppConstants.enhancerUsesTodayKey, 0);
    await storage.saveSetting(
      AppConstants.lastEnhancerResetKey,
      now.toIso8601String(),
    );
  }

  /// Check if user has enough tokens
  bool hasEnoughTokens(int estimatedTokens) {
    return state.remainingTokens >= estimatedTokens;
  }

  /// Consume tokens after a chat/enhance operation
  Future<void> consumeTokens(int tokens) async {
    final newTotal = state.totalTokensUsed + tokens;
    state = state.copyWith(totalTokensUsed: newTotal);

    final storage = ref.read(storageServiceProvider);
    await storage.saveSetting(AppConstants.totalTokensUsedKey, newTotal);
  }

  /// Add tokens (after watching ad)
  Future<void> addTokens(int tokens) async {
    final newBalance = state.tokenBalance + tokens;
    state = state.copyWith(tokenBalance: newBalance);

    final storage = ref.read(storageServiceProvider);
    await storage.saveSetting(AppConstants.tokenBalanceKey, newBalance);
  }

  /// Estimate tokens from text (rough approximation: words * 1.3)
  static int estimateTokens(String text) {
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    return (words * 1.3).ceil();
  }

  /// Parse tokens from Ollama response
  static int parseTokensFromResponse(Map<String, dynamic> response) {
    final promptEvalCount = response['prompt_eval_count'] as int? ?? 0;
    final evalCount = response['eval_count'] as int? ?? 0;
    return promptEvalCount + evalCount;
  }

  /// Reload state from storage
  void reload() {
    _loadFromStorage();
  }
}

final usageLimitsProvider =
    NotifierProvider<UsageLimitsNotifier, UsageLimitsState>(
      UsageLimitsNotifier.new,
    );
