import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'article_model.dart';

/// Plan A step 3 — ranks the feed from impressions, clicks, dwell, and preferences.
class FeedPersonalizationService {
  FeedPersonalizationService._();

  static final FeedPersonalizationService instance =
      FeedPersonalizationService._();

  static const String prefsTagScores = 'nyusguru_tag_affinities_v1';
  static const double _maxTagScore = 100;

  Map<String, double> _tagScores = <String, double>{};
  bool _loaded = false;

  bool get hasPersonalization => _tagScores.isNotEmpty;

  String? get topAffinityTag {
    if (_tagScores.isEmpty) return null;
    return _tagScores.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(prefsTagScores);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          _tagScores = decoded.map(
            (key, value) => MapEntry(
              '$key',
              (value is num ? value.toDouble() : 0.0)
                  .clamp(0.0, _maxTagScore)
                  .toDouble(),
            ),
          );
        }
      }
    } catch (e, st) {
      debugPrint('FeedPersonalizationService.load failed: $e\n$st');
      _tagScores = <String, double>{};
    }
    _loaded = true;
  }

  Future<void> _persist() async {
    if (!_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsTagScores, jsonEncode(_tagScores));
    } catch (e, st) {
      debugPrint('FeedPersonalizationService._persist failed: $e\n$st');
    }
  }

  static String normalizeTag(String raw) {
    return raw.toLowerCase().replaceAll('#', '').trim();
  }

  void _boostTags(Iterable<String> tags, double amount) {
    if (amount <= 0) return;
    var changed = false;
    for (final raw in tags) {
      final tag = normalizeTag(raw);
      if (tag.length < 2) continue;
      final next = ((_tagScores[tag] ?? 0) + amount)
          .clamp(0.0, _maxTagScore)
          .toDouble();
      _tagScores[tag] = next;
      changed = true;
    }
    if (changed) {
      unawaited(_persist());
    }
  }

  void recordImpression(List<String> tags) => _boostTags(tags, 0.35);

  void recordClick(List<String> tags) => _boostTags(tags, 2.0);

  void recordDwell(List<String> tags, int seconds) {
    final clamped = seconds.clamp(1, 120);
    _boostTags(tags, clamped * 0.08);
  }

  void recordLiked(List<String> tags) => _boostTags(tags, 3.0);

  void recordMoreLikeThis(List<String> tags) => _boostTags(tags, 5.0);

  /// Higher = more relevant for this user.
  double scoreArticle(Article article) {
    var affinity = 0.0;
    for (final raw in article.tags) {
      affinity += _tagScores[normalizeTag(raw)] ?? 0;
    }

    final hoursSince = DateTime.now()
        .difference(article.harvestedAt)
        .inHours
        .clamp(0, 720);
    final recency = 1.0 / (1.0 + hoursSince / 24.0);

    return affinity * 2.0 + recency * 1.5;
  }

  List<Article> rankArticles(List<Article> articles) {
    if (articles.length <= 1) return List<Article>.from(articles);

    final ranked = List<Article>.from(articles);
    ranked.sort((a, b) {
      final scoreCmp = scoreArticle(b).compareTo(scoreArticle(a));
      if (scoreCmp != 0) return scoreCmp;
      return b.harvestedAt.compareTo(a.harvestedAt);
    });
    return ranked;
  }

  @visibleForTesting
  Map<String, double> get tagScoresForTest =>
      Map<String, double>.from(_tagScores);

  @visibleForTesting
  Future<void> resetForTest() async {
    _tagScores = <String, double>{};
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsTagScores);
  }
}
