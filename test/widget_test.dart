// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nyusguru_app/main.dart';
import 'package:nyusguru_app/onboarding_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      OnboardingService.prefsComplete: true,
    });
  });

  testWidgets('NewsFeedScreen basic UI renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NewsFeedScreen(onToggleTheme: () {}),
      ),
    );

    expect(find.text('NyusGuru'), findsOneWidget);
    expect(find.text('English'), findsNothing);
    expect(find.text('Hindi'), findsNothing);
    expect(find.byTooltip('Search'), findsOneWidget);

    // Shimmer placeholders mimic news cards while the feed request is pending.
    expect(find.byType(NewsSkeleton), findsNWidgets(6));
  });
}
