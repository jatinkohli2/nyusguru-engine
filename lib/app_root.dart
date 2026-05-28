import 'package:flutter/material.dart';

import 'onboarding_screen.dart';
import 'onboarding_service.dart';

/// Chooses onboarding vs main feed (Plan A step 2 entry).
class AppRoot extends StatefulWidget {
  const AppRoot({super.key, required this.feed});

  final Widget feed;

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  bool? _needsOnboarding;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await OnboardingService.instance.load();
    if (!mounted) return;
    setState(() {
      _needsOnboarding = OnboardingService.instance.shouldShowOnboarding;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_needsOnboarding == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_needsOnboarding!) {
      return OnboardingScreen(
        onFinished: () => setState(() => _needsOnboarding = false),
      );
    }

    return widget.feed;
  }
}
