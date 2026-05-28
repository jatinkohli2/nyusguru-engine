import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'news_categories.dart';
import 'onboarding_service.dart';
import 'retention_service.dart';

/// Plan A step 2 — welcome, language, and up to 3 interest categories.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const String _prefsKeyHindi = 'nyusguru_pref_hindi';
  static const String _prefsKeyCategoryFilters =
      'nyusguru_pref_category_filters';

  final PageController _pageController = PageController();
  int _page = 0;
  bool _isHindi = false;
  final Set<String> _picked = <String>{};

  static const String _promiseEn =
      'Your 5-minute bilingual brief on markets and tech — curated, not endless scrolling.';
  static const String _promiseHi =
      'बाज़ार और टेक पर ५ मिनट की द्विभाषी ब्रिफ़ — चुनी हुई खबरें, अंतहीन स्क्रॉल नहीं।';

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeyHindi, _isHindi);
    final filters = _picked.isEmpty
        ? <String>{'All'}
        : Set<String>.from(_picked);
    final sorted = filters.toList()..sort();
    await prefs.setString(_prefsKeyCategoryFilters, sorted.join('|'));
    await OnboardingService.instance.markComplete();
    for (final cat in _picked) {
      await RetentionService.instance.toggleFollowTopic(cat, true);
    }
    if (!mounted) return;
    widget.onFinished();
  }

  void _next() {
    if (_page >= 2) {
      unawaited(_finish());
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLast = _page >= 2;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  Text(
                    'NyusGuru',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text('${_page + 1}/3'),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _welcomePage(theme),
                  _languagePage(theme),
                  _interestsPage(theme),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  child: Text(
                    isLast
                        ? (_isHindi ? 'ब्रिफ़ शुरू करें' : 'Start my brief')
                        : (_isHindi ? 'आगे' : 'Continue'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _welcomePage(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Icon(
            Icons.newspaper_rounded,
            size: 56,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            _isHindi ? 'NyusGuru में आपका स्वागत है' : 'Welcome to NyusGuru',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _isHindi ? _promiseHi : _promiseEn,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _languagePage(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text(
            _isHindi ? 'भाषा चुनें' : 'Choose your language',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment<bool>(value: false, label: Text('English')),
              ButtonSegment<bool>(value: true, label: Text('Hindi')),
            ],
            selected: {_isHindi},
            onSelectionChanged: (s) => setState(() => _isHindi = s.first),
          ),
        ],
      ),
    );
  }

  Widget _interestsPage(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            _isHindi
                ? 'अपनी रुचियाँ (अधिकतम ३)'
                : 'Your interests (pick up to 3)',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isHindi
                ? 'हम आपकी ब्रिफ़ इन्हीं विषयों पर केंद्रित रखेंगे।'
                : 'We will focus your brief on these topics.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final cat in kOnboardingInterestCategories)
                    FilterChip(
                      label: Text(cat),
                      selected: _picked.contains(cat),
                      onSelected: (on) {
                        setState(() {
                          if (on) {
                            if (_picked.length >= 3) return;
                            _picked.add(cat);
                          } else {
                            _picked.remove(cat);
                          }
                        });
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
