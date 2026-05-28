import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'user_interaction_logger.dart';

/// Plan A step 2 — first-launch onboarding completion flag.
class OnboardingService {
  OnboardingService._();

  static final OnboardingService instance = OnboardingService._();

  static const String prefsComplete = 'nyusguru_onboarding_complete';

  bool _complete = false;
  bool _loaded = false;

  bool get isComplete => _complete;
  bool get shouldShowOnboarding => _loaded && !_complete;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _complete = prefs.getBool(prefsComplete) ?? false;
    } catch (e, st) {
      debugPrint('OnboardingService.load failed: $e\n$st');
    }
    _loaded = true;
  }

  Future<void> markComplete() async {
    if (_complete) return;
    _complete = true;
    UserInteractionLogger.instance.recordFunnelMilestone('onboarding_complete');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefsComplete, true);
    } catch (e, st) {
      debugPrint('OnboardingService.markComplete failed: $e\n$st');
    }
  }

  @visibleForTesting
  Future<void> resetForTest() async {
    _complete = false;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsComplete);
  }
}
