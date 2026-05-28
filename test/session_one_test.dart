import 'package:flutter_test/flutter_test.dart';
import 'package:nyusguru_app/session_one_service.dart';
import 'package:nyusguru_app/user_interaction_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    UserInteractionLogger.instance.start();
    await SessionOneService.instance.resetForTest();
  });

  test('coach mark shows until first article open', () async {
    await SessionOneService.instance.load();
    expect(SessionOneService.instance.shouldShowCoachMark, isTrue);

    await SessionOneService.instance.onFirstArticleOpen();
    expect(SessionOneService.instance.shouldShowCoachMark, isFalse);
    expect(SessionOneService.instance.coachDismissed, isTrue);
  });

  test('celebration consumes once after first open', () async {
    await SessionOneService.instance.load();
    await SessionOneService.instance.onFirstArticleOpen();

    final first = await SessionOneService.instance.consumeCelebration(
      isHindi: false,
    );
    expect(first, contains('Day 1 brief started'));

    final second = await SessionOneService.instance.consumeCelebration(
      isHindi: false,
    );
    expect(second, isNull);
    expect(SessionOneService.instance.briefCelebrated, isTrue);
  });

  test('dwell 30 milestone is logged only once', () async {
    await SessionOneService.instance.load();
    await SessionOneService.instance.onFirstArticleDwell30s();
    await SessionOneService.instance.onFirstArticleDwell30s();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(SessionOneService.prefsDwell30Logged), isTrue);
  });
}
