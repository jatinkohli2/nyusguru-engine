import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'article_model.dart';

class BookmarkStorage {
  BookmarkStorage._();

  static const String _prefsKey = 'nyusguru_bookmarked_articles_v1';

  static Future<List<Article>> loadArticles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return <Article>[];

      final decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) return <Article>[];

      final out = <Article>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        try {
          // jsonDecode map runtime type is not always Map<String, dynamic>.
          out.add(Article.fromJson(Map<String, dynamic>.from(item)));
        } catch (e, st) {
          debugPrint('BookmarkStorage: skipped bad entry: $e\n$st');
        }
      }
      return out;
    } catch (e, st) {
      debugPrint('BookmarkStorage.loadArticles failed: $e\n$st');
      return <Article>[];
    }
  }

  static Future<Set<String>> bookmarkedUrls() async {
    final articles = await loadArticles();
    return articles.map((a) => a.url.trim()).where((u) => u.isNotEmpty).toSet();
  }

  static Future<bool> _persist(List<Article> articles) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(
        articles.map((a) => a.toJson()).toList(growable: false),
      );
      final ok = await prefs.setString(_prefsKey, encoded);
      if (!ok) {
        debugPrint('BookmarkStorage._persist: setString returned false');
      }
      return ok;
    } catch (e, st) {
      debugPrint('BookmarkStorage._persist failed: $e\n$st');
      return false;
    }
  }

  /// Adds [article] at the front if missing; returns whether disk save succeeded.
  static Future<bool> add(Article article) async {
    final u = article.url.trim();
    if (u.isEmpty) return false;

    final list = await loadArticles();
    list.removeWhere((a) => a.url.trim() == u);
    list.insert(
      0,
      Article(
        url: u,
        title: article.title,
        titleHindi: article.titleHindi,
        summary: article.summary,
        summaryHindi: article.summaryHindi,
        deepAnalysis: article.deepAnalysis,
        imageUrl: article.imageUrl,
        animeImageUrl: article.animeImageUrl,
        tags: article.tags,
        harvestedAt: article.harvestedAt,
      ),
    );
    return _persist(list);
  }

  static Future<bool> removeByUrl(String url) async {
    final u = url.trim();
    if (u.isEmpty) return false;
    final list = await loadArticles();
    list.removeWhere((a) => a.url.trim() == u);
    return _persist(list);
  }

  static Future<bool> isBookmarked(String url) async {
    final u = url.trim();
    if (u.isEmpty) return false;
    final urls = await bookmarkedUrls();
    return urls.contains(u);
  }
}
