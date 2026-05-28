import 'package:flutter_test/flutter_test.dart';
import 'package:nyusguru_app/article_model.dart';
import 'package:nyusguru_app/feed_personalization_service.dart';
import 'package:nyusguru_app/session_one_service.dart';
import 'package:nyusguru_app/session_two_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Article _article(String url, List<String> tags, DateTime at) {
  return Article(
    url: url,
    title: url,
    titleHindi: url,
    summary: 's',
    summaryHindi: 's',
    tags: tags,
    harvestedAt: at,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SessionOneService.instance.resetForTest();
    await SessionTwoService.instance.resetForTest();
    await FeedPersonalizationService.instance.resetForTest();
    await FeedPersonalizationService.instance.load();
  });

  test('session 2 picks use personalized ranking', () async {
    await SessionOneService.instance.load();
    await SessionOneService.instance.onFirstArticleOpen();
    await SessionTwoService.instance.load();
    SessionTwoService.instance.setVisitCountForTest(2);

    FeedPersonalizationService.instance.recordMoreLikeThis(const <String>[
      'finance',
    ]);

    final articles = <Article>[
      _article('sports', const <String>['sports'], DateTime(2026, 2, 1)),
      _article('finance', const <String>['finance'], DateTime(2026, 1, 1)),
      _article('tech', const <String>['tech'], DateTime(2026, 3, 1)),
    ];

    final ranked = FeedPersonalizationService.instance.rankArticles(articles);
    final picked = SessionTwoService.instance.pickStoriesForYou(
      ranked,
      limit: 1,
    );

    expect(picked.single.url, 'finance');
  });
}
