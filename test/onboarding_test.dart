import 'package:flutter_test/flutter_test.dart';
import 'package:nyusguru_app/onboarding_service.dart';
import 'package:nyusguru_app/user_interaction_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    UserInteractionLogger.instance.start();
    await OnboardingService.instance.resetForTest();
    await OnboardingService.instance.load();
  });

  test('onboarding shows until marked complete', () async {
    expect(OnboardingService.instance.shouldShowOnboarding, isTrue);
    await OnboardingService.instance.markComplete();
    expect(OnboardingService.instance.shouldShowOnboarding, isFalse);
  });
}
