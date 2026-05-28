import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'nyusguru_api_config.dart';

class HighValueSignalService {
  HighValueSignalService._();

  static Future<void> recordPreferenceSignal({
    required String articleUrl,
    required bool liked,
    required bool moreLikeThis,
    required bool isHindi,
    List<String> tags = const <String>[],
  }) async {
    final url = articleUrl.trim();
    if (url.isEmpty) return;

    final body = <String, dynamic>{
      'article_url': url,
      'liked': liked,
      'more_like_this': moreLikeThis,
      // Basis for high-value detector as requested.
      'is_high_value_candidate': liked && moreLikeThis,
      'locale': isHindi ? 'hi' : 'en',
      'tags': tags,
      'client_ts': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      final response = await http
          .post(
            Uri.parse(NyusGuruApiConfig.recordNewsSignalUrl),
            headers: NyusGuruApiConfig.apiHeaders(jsonContent: true),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (response.statusCode == 404) {
          debugPrint(
            'recordPreferenceSignal: Edge Function not found (404). '
            'Deploy `record-news-signal` on project bmrnboonxzkyxgatwgbr or '
            'update _kSignalEndpoint in lib/high_value_signal_service.dart.',
          );
        } else {
          debugPrint(
            'recordPreferenceSignal failed: '
            '${response.statusCode} ${response.body}',
          );
        }
      }
    } catch (e, st) {
      debugPrint('recordPreferenceSignal error: $e\n$st');
    }
  }

  static Future<void> registerDeviceToken({
    required String token,
    required String platform,
  }) async {
    final t = token.trim();
    if (t.isEmpty) return;
    final body = <String, dynamic>{
      'token': t,
      'platform': platform,
      'client_ts': DateTime.now().toUtc().toIso8601String(),
    };
    try {
      final response = await http
          .post(
            Uri.parse(NyusGuruApiConfig.registerDeviceTokenUrl),
            headers: NyusGuruApiConfig.apiHeaders(jsonContent: true),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (response.statusCode == 404) {
          debugPrint(
            'registerDeviceToken: Edge Function not found (404). '
            'Deploy `register-device-token` on Supabase or update _kDeviceEndpoint.',
          );
        } else {
          debugPrint(
            'registerDeviceToken failed: '
            '${response.statusCode} ${response.body}',
          );
        }
      }
    } catch (e, st) {
      debugPrint('registerDeviceToken error: $e\n$st');
    }
  }
}
