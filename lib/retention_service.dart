import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'digest_notification_plugin.dart';
import 'news_categories.dart';
import 'user_interaction_logger.dart';

/// Plan A step 4 — streaks, digest timing, followed topics.
class RetentionService {
  RetentionService._();

  static final RetentionService instance = RetentionService._();

  static const String prefsStreakCount = 'nyusguru_retention_streak_count';
  static const String prefsLastStreakDay = 'nyusguru_retention_last_streak_day';
  static const String prefsDigestHour = 'nyusguru_retention_digest_hour';
  static const String prefsDigestEnabled = 'nyusguru_retention_digest_enabled';
  static const String prefsFollowedTopics =
      'nyusguru_retention_followed_topics';
  static const String prefsDigestBannerDay =
      'nyusguru_retention_digest_banner_day';

  static const int defaultDigestHour = 8;

  int _streakCount = 0;
  String? _lastStreakDay;
  int _digestHour = defaultDigestHour;
  bool _digestEnabled = false;
  Set<String> _followedTopics = <String>{};
  String? _digestBannerShownDay;
  bool _loaded = false;

  int get streakCount => _streakCount;
  int get digestHour => _digestHour;
  bool get digestEnabled => _digestEnabled;
  Set<String> get followedTopics => Set<String>.unmodifiable(_followedTopics);

