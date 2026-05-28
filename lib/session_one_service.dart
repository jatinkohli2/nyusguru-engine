import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'user_interaction_logger.dart';

/// Plan A — Session 1: first-read guidance and funnel milestones.
class SessionOneService {
  SessionOneService._();

  static final SessionOneService instance = SessionOneService._();

  static const String prefsCoachDismissed = 'nyusguru_session1_coach_dismissed';
  static const String prefsBriefCelebrated =
      'nyusguru_session1_brief_celebrated';
  static const String prefsFirstOpenLogged =
      'nyusguru_session1_first_open_logged';
  static const String prefsDwell30Logged = 'nyusguru_session1_dwell_30_logged';

  bool _coachDismissed = false;
  bool _briefCelebrated = false;
  bool _firstOpenLogged = false;
  bool _dwell30Logged = false;
  bool _celebrationPending = false;
  bool _loaded = false;

  bool get coachDismissed => _coachDismissed;
  bool get briefCelebrated => _briefCelebrated;
  bool get celebrationPending => _celebrationPending;

  /// Session 1 payoff complete (opened an article or finished Day 1 UI).
  bool get hasCompletedFirstRead => _firstOpenLogged || _briefCelebrated;

  /// Coach hint on the first feed card (until dismissed or first open).
  bool get shouldShowCoachMark =>
      _loaded && !_coachDismissed && !_firstOpenLogged;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _coachDismissed = prefs.getBool(prefsCoachDismissed) ?? false;
      _briefCelebrated = prefs.getBool(prefsBriefCelebrated) ?? false;
      _firstOpenLogged = prefs.getBool(prefsFirstOpenLogged) ?? false;
      _dwell30Logged = prefs.getBool(prefsDwell30Logged) ?? false;
    } catch (e, st) {
      debugPrint('SessionOneService.load failed: $e\n$st');
    }
    _loaded = true;
  }

  Future<void> dismissCoachMark() async {
    if (_coachDismissed) return;
    _coachDismissed = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefsCoachDismissed, true);
    } catch (e, st) {
      debugPrint('SessionOneService.dismissCoachMark failed: $e\n$st');
    }
  }

  /// Called when the user opens any article from the feed.
  Future<void> onFirstArticleOpen() async {
    await dismissCoachMark();

    if (_firstOpenLogged) {
      _maybeQueueCelebration();
      return;
    }

    _firstOpenLogged = true;
    UserInteractionLogger.instance.recordFunnelMilestone('first_article_open');

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefsFirstOpenLogged, true);
    } catch (e, st) {
      debugPrint('SessionOneService.onFirstArticleOpen failed: $e\n$st');
    }

    _maybeQueueCelebration();
  }

  /// Called after ≥30s dwell on an article in preview.
  Future<void> onFirstArticleDwell30s() async {
    if (_dwell30Logged) return;

    _dwell30Logged = true;
    UserInteractionLogger.instance.recordFunnelMilestone(
      'first_article_dwell_30s',
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefsDwell30Logged, true);
    } catch (e, st) {
      debugPrint('SessionOneService.onFirstArticleDwell30s failed: $e\n$st');
    }

    _maybeQueueCelebration();
  }

  void _maybeQueueCelebration() {
    if (_briefCelebrated) return;
    if (!_firstOpenLogged && !_dwell30Logged) return;
    _celebrationPending = true;
  }

  /// Shows the Day 1 success UI once; returns message if shown.
  Future<String?> consumeCelebration({required bool isHindi}) async {
    if (!_celebrationPending || _briefCelebrated) return null;

    _celebrationPending = false;
    _briefCelebrated = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefsBriefCelebrated, true);
    } catch (e, st) {
      debugPrint('SessionOneService.consumeCelebration failed: $e\n$st');
    }

    return isHindi
        ? 'दिन 1 की ब्रिफ़ शुरू — बढ़िया!'
        : 'Day 1 brief started — nice work!';
  }

  /// Test-only reset.
  @visibleForTesting
  Future<void> resetForTest() async {
    _coachDismissed = false;
    _briefCelebrated = false;
    _firstOpenLogged = false;
    _dwell30Logged = false;
    _celebrationPending = false;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsCoachDismissed);
    await prefs.remove(prefsBriefCelebrated);
    await prefs.remove(prefsFirstOpenLogged);
    await prefs.remove(prefsDwell30Logged);
  }
}
