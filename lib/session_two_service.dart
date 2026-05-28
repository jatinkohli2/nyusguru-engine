import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'article_model.dart';
import 'feed_personalization_service.dart';
import 'session_one_service.dart';
import 'user_interaction_logger.dart';

/// Plan A — Session 2: habit loop, “picked for you”, notification nudge.
class SessionTwoService {
  SessionTwoService._();

  static final SessionTwoService instance = SessionTwoService._();

  static const String prefsVisitCount = 'nyusguru_session2_visit_count';
  static const String prefsFeedViewLogged =
      'nyusguru_session2_feed_view_logged';
  static const String prefsNotificationNudgeHandled =
      'nyusguru_session2_notification_nudge_handled';
  static const String prefsHindiHintShown =
      'nyusguru_session2_hindi_hint_shown';

  int _visitCount = 0;
  bool _feedViewLogged = false;
  bool _notificationNudgeHandled = false;
  bool _hindiHintShown = false;
  bool _loaded = false;

  int get visitCount => _visitCount;

  bool get _sessionOneComplete =>
      SessionOneService.instance.hasCompletedFirstRead;

  /// Second+ app visit after Session 1 payoff.
  bool get isSession2Active =>
      _loaded && _visitCount >= 2 && _sessionOneComplete;

  bool get shouldShowPickedSection => isSession2Active;

  bool get shouldShowNotificationNudge =>
      isSession2Active &&
      !_notificationNudgeHandled &&
      SessionOneService.instance.hasCompletedFirstRead;

  Future<void> load() async {
    await SessionOneService.instance.load();
    try {
      final prefs = await SharedPreferences.getInstance();
      _visitCount = prefs.getInt(prefsVisitCount) ?? 0;
      _feedViewLogged = prefs.getBool(prefsFeedViewLogged) ?? false;
      _notificationNudgeHandled =
          prefs.getBool(prefsNotificationNudgeHandled) ?? false;
      _hindiHintShown = prefs.getBool(prefsHindiHintShown) ?? false;
    } catch (e, st) {
      debugPrint('SessionTwoService.load failed: $e\n$st');
    }
    _loaded = true;
  }

  /// Call once per app cold start.
  Future<void> recordAppVisit() async {
    if (!_loaded) await load();
    _visitCount += 1;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(prefsVisitCount, _visitCount);
    } catch (e, st) {
      debugPrint('SessionTwoService.recordAppVisit failed: $e\n$st');
    }
  }

  /// Top [limit] stories by recency from an already-filtered list.
  List<Article> pickStoriesForYou(
    List<Article> visibleArticles, {
    int limit = 3,
  }) {
    if (!shouldShowPickedSection || visibleArticles.isEmpty) {
      return const <Article>[];
    }
    final ranked = FeedPersonalizationService.instance.rankArticles(
      visibleArticles,
    );
    return ranked.take(limit).toList();
  }

  List<Article> feedExcludingPicked(
    List<Article> visibleArticles,
    List<Article> picked,
  ) {
    if (picked.isEmpty) return visibleArticles;
    final pickedUrls = picked.map((a) => a.url.trim()).toSet();
    return visibleArticles
        .where((a) => !pickedUrls.contains(a.url.trim()))
        .toList();
  }

  Future<void> logSession2FeedViewIfNeeded() async {
    if (!isSession2Active || _feedViewLogged) return;
    _feedViewLogged = true;
    UserInteractionLogger.instance.recordFunnelMilestone('session2_feed_view');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefsFeedViewLogged, true);
    } catch (e, st) {
      debugPrint(
        'SessionTwoService.logSession2FeedViewIfNeeded failed: $e\n$st',
      );
    }
  }

  /// One-time snackbar when Hindi was chosen earlier.
  Future<String?> consumeHindiContinuityHint({required bool isHindi}) async {
    if (!isSession2Active || !isHindi || _hindiHintShown) return null;
    _hindiHintShown = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefsHindiHintShown, true);
    } catch (e, st) {
      debugPrint(
        'SessionTwoService.consumeHindiContinuityHint failed: $e\n$st',
      );
    }
    return 'आपकी ब्रिफ़ हिंदी में जारी है';
  }

  Future<void> markNotificationNudgeHandled({required bool enabled}) async {
    _notificationNudgeHandled = true;
    UserInteractionLogger.instance.recordFunnelMilestone(
      enabled
          ? 'session2_notification_enabled'
          : 'session2_notification_dismissed',
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefsNotificationNudgeHandled, true);
    } catch (e, st) {
      debugPrint(
        'SessionTwoService.markNotificationNudgeHandled failed: $e\n$st',
      );
    }
  }

  void logNotificationNudgeShown() {
    UserInteractionLogger.instance.recordFunnelMilestone(
      'session2_notification_nudge_shown',
    );
  }

  @visibleForTesting
  Future<void> resetForTest() async {
    _visitCount = 0;
    _feedViewLogged = false;
    _notificationNudgeHandled = false;
    _hindiHintShown = false;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsVisitCount);
    await prefs.remove(prefsFeedViewLogged);
    await prefs.remove(prefsNotificationNudgeHandled);
    await prefs.remove(prefsHindiHintShown);
  }

  @visibleForTesting
  void setVisitCountForTest(int count) {
    _visitCount = count;
    _loaded = true;
  }
}
