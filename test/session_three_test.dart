import 'package:flutter_test/flutter_test.dart';
import 'package:nyusguru_app/article_model.dart';
import 'package:nyusguru_app/feed_personalization_service.dart';
import 'package:nyusguru_app/session_one_service.dart';
import 'package:nyusguru_app/session_three_service.dart';
import 'package:nyusguru_app/session_two_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Article _article(DateTime at) {
  return Article(
    url: 'https://example.com/${at.millisecondsSinceEpoch}',
    title: 't',
    titleHindi: 't',
    summary: 's',
    summaryHindi: 's',
    tags: const <String>['finance'],
    harvestedAt: at,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SessionOneService.instance.resetForTest();
    await SessionTwoService.instance.resetForTest();
    await SessionThreeService.instance.resetForTest();
    await FeedPersonalizationService.instance.resetForTest();
  });

  test('session 3 active on visit 3 after first read', () async {
    await SessionOneService.instance.load();
    await SessionOneService.instance.onFirstArticleOpen();
    await SessionTwoService.instance.load();
    SessionTwoService.instance.setVisitCountForTest(3);
    await SessionThreeService.instance.load();
    expect(SessionTwoService.instance.visitCount, greaterThanOrEqualTo(3));
    expect(SessionThreeService.instance.isSession3Active, isTrue);
  });

  test('counts articles newer than last visit', () async {
    await SessionThreeService.instance.load();
    SessionThreeService.instance.setLastVisitForTest(
      DateTime(2026, 1, 11, 18),
    );
    final articles = <Article>[
      _article(DateTime(2026, 1, 9)),
      _article(DateTime(2026, 1, 11, 10)),
      _article(DateTime(2026, 1, 12, 8)),
    ];
    expect(SessionThreeService.instance.countNewSinceLastVisit(articles), 1);
  });

  test('suggests category when on All and tag affinity exists', () async {
    await SessionOneService.instance.load();
    await SessionOneService.instance.onFirstArticleOpen();
    await SessionTwoService.instance.load();
    SessionTwoService.instance.setVisitCountForTest(3);
    await FeedPersonalizationService.instance.load();
    FeedPersonalizationService.instance.recordMoreLikeThis(const <String>[
      'finance',
    ]);
    await SessionThreeService.instance.load();
    expect(SessionThreeService.instance.isSession3Active, isTrue);

    final cat = SessionThreeService.instance.suggestedCategoryIfStillOnAll({
      'All',
    });
    expect(cat, 'Finance');
  });
}
