import 'package:flutter_test/flutter_test.dart';
import 'package:nyusguru_app/article_model.dart';
import 'package:nyusguru_app/feed_personalization_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Article _article({
  required String url,
  required List<String> tags,
  required DateTime harvestedAt,
}) {
  return Article(
    url: url,
    title: 'Title $url',
    titleHindi: 'शीर्षक',
    summary: 'Summary',
    summaryHindi: 'सार',
    tags: tags,
    harvestedAt: harvestedAt,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await FeedPersonalizationService.instance.resetForTest();
    await FeedPersonalizationService.instance.load();
  });

  test('rankArticles uses recency when no signals', () {
    final articles = <Article>[
      _article(
        url: 'a',
        tags: const <String>['tech'],
        harvestedAt: DateTime(2026, 1, 1),
      ),
      _article(
        url: 'b',
        tags: const <String>['sports'],
        harvestedAt: DateTime(2026, 1, 5),
      ),
    ];

    final ranked = FeedPersonalizationService.instance.rankArticles(articles);
    expect(ranked.first.url, 'b');
  });

  test('more like this boosts matching tags to the top', () {
    final articles = <Article>[
      _article(
        url: 'tech-old',
        tags: const <String>['technology'],
        harvestedAt: DateTime(2026, 1, 1),
      ),
      _article(
        url: 'sports-new',
        tags: const <String>['sports'],
        harvestedAt: DateTime(2026, 1, 10),
      ),
      _article(
        url: 'tech-new',
        tags: const <String>['technology', 'ai'],
        harvestedAt: DateTime(2026, 1, 2),
      ),
    ];

    FeedPersonalizationService.instance.recordMoreLikeThis(const <String>[
      'technology',
    ]);

    final ranked = FeedPersonalizationService.instance.rankArticles(articles);
    expect(ranked.first.url, 'tech-new');
    expect(FeedPersonalizationService.instance.hasPersonalization, isTrue);
  });

  test('tag scores persist across load', () async {
    FeedPersonalizationService.instance.recordClick(const <String>['markets']);
    expect(
      FeedPersonalizationService.instance.tagScoresForTest['markets'],
      greaterThan(0),
    );

    await FeedPersonalizationService.instance.load();
    expect(
      FeedPersonalizationService.instance.tagScoresForTest['markets'],
      greaterThan(0),
    );
  });
}
