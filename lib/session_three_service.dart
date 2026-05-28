import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'article_model.dart';
import 'feed_personalization_service.dart';
import 'news_categories.dart';
import 'session_one_service.dart';
import 'session_two_service.dart';
import 'user_interaction_logger.dart';

/// Plan A step 2 — Session 3: return visit, new-since-last-visit, habit hints.
class SessionThreeService {
  SessionThreeService._();

  static final SessionThreeService instance = SessionThreeService._();

  static const String prefsLastVisitMs = 'nyusguru_session3_last_visit_ms';
  static const String prefsNewBannerDismissed =
      'nyusguru_session3_new_banner_dismissed';
  static const String prefsBookmarkHintShown =
      'nyusguru_session3_bookmark_hint_shown';
  static const String prefsCategoryHintShown =
      'nyusguru_session3_category_hint_shown';

  DateTime? _lastVisit;
  bool _newBannerDismissed = false;
  bool _bookmarkHintShown = false;
  bool _categoryHintShown = false;
  bool _loaded = false;

  bool get isSession3Active {
    if (!_loaded) return false;
    return SessionTwoService.instance.visitCount >= 3 &&
        SessionOneService.instance.hasCompletedFirstRead;
  }

  Future<void> load() async {
    await SessionOneService.instance.load();
    try {
      final prefs = await SharedPreferences.getInstance();
      final ms = prefs.getInt(prefsLastVisitMs);
      _lastVisit = ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
      _newBannerDismissed = prefs.getBool(prefsNewBannerDismissed) ?? false;
      _bookmarkHintShown = prefs.getBool(prefsBookmarkHintShown) ?? false;
      _categoryHintShown = prefs.getBool(prefsCategoryHintShown) ?? false;
    } catch (e, st) {
      debugPrint('SessionThreeService.load failed: $e\n$st');
    }
    _loaded = true;
  }

  Future<void> markLastVisitNow() async {
    final now = DateTime.now();
    _lastVisit = now;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(prefsLastVisitMs, now.millisecondsSinceEpoch);
    } catch (e, st) {
      debugPrint('SessionThreeService.markLastVisitNow failed: $e\n$st');
    }
  }

  int countNewSinceLastVisit(List<Article> articles) {
    final since = _lastVisit;
    if (since == null) return 0;
    return articles.where((a) => a.harvestedAt.isAfter(since)).length;
  }

  bool shouldShowNewSinceBanner(List<Article> articles) {
    if (!isSession3Active || _newBannerDismissed) return false;
    return countNewSinceLastVisit(articles) > 0;
  }

  Future<void> dismissNewSinceBanner() async {
    _newBannerDismissed = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefsNewBannerDismissed, true);
    } catch (e, st) {
      debugPrint('SessionThreeService.dismissNewSinceBanner failed: $e\n$st');
    }
  }

  Future<String?> consumeBookmarkHint({required bool isHindi}) async {
    if (!isSession3Active || _bookmarkHintShown) return null;
    _bookmarkHintShown = true;
    UserInteractionLogger.instance.recordFunnelMilestone(
      'session3_bookmark_hint_shown',
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefsBookmarkHintShown, true);
    } catch (e, st) {
      debugPrint('SessionThreeService.consumeBookmarkHint failed: $e\n$st');
    }
    return isHindi
        ? 'बाद में पढ़ने के लिए कहानियाँ बुकमार्क करें'
        : 'Bookmark stories to finish later';
  }

  /// Suggests a drawer category when user still has “All” and we have tag signal.
  String? suggestedCategoryIfStillOnAll(Set<String> selectedFilters) {
    if (!isSession3Active || _categoryHintShown) return null;
    if (!selectedFilters.contains('All') || selectedFilters.length != 1) {
      return null;
    }

    final topTag = FeedPersonalizationService.instance.topAffinityTag;
    if (topTag == null) return null;

    for (final cat in kOnboardingInterestCategories) {
      if (_tagMatchesCategory(topTag, cat)) return cat;
    }
    return null;
  }

  Future<void> markCategoryHintShown() async {
    _categoryHintShown = true;
    UserInteractionLogger.instance.recordFunnelMilestone(
      'session3_category_hint_shown',
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefsCategoryHintShown, true);
    } catch (e, st) {
      debugPrint('SessionThreeService.markCategoryHintShown failed: $e\n$st');
    }
  }

  static bool _tagMatchesCategory(String tag, String category) {
    final t = tag.toLowerCase();
    switch (category) {
      case 'Technology':
        return t.contains('tech') || t.contains('ai') || t.contains('startup');
      case 'Finance':
        return t.contains('market') ||
            t.contains('stock') ||
            t.contains('finance') ||
            t.contains('econom');
      case 'Sports':
        return t.contains('sport') ||
            t.contains('cricket') ||
            t.contains('nba');
      case 'Politics':
        return t.contains('politic') ||
            t.contains('election') ||
            t.contains('gov');
      case 'Entertainment':
        return t.contains('entertain') ||
            t.contains('bollywood') ||
            t.contains('film');
      case 'Health':
        return t.contains('health') || t.contains('medical');
      case 'Education':
        return t.contains('educat') ||
            t.contains('school') ||
            t.contains('exam');
      case 'International':
        return t.contains('world') ||
            t.contains('global') ||
            t.contains('international');
      case 'Crime':
        return t.contains('crime') || t.contains('police');
      case 'Lifestyle':
        return t.contains('lifestyle') || t.contains('fashion');
      default:
        return t.contains(category.toLowerCase());
    }
  }

  @visibleForTesting
  Future<void> resetForTest() async {
    _lastVisit = null;
    _newBannerDismissed = false;
    _bookmarkHintShown = false;
    _categoryHintShown = false;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsLastVisitMs);
    await prefs.remove(prefsNewBannerDismissed);
    await prefs.remove(prefsBookmarkHintShown);
    await prefs.remove(prefsCategoryHintShown);
  }

  @visibleForTesting
  void setLastVisitForTest(DateTime? when) {
    _lastVisit = when;
    _loaded = true;
  }
}
