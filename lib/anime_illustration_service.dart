import 'dart:convert';

import 'package:http/http.dart' as http;

import 'nyusguru_api_config.dart';

/// Server AnimeGAN (`ensure-anime-image`). Call only when a publisher image URL exists.
class AnimeIllustrationService {
  AnimeIllustrationService._();

  static final Map<String, Future<String?>> _inflight =
      <String, Future<String?>>{};
  static final Map<String, String> _successCache = <String, String>{};

  /// Returns public anime illustration URL, or `null` if skipped / failed (safe to retry later).
  static Future<String?> fetchAnimeIllustration({
    required String articleUrl,
    required String sourceImageUrl,
  }) async {
    if (_successCache.containsKey(articleUrl)) {
      return Future<String?>.value(_successCache[articleUrl]);
    }

    return _inflight
        .putIfAbsent(articleUrl, () async {
          try {
            final uri = Uri.parse(NyusGuruApiConfig.ensureAnimeImageUrl);
            final response = await http
                .post(
                  uri,
                  headers: NyusGuruApiConfig.apiHeaders(jsonContent: true),
                  body: jsonEncode(<String, String>{
                    'article_url': articleUrl,
                    'source_image_url': sourceImageUrl,
                  }),
                )
                .timeout(const Duration(seconds: 120));

            if (response.statusCode >= 200 && response.statusCode < 300) {
              final dynamic decoded = jsonDecode(response.body);
              if (decoded is Map<String, dynamic>) {
                final animeRaw = decoded['anime_image_url'];
                final anime = animeRaw is String ? animeRaw.trim() : '';
                if (anime.isNotEmpty) {
                  _successCache[articleUrl] = anime;
                  return anime;
                }
              }
            }
          } catch (_) {
            // Retry allowed on next widget rebuild / navigation.
          }
          return null;
        })
        .whenComplete(() {
          _inflight.remove(articleUrl);
        });
  }
}
