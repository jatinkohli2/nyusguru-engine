import 'package:flutter_test/flutter_test.dart';
import 'package:nyusguru_app/article_model.dart';
import 'package:nyusguru_app/session_one_service.dart';
import 'package:nyusguru_app/session_two_service.dart';
import 'package:nyusguru_app/user_interaction_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

Article _article(String url, DateTime harvestedAt) {
  return Article(
    url: url,
    title: 'Title $url',
    titleHindi: 'शीर्षक',
    summary: 'Summary',
    summaryHindi: 'सार',
    tags: const <String>['tech'],
    harvestedAt: harvestedAt,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    UserInteractionLogger.instance.start();
    await SessionOneService.instance.resetForTest();
    await SessionTwoService.instance.resetForTest();
  });

  test('session 2 inactive on first visit', () async {
    await SessionTwoService.instance.load();
    await SessionTwoService.instance.recordAppVisit();
    expect(SessionTwoService.instance.isSession2Active, isFalse);
    expect(SessionTwoService.instance.shouldShowPickedSection, isFalse);
  });

  test('session 2 active after visit 2 and first read', () async {
    await SessionOneService.instance.load();
    await SessionOneService.instance.onFirstArticleOpen();

    await SessionTwoService.instance.load();
    await SessionTwoService.instance.recordAppVisit();
    await SessionTwoService.instance.recordAppVisit();

    expect(SessionTwoService.instance.isSession2Active, isTrue);
    expect(SessionTwoService.instance.shouldShowPickedSection, isTrue);
  });

  test('pickStoriesForYou returns top 3 by recency', () async {
    await SessionOneService.instance.load();
    await SessionOneService.instance.onFirstArticleOpen();
    await SessionTwoService.instance.load();
    SessionTwoService.instance.setVisitCountForTest(2);

    final articles = <Article>[
      _article('a', DateTime(2026, 1, 1)),
      _article('b', DateTime(2026, 1, 3)),
      _article('c', DateTime(2026, 1, 2)),
      _article('d', DateTime(2026, 1, 4)),
    ];

    final picked = SessionTwoService.instance.pickStoriesForYou(articles);
    expect(picked, hasLength(3));
    expect(picked.first.url, 'd');
    expect(picked[1].url, 'b');
    expect(picked[2].url, 'c');
  });

  test('feedExcludingPicked removes picked URLs', () async {
    final a = _article('a', DateTime.now());
    final b = _article('b', DateTime.now());
    final visible = <Article>[a, b];
    final picked = <Article>[a];

    final rest = SessionTwoService.instance.feedExcludingPicked(
      visible,
      picked,
    );
    expect(rest, hasLength(1));
    expect(rest.first.url, 'b');
  });

  test('notification nudge only once', () async {
    await SessionOneService.instance.load();
    await SessionOneService.instance.onFirstArticleOpen();
    await SessionTwoService.instance.load();
    SessionTwoService.instance.setVisitCountForTest(2);

    expect(SessionTwoService.instance.shouldShowNotificationNudge, isTrue);

    await SessionTwoService.instance.markNotificationNudgeHandled(
      enabled: false,
    );
    expect(SessionTwoService.instance.shouldShowNotificationNudge, isFalse);
  });

  test('hindi continuity hint shows once on session 2', () async {
    await SessionOneService.instance.load();
    await SessionOneService.instance.onFirstArticleOpen();
    await SessionTwoService.instance.load();
    SessionTwoService.instance.setVisitCountForTest(2);

    final first = await SessionTwoService.instance.consumeHindiContinuityHint(
      isHindi: true,
    );
    expect(first, isNotNull);

    final second = await SessionTwoService.instance.consumeHindiContinuityHint(
      isHindi: true,
    );
    expect(second, isNull);
  });
}