  bool get hasFollowedTopics => _followedTopics.isNotEmpty;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _streakCount = prefs.getInt(prefsStreakCount) ?? 0;
      _lastStreakDay = prefs.getString(prefsLastStreakDay);
      _digestHour = prefs.getInt(prefsDigestHour) ?? defaultDigestHour;
      _digestEnabled = prefs.getBool(prefsDigestEnabled) ?? false;
      _digestBannerShownDay = prefs.getString(prefsDigestBannerDay);
      final raw = prefs.getString(prefsFollowedTopics);
      _followedTopics = _parseTopics(raw);
    } catch (e, st) {
      debugPrint('RetentionService.load failed: $e\n$st');
    }
    _loaded = true;
  }

  static Set<String> _parseTopics(String? raw) {
    if (raw == null || raw.isEmpty) return <String>{};
    return raw
        .split('|')
        .map((s) => s.trim())
        .where((s) => kOnboardingInterestCategories.contains(s))
        .toSet();
  }

  static String _todayKey([DateTime? now]) {
    final d = now ?? DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static String _yesterdayKey([DateTime? now]) {
    final d = (now ?? DateTime.now()).subtract(const Duration(days: 1));
    return _todayKey(d);
  }

  /// Call when the user reads at least one article in a session.
  Future<void> recordDailyEngagement() async {
    if (!_loaded) await load();
    final today = _todayKey();
    if (_lastStreakDay == today) return;

    if (_lastStreakDay == _yesterdayKey()) {
      _streakCount += 1;
    } else {
      _streakCount = 1;
    }
    _lastStreakDay = today;

    UserInteractionLogger.instance.recordFunnelMilestone(
      'retention_streak_$_streakCount',
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(prefsStreakCount, _streakCount);
      await prefs.setString(prefsLastStreakDay, _lastStreakDay!);
    } catch (e, st) {
      debugPrint('RetentionService.recordDailyEngagement failed: $e\n$st');
    }
  }

  String streakHeadline({required bool isHindi}) {
    if (_streakCount <= 0) {
      return isHindi ? 'आज अपनी ब्रिफ़ शुरू करें' : 'Start your brief today';
    }
    if (_streakCount == 1) {
      return isHindi ? '🔥 1 दिन की लय' : '🔥 1-day streak';
    }
    return isHindi
        ? '🔥 $_streakCount दिन की लय'
        : '🔥 $_streakCount-day streak';
  }

  Future<void> setDigestEnabled(bool enabled) async {
    _digestEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefsDigestEnabled, enabled);
    } catch (e, st) {
      debugPrint('RetentionService.setDigestEnabled failed: $e\n$st');
    }
    if (enabled) {
      UserInteractionLogger.instance.recordFunnelMilestone(
        'retention_digest_enabled',
      );
    }
    unawaited(DigestNotificationScheduler.reschedule());
  }

  Future<void> setDigestHour(int hour) async {
    _digestHour = hour.clamp(0, 23);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(prefsDigestHour, _digestHour);
    } catch (e, st) {
      debugPrint('RetentionService.setDigestHour failed: $e\n$st');
    }
    unawaited(DigestNotificationScheduler.reschedule());
  }

  String digestTimeLabel({required bool isHindi}) {
    final h = _digestHour;
    final period = h >= 12
        ? (isHindi ? 'अपराह्न' : 'PM')
        : (isHindi ? 'पूर्वाह्न' : 'AM');
    final display = h % 12 == 0 ? 12 : h % 12;
    final padded = display.toString();
    if (isHindi) {
      return '$padded:00 $period';
    }
    return '$padded:00 ${h >= 12 ? 'PM' : 'AM'}';
  }

  Future<void> toggleFollowTopic(String topic, bool follow) async {
    final t = topic.trim();
    if (!kOnboardingInterestCategories.contains(t)) return;
    if (follow) {
      _followedTopics.add(t);
    } else {
      _followedTopics.remove(t);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final sorted = _followedTopics.toList()..sort();
      await prefs.setString(prefsFollowedTopics, sorted.join('|'));
    } catch (e, st) {
      debugPrint('RetentionService.toggleFollowTopic failed: $e\n$st');
    }
    if (follow) {
      UserInteractionLogger.instance.recordFunnelMilestone(
        'retention_follow_$t',
      );
    }
  }

  bool isFollowing(String topic) => _followedTopics.contains(topic);

  /// Seeds follows from onboarding / drawer category picks.
  Future<void> syncFollowedFromCategoryFilters(Set<String> filters) async {
    if (_followedTopics.isNotEmpty) return;
    if (filters.contains('All') || filters.isEmpty) return;
    for (final cat in filters) {
      if (kOnboardingInterestCategories.contains(cat)) {
        _followedTopics.add(cat);
      }
    }
    if (_followedTopics.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final sorted = _followedTopics.toList()..sort();
      await prefs.setString(prefsFollowedTopics, sorted.join('|'));
    } catch (e, st) {
      debugPrint(
        'RetentionService.syncFollowedFromCategoryFilters failed: $e\n$st',
      );
    }
  }

  /// In-app digest nudge when local time passed digest hour and no read today.
  bool shouldShowDigestReadyBanner([DateTime? now]) {
    if (!_digestEnabled) return false;
    final n = now ?? DateTime.now();
    if (n.hour < _digestHour) return false;
    if (_lastStreakDay == _todayKey(n)) return false;
    if (_digestBannerShownDay == _todayKey(n)) return false;
    return true;
  }

  Future<String?> consumeDigestReadyBanner({required bool isHindi}) async {
    if (!shouldShowDigestReadyBanner()) return null;
    final today = _todayKey();
    _digestBannerShownDay = today;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsDigestBannerDay, today);
    } catch (e, st) {
      debugPrint('RetentionService.consumeDigestReadyBanner failed: $e\n$st');
    }
    final topics = _followedTopics.isEmpty
        ? (isHindi ? 'आपकी दैनिक ब्रिफ़' : 'your daily brief')
        : _followedTopics.take(2).join(isHindi ? ' · ' : ' · ');
    return isHindi
        ? 'आपकी $topics तैयार है — ${digestTimeLabel(isHindi: true)} के बाद'
        : 'Your $topics is ready — scheduled for ${digestTimeLabel(isHindi: false)}';
  }

  String smartNotificationBody({required bool isHindi}) {
    if (_followedTopics.isEmpty) {
      return isHindi
          ? 'आपकी ५ मिनट की ब्रिफ़ तैयार है।'
          : 'Your 5-minute brief is ready.';
    }
    final joined = _followedTopics.take(3).join(', ');
    return isHindi
        ? '$joined पर आपकी ब्रिफ़ तैयार है।'
        : 'Your brief on $joined is ready.';
  }

  @visibleForTesting
  Future<void> resetForTest() async {
    _streakCount = 0;
    _lastStreakDay = null;
    _digestHour = defaultDigestHour;
    _digestEnabled = false;
    _followedTopics = <String>{};
    _digestBannerShownDay = null;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsStreakCount);
    await prefs.remove(prefsLastStreakDay);
    await prefs.remove(prefsDigestHour);
    await prefs.remove(prefsDigestEnabled);
    await prefs.remove(prefsFollowedTopics);
    await prefs.remove(prefsDigestBannerDay);
  }

  @visibleForTesting
  void setStreakForTest({required int count, String? lastDay}) {
    _streakCount = count;
    _lastStreakDay = lastDay;
    _loaded = true;
  }
}

/// Schedules one local digest reminder per day (best-effort).
class DigestNotificationScheduler {
  DigestNotificationScheduler._();

  static bool _pluginReady = false;

  static Future<void> initialize() async {
    try {
      // Deferred import pattern avoided; use dynamic plugin init in digest_notifications.dart
      await DigestNotificationPlugin.initialize();
      _pluginReady = true;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('DigestNotificationScheduler init skipped: $e\n$st');
      }
    }
  }

  static Future<void> reschedule() async {
    if (!_pluginReady) return;
    final r = RetentionService.instance;
    if (!r.digestEnabled) {
      await DigestNotificationPlugin.cancelDigest();
      return;
    }
    await DigestNotificationPlugin.scheduleDaily(
      hour: r.digestHour,
      title: 'NyusGuru',
      body: r.smartNotificationBody(isHindi: false),
    );
  }
}
