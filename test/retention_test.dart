import 'package:flutter_test/flutter_test.dart';
import 'package:nyusguru_app/retention_service.dart';
import 'package:nyusguru_app/user_interaction_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    UserInteractionLogger.instance.start();
    await RetentionService.instance.resetForTest();
    await RetentionService.instance.load();
  });

  test('streak starts at 1 on first engagement', () async {
    await RetentionService.instance.recordDailyEngagement();
    expect(RetentionService.instance.streakCount, 1);
    await RetentionService.instance.recordDailyEngagement();
    expect(RetentionService.instance.streakCount, 1);
  });

  test('streak increments after yesterday engagement', () async {
    final prefs = await SharedPreferences.getInstance();
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yKey =
        '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
    await prefs.setString(RetentionService.prefsLastStreakDay, yKey);
    await prefs.setInt(RetentionService.prefsStreakCount, 2);
    await RetentionService.instance.load();

    await RetentionService.instance.recordDailyEngagement();
    expect(RetentionService.instance.streakCount, 3);
  });

  test('digest banner shows after digest hour without read today', () async {
    await RetentionService.instance.setDigestEnabled(true);
    await RetentionService.instance.setDigestHour(0);
    expect(
      RetentionService.instance.shouldShowDigestReadyBanner(DateTime.now()),
      isTrue,
    );
  });

  test('follow topics toggle persists', () async {
    await RetentionService.instance.toggleFollowTopic('Finance', true);
    expect(RetentionService.instance.isFollowing('Finance'), isTrue);
    await RetentionService.instance.load();
    expect(RetentionService.instance.isFollowing('Finance'), isTrue);
  });
}
