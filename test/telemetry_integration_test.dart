import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:nyusguru_app/nyusguru_api_config.dart';
import 'package:nyusguru_app/user_interaction_logger.dart';

/// Live API checks (real network). Run:
/// `flutter test test/telemetry_integration_test.dart --dart-define=SUPABASE_ANON_KEY=<anon>`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final anon = NyusGuruApiConfig.supabaseAnonKey;
  final skip = anon.isEmpty;

  test('log_user_telemetry RPC accepts batched events', () async {
    if (skip) return;

    UserInteractionLogger.instance.start();
    UserInteractionLogger.instance.recordArticleImpression(
      'https://example.com/flutter-test-impression',
    );
    UserInteractionLogger.instance.recordArticleClick(
      'https://example.com/flutter-test-impression',
    );
    UserInteractionLogger.instance.beginDwellSession(
      'https://example.com/flutter-test-impression',
    );
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    UserInteractionLogger.instance.endDwellSession(reason: 'test');
    UserInteractionLogger.instance.scheduleFlush();

    await Future<void>.delayed(const Duration(seconds: 2));
    UserInteractionLogger.instance.stop();
  }, skip: skip);

  test('record-news-signal edge function returns 2xx', () async {
    if (skip) return;

    final response = await http
        .post(
          Uri.parse(NyusGuruApiConfig.recordNewsSignalUrl),
          headers: NyusGuruApiConfig.apiHeaders(jsonContent: true),
          body: jsonEncode(<String, dynamic>{
            'article_url': 'https://example.com/flutter-test-like',
            'liked': true,
            'more_like_this': false,
            'locale': 'en',
            'tags': <String>['test'],
            'client_ts': DateTime.now().toUtc().toIso8601String(),
          }),
        )
        .timeout(const Duration(seconds: 12));

    expect(
      response.statusCode,
      inInclusiveRange(200, 299),
      reason:
          'anonLen=${NyusGuruApiConfig.supabaseAnonKey.length} '
          'body=${response.body}',
    );
  }, skip: skip);
}
