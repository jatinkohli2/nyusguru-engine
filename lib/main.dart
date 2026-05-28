import 'dart:async' show StreamSubscription, Timer, TimeoutException;
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

import 'article_image.dart';
import 'article_model.dart';
import 'app_page_transitions.dart';
import 'article_preview_page.dart';
import 'deep_analysis_overlay.dart';
import 'article_share.dart';
import 'article_source_icon.dart';
import 'bookmark_storage.dart';
import 'bookmarks_page.dart';
import 'high_value_signal_service.dart';
import 'nyusguru_api_config.dart';
import 'push_notification_service.dart';
import 'telemetry_impression_detector.dart';
import 'user_interaction_logger.dart';

const List<String> _newsFilterCategories = <String>[
  'Politics',
  'Sports',
  'Finance',
  'Entertainment',
  'Crime',
  'Technology',
  'Education',
  'Health',
  'International',
  'Lifestyle',
  'All',
];

const String _prefsKeyHindi = 'nyusguru_pref_hindi';
const String _prefsKeyCategoryFilters = 'nyusguru_pref_category_filters';

/// Edge functions can cold-start; short client timeouts cause false failures.
const Duration _kNewsFeedHttpTimeout = Duration(seconds: 45);
const int _kNewsFeedMaxAttempts = 3;

const Duration _kUiAnimDuration = Duration(milliseconds: 440);
const Curve _kUiAnimCurve = Curves.easeOutQuart;
const Curve _kUiAnimCurveIn = Curves.easeOutQuart;
const Curve _kUiAnimCurveOut = Curves.easeInQuart;

/// Square NG crop from `NyusGuru_7`: centered, largest square (see tool script).
const String _appLogoAsset = 'assets/images/app_logo_mark.png';

/// Wordmark / primary blue (pairs with `NyusGuru_7` mark; slate navy).
const Color _kBrandNyusBlue = Color(0xFF3A5680);

/// Dark-mode wordmark color (warm gold on dark surfaces).
const Color _kBrandWordmarkGold = Color(0xFFE8C547);

/// Light-mode canvas and widget surfaces — ivory.
const Color _kLightLogoCanvas = Color(0xFFFFF8E7);

/// Valid [num.clamp] bounds for narrow / first-frame widths (avoids exceptions).
double _toolbarFallbackTitleWidth(double screenWidthDp) {
  final sw = screenWidthDp.isFinite && screenWidthDp > 0 ? screenWidthDp : 400.0;
  final upper = sw;
  final lower = upper < 120 ? upper : 120.0;
  return (sw - 200).clamp(lower, upper).toDouble();
}

Widget _nyusGuruLogoTitleRow(
  BuildContext context, {
  required double logoHeight,
  double gap = 6,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final wordColor = isDark ? _kBrandWordmarkGold : _kBrandNyusBlue;

  final wordStyle = TextStyle(
    fontSize: logoHeight * 0.36,
    fontWeight: FontWeight.w800,
    height: 1,
    letterSpacing: -0.2,
    color: wordColor,
  );

  return Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      SizedBox(
        height: logoHeight,
        width: logoHeight,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(logoHeight * 0.12),
          child: Image.asset(
            _appLogoAsset,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
      SizedBox(width: gap),
      Flexible(
        child: Text(
          'NyusGuru',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: wordStyle,
        ),
      ),
    ],
  );
}

String _friendlyNewsLoadError(Object error) {
  if (error is SocketException) {
    return 'You appear to be offline. Check your connection, then tap Refresh.';
  }
  if (error is FormatException) {
    return 'We received an unexpected response from the news feed. Tap Refresh to try again.';
  }
  final raw = error.toString();
  final lowered = raw.toLowerCase();
  if (lowered.contains('timed out') || lowered.contains('timeout')) {
    return 'The request took too long. Check your connection and tap Refresh.';
  }
  if (lowered.contains('failed host lookup') ||
      lowered.contains('network is unreachable')) {
    return 'Could not reach NyusGuru. Check your connection and tap Refresh.';
  }
  if (raw.startsWith('Exception: ')) {
    final inner = raw.substring('Exception: '.length);
    if (inner.contains('statusCode') ||
        inner.contains('<!doctype') ||
        inner.length > 200) {
      return 'Something went wrong loading news. Tap Refresh to retry.';
    }
    return inner;
  }
  return 'Something went wrong loading news. Tap Refresh to retry.';
}

/// Placeholder row matching feed card layout while articles load.
class NewsSkeleton extends StatelessWidget {
  const NewsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final base = isDark
        ? const Color(0xFF2C2C2E)
        : Color.lerp(Colors.grey.shade300, theme.colorScheme.surface, 0.35)!;
    final highlight = isDark
        ? const Color(0xFF3D3D40)
        : Color.lerp(Colors.grey.shade100, theme.colorScheme.surface, 0.5)!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        elevation: 0,
        color: theme.colorScheme.surface,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: Shimmer.fromColors(
          baseColor: base,
          highlightColor: highlight,
          period: const Duration(milliseconds: 1300),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: base,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final w = constraints.maxWidth;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    height: 14,
                                    width: w,
                                    decoration: BoxDecoration(
                                      color: base,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    height: 14,
                                    width: w * 0.82,
                                    decoration: BoxDecoration(
                                      color: base,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    height: 11,
                                    width: w,
                                    decoration: BoxDecoration(
                                      color: base,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    height: 11,
                                    width: w * 0.94,
                                    decoration: BoxDecoration(
                                      color: base,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    height: 11,
                                    width: w * 0.62,
                                    decoration: BoxDecoration(
                                      color: base,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 4, top: 6, bottom: 6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: base,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: base,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  UserInteractionLogger.instance.start();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;

  static ThemeData _lightTheme() {
    final seeded = ColorScheme.fromSeed(
      seedColor: _kBrandNyusBlue,
      brightness: Brightness.light,
    );
    final scheme = seeded.copyWith(
      surface: _kLightLogoCanvas,
      surfaceDim: _kLightLogoCanvas,
      surfaceBright: _kLightLogoCanvas,
      surfaceContainerLowest: _kLightLogoCanvas,
      surfaceContainerLow: _kLightLogoCanvas,
      surfaceContainer: _kLightLogoCanvas,
      surfaceContainerHigh: _kLightLogoCanvas,
      surfaceContainerHighest: _kLightLogoCanvas,
    );

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: _kLightLogoCanvas,
      canvasColor: _kLightLogoCanvas,
      splashFactory: InkSparkle.splashFactory,
      cardTheme: const CardThemeData(
        color: _kLightLogoCanvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _kLightLogoCanvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: _kLightLogoCanvas,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: _kLightLogoCanvas,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _kLightLogoCanvas,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  static ThemeData _darkTheme() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _kBrandNyusBlue,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      splashFactory: InkSparkle.splashFactory,
    );
  }

  void _toggleThemeMode() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NyusGuru',
      debugShowCheckedModeBanner: false,
      theme: _lightTheme(),
      darkTheme: _darkTheme(),
      themeMode: _themeMode,
      themeAnimationDuration: const Duration(milliseconds: 560),
      themeAnimationCurve: Curves.easeInOutQuart,
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        final media = MediaQuery.of(context);
        // Respect Dynamic Type / accessibility without blowing layouts on phones.
        final scaler = media.textScaler.clamp(
          minScaleFactor: defaultTargetPlatform == TargetPlatform.iOS
              ? 0.85
              : 0.8,
          maxScaleFactor: defaultTargetPlatform == TargetPlatform.iOS
              ? 1.45
              : 1.45,
        );
        return MediaQuery(
          data: media.copyWith(textScaler: scaler),
          child: child,
        );
      },
      home: NewsFeedScreen(onToggleTheme: _toggleThemeMode),
    );
  }
}

class NewsFeedScreen extends StatefulWidget {
  const NewsFeedScreen({super.key, required this.onToggleTheme});

  final VoidCallback onToggleTheme;

  @override
  State<NewsFeedScreen> createState() => _NewsFeedScreenState();
}

class _NewsFeedScreenState extends State<NewsFeedScreen> {
  /// Loaded articles (kept visible during pull-to-refresh so [RefreshIndicator] stays stable).
  List<Article> _articles = <Article>[];
  Object? _feedError;
  bool _initialLoading = true;
  int _feedRequestSeq = 0;
  bool _isHindi = false;
  Set<String> _selectedCategoryFilters = <String>{'All'};
  bool _isSearching = false;
  String _searchQuery = '';
  final ScrollController _feedScrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Set<String> _bookmarkedUrls = <String>{};
  Timer? _noNewNewsOverlayTimer;
  String? _noNewNewsOverlayText;
  bool _showScrollActions = false;
  Timer? _scrollActionsHideTimer;
  StreamSubscription<String>? _pushArticleTapSub;

  @override
  void initState() {
    super.initState();
    _loadUserPrefs();
    _loadFeed();
    _initPushNotifications();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshBookmarkedUrls();
    });
  }

  Future<void> _initPushNotifications() async {
    _pushArticleTapSub?.cancel();
    await PushNotificationService.initialize(
      onToken: (token) => HighValueSignalService.registerDeviceToken(
        token: token,
        platform: Platform.isIOS ? 'ios' : 'android',
      ),
    );
    _pushArticleTapSub = PushNotificationService.articleTapStream.listen(
      _openArticleFromPushPayload,
    );
  }

  void _openArticleFromPushPayload(String articleUrl) {
    final url = articleUrl.trim();
    if (url.isEmpty || !mounted) return;
    final index = _articles.indexWhere((a) => a.url.trim() == url);
    if (index < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isHindi
                ? 'यह लेख अभी फ़ीड में उपलब्ध नहीं है।'
                : 'This article is not in the current feed yet.',
          ),
        ),
      );
      return;
    }
    final article = _articles[index];
    _openArticlePreview(article, _articles);
  }

  Future<void> _loadUserPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hindi = prefs.getBool(_prefsKeyHindi) ?? false;
      final raw = prefs.getString(_prefsKeyCategoryFilters);
      var cats = <String>{'All'};
      if (raw != null && raw.isNotEmpty) {
        final parsed = raw
            .split('|')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toSet();
        final allowed =
            parsed.where((c) => _newsFilterCategories.contains(c)).toSet();
        if (allowed.isEmpty) {
          cats = {'All'};
        } else if (allowed.contains('All')) {
          cats = {'All'};
        } else {
          cats = allowed;
        }
      }
      if (!mounted) return;
      setState(() {
        _isHindi = hindi;
        _selectedCategoryFilters = cats;
      });
    } catch (e, st) {
      debugPrint('_loadUserPrefs failed: $e\n$st');
    }
  }

  Future<void> _persistUserPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKeyHindi, _isHindi);
      final sorted = _selectedCategoryFilters.toList()..sort();
      await prefs.setString(_prefsKeyCategoryFilters, sorted.join('|'));
    } catch (e, st) {
      debugPrint('_persistUserPrefs failed: $e\n$st');
    }
  }

  /// Loads the remote feed. Pull refresh keeps existing [_articles] on screen until success.
  Future<void> _loadFeed({bool fromPullRefresh = false}) async {
    final seq = ++_feedRequestSeq;

    final urlsBeforePull =
        fromPullRefresh ? _articleUrlSet(_articles) : null;

    final showSkeleton = _articles.isEmpty;

    if (showSkeleton) {
      setState(() {
        _initialLoading = true;
        _feedError = null;
      });
    }

    try {
      final list = await _fetchArticles();
      if (!mounted || seq != _feedRequestSeq) return;
      final noNewLinksAfterPull = fromPullRefresh &&
          urlsBeforePull != null &&
          _sameArticleUrlSet(urlsBeforePull, list);
      setState(() {
        _articles = list;
        _feedError = null;
        _initialLoading = false;
      });
      if (noNewLinksAfterPull && mounted) {
        _showPullRefreshNoNewNewsBanner();
      }
    } catch (e, st) {
      debugPrint('News feed load failed: $e\n$st');
      if (!mounted || seq != _feedRequestSeq) return;
      if (_articles.isEmpty) {
        setState(() {
          _initialLoading = false;
          _feedError = e;
        });
      } else {
        setState(() => _initialLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyNewsLoadError(e))),
        );
      }
    }
  }

  Future<void> _reloadNewsFeedForPullRefresh() async {
    await _loadFeed(fromPullRefresh: true);
  }

  static Set<String> _articleUrlSet(List<Article> articles) {
    return articles
        .map((a) => a.url.trim())
        .where((u) => u.isNotEmpty)
        .toSet();
  }

  static bool _sameArticleUrlSet(Set<String> before, List<Article> after) {
    final next = _articleUrlSet(after);
    return before.length == next.length &&
        before.containsAll(next) &&
        next.containsAll(before);
  }

  void _showPullRefreshNoNewNewsBanner() {
    _noNewNewsOverlayTimer?.cancel();
    final text = _isHindi
        ? 'नई ख़बरें जल्द उपलब्ध होंगी।'
        : 'Standby for more intel';
    setState(() => _noNewNewsOverlayText = text);
    _noNewNewsOverlayTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _noNewNewsOverlayText = null);
    });
  }

  Future<void> _refreshBookmarkedUrls() async {
    try {
      final urls = await BookmarkStorage.bookmarkedUrls();
      if (!mounted) return;
      setState(() => _bookmarkedUrls = urls);
    } catch (e, st) {
      debugPrint('Bookmarks refresh failed: $e\n$st');
      if (!mounted) return;
      setState(() => _bookmarkedUrls = <String>{});
    }
  }

  Future<void> _onBookmarkIconPressed(Article article) async {
    final url = article.url.trim();
    if (url.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isHindi
                ? 'इस लेख का लिंक नहीं है।'
                : 'Cannot bookmark this story (missing link).',
          ),
        ),
      );
      return;
    }

    final on = _bookmarkedUrls.contains(url);
    setState(() {
      if (on) {
        _bookmarkedUrls = {..._bookmarkedUrls}..remove(url);
      } else {
        _bookmarkedUrls = {..._bookmarkedUrls, url};
      }
    });

    final ok =
        on ? await BookmarkStorage.removeByUrl(url) : await BookmarkStorage.add(article);

    await _refreshBookmarkedUrls();

    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isHindi
              ? 'बुकमार्क सेव नहीं हो सका। दुबारा कोशिश करें।'
              : 'Could not save bookmark. Please try again.',
        ),
      ),
    );
  }

  void _openBookmarksPage() {
    Navigator.of(context).push<void>(
      NyusPageTransitions.pushRoute<void>(
        BookmarksPage(
          isHindi: _isHindi,
          formatTimeAgo: _formatTimeAgo,
          onBookmarksChanged: _refreshBookmarkedUrls,
        ),
        settings: const RouteSettings(name: 'bookmarks'),
      ),
    );
  }

  Future<List<Article>> _fetchArticles() async {
    final headers = NyusGuruApiConfig.apiHeaders();
    final uri = Uri.parse(NyusGuruApiConfig.newsFeedUrl);
    const userTimeoutHint =
        'Request timed out. Check your connection and pull Refresh.';

    for (var attempt = 0; attempt < _kNewsFeedMaxAttempts; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(Duration(milliseconds: 600 * attempt));
      }
      try {
        final response = await http.get(uri, headers: headers).timeout(
              _kNewsFeedHttpTimeout,
              onTimeout: () => throw TimeoutException(
                userTimeoutHint,
                _kNewsFeedHttpTimeout,
              ),
            );

        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception(
            'News feed returned status ${response.statusCode}. Please try again shortly.',
          );
        }

        final dynamic decoded = jsonDecode(response.body);
        final List<dynamic> data = decoded is List
            ? decoded
            : decoded is Map<String, dynamic> && decoded['articles'] is List
            ? decoded['articles'] as List<dynamic>
            : <dynamic>[];

        return data
            .whereType<Map<String, dynamic>>()
            .map(Article.fromJson)
            .toList();
      } on TimeoutException catch (_, st) {
        final isLast = attempt >= _kNewsFeedMaxAttempts - 1;
        if (isLast) {
          debugPrint(
            'News feed: timeout after $_kNewsFeedMaxAttempts attempts\n$st',
          );
          throw Exception(userTimeoutHint);
        }
        debugPrint(
          'News feed: attempt ${attempt + 1} timed out, retrying…',
        );
      }
    }

    throw Exception(userTimeoutHint);
  }

  void _restartNewsFetch() {
    _loadFeed();
  }

  Widget _noNewsIllustration(ThemeData theme, {required bool showWifiIssue}) {
    final bg = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.65);
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bg,
      ),
      child: Icon(
        showWifiIssue ? Icons.wifi_off_rounded : Icons.article_outlined,
        size: 72,
        color: theme.colorScheme.primary.withValues(alpha: 0.85),
      ),
    );
  }

  Widget _buildEmptyOrErrorFeed({
    required ThemeData theme,
    required String subtitle,
    required bool showWifiIssue,
    required VoidCallback onRefresh,
  }) {
    final title = _isHindi ? 'कोई समाचार नहीं मिला' : 'No News Found';
    final refreshLabel = _isHindi ? 'रीफ़्रेश' : 'Refresh';
    final hint = _isHindi
        ? 'अपडेट के लिए रीफ़्रेश दबाएँ।'
        : 'Tap Refresh to load the latest stories.';

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          controller: _feedScrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _noNewsIllustration(theme, showWifiIssue: showWifiIssue),
                    const SizedBox(height: 24),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      hint,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.85,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    FilledButton.icon(
                      onPressed: onRefresh,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(refreshLabel),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _scrollToTop() async {
    if (!_feedScrollController.hasClients) return;
    await _feedScrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutQuart,
    );
  }

  void _onMainFeedScrollActivity() {
    _scrollActionsHideTimer?.cancel();
    if (!_showScrollActions) {
      setState(() => _showScrollActions = true);
    }
    _scrollActionsHideTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _showScrollActions = false);
    });
  }

  bool _onMainFeedScrollNotification(ScrollNotification n) {
    if (n is ScrollStartNotification || n is ScrollUpdateNotification) {
      _onMainFeedScrollActivity();
    }
    return false;
  }

  String _scrollHintBarCopy() {
    if (_isHindi) {
      return '↓⟲ रिफ़्रेश · ☰ मेन्यू · ↑↓ सार · ←→ जुड़ी';
    }
    return '↓⟲ refresh · ☰ menu · ↑↓ story · ←→ related';
  }

  @override
  void dispose() {
    _noNewNewsOverlayTimer?.cancel();
    _scrollActionsHideTimer?.cancel();
    _pushArticleTapSub?.cancel();
    _feedScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _formatTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final localTime = timestamp.toLocal();
    final difference = now.difference(localTime);

    if (difference.inSeconds < 60) {
      return 'just now';
    }
    if (difference.inMinutes < 60) {
      return Intl.plural(
        difference.inMinutes,
        one: '1 min ago',
        other: '${difference.inMinutes} mins ago',
      );
    }
    if (difference.inHours < 24) {
      return Intl.plural(
        difference.inHours,
        one: '1 hour ago',
        other: '${difference.inHours} hours ago',
      );
    }
    return Intl.plural(
      difference.inDays,
      one: '1 day ago',
      other: '${difference.inDays} days ago',
    );
  }

  static List<String> _keywordsForCategoryFilter(String category) {
    final b = category.toLowerCase();
    switch (category) {
      case 'Technology':
        return <String>[b, 'tech'];
      case 'Sports':
        return <String>[b, 'sport'];
      case 'Finance':
        return <String>[b, 'business', 'economy', 'market'];
      case 'Entertainment':
        return <String>[b, 'entertain'];
      case 'International':
        return <String>[b, 'world', 'global'];
      case 'Education':
        return <String>[b, 'edu', 'school', 'university'];
      case 'Health':
        return <String>[b, 'medical', 'wellness'];
      default:
        return <String>[b];
    }
  }

  bool _matchesCategoryKeyword(Article article, String category) {
    if (category == 'All') return true;
    final needles = _keywordsForCategoryFilter(category);
    return article.tags.any((tag) {
      final t = tag.toLowerCase().replaceAll('#', '').trim();
      return needles.any((n) => n.isNotEmpty && t.contains(n));
    });
  }

  bool _passesCategoryFilters(Article article) {
    if (_selectedCategoryFilters.isEmpty ||
        _selectedCategoryFilters.contains('All')) {
      return true;
    }
    return _selectedCategoryFilters
        .any((c) => _matchesCategoryKeyword(article, c));
  }

  bool _isCategoryFilterChecked(String category) {
    if (_selectedCategoryFilters.contains('All') ||
        _selectedCategoryFilters.isEmpty) {
      return category == 'All';
    }
    return _selectedCategoryFilters.contains(category);
  }

  void _applyCategoryFilterToggle(String category, bool checked) {
    if (category == 'All') {
      _selectedCategoryFilters = <String>{'All'};
      return;
    }
    final next = Set<String>.from(_selectedCategoryFilters)..remove('All');
    if (checked) {
      next.add(category);
    } else {
      next.remove(category);
    }
    _selectedCategoryFilters = next.isEmpty ? <String>{'All'} : next;
  }

  String _categoryDisplayLabel(String category) {
    if (!_isHindi) return category;
    return switch (category) {
      'Politics' => 'राजनीति',
      'Sports' => 'खेल',
      'Finance' => 'वित्त',
      'Entertainment' => 'मनोरंजन',
      'Crime' => 'अपराध',
      'Technology' => 'प्रौद्योगिकी',
      'Education' => 'शिक्षा',
      'Health' => 'स्वास्थ्य',
      'International' => 'अंतरराष्ट्रीय',
      'Lifestyle' => 'जीवनशैली',
      'All' => 'सभी',
      _ => category,
    };
  }

  bool _matchesSearch(Article article, String query) {
    if (query.isEmpty) return true;
    final normalizedQuery = query.toLowerCase();
    return article.title.toLowerCase().contains(normalizedQuery) ||
        article.titleHindi.toLowerCase().contains(normalizedQuery);
  }

  String _feedSummaryPreview(Article article) {
    final raw = _isHindi
        ? article.summaryHindi.trim()
        : article.summary.trim();
    if (raw.isEmpty) {
      return _isHindi ? 'हिंदी सार उपलब्ध नहीं' : 'Tap for summary.';
    }
    const maxLen = 240;
    if (raw.length <= maxLen) return raw;
    return '${raw.substring(0, maxLen)}…';
  }

  void _openArticlePreview(Article article, List<Article> selection) {
    UserInteractionLogger.instance.recordArticleClick(article.url);
    final initialIndex = selection.indexWhere((a) => a.url == article.url);
    Navigator.of(context).push<void>(
      NyusPageTransitions.pushRoute<void>(
        ArticlePreviewSurveyPage(
          verticalArticles: selection,
          initialVerticalIndex: initialIndex >= 0 ? initialIndex : 0,
          tagNeighborCandidates: selection,
          isHindi: _isHindi,
          timeAgoFor: (a) => _formatTimeAgo(a.harvestedAt),
        ),
        settings: const RouteSettings(name: 'article_preview'),
      ),
    );
  }

  Widget _skeletonLoadingFeed() {
    return SingleChildScrollView(
      controller: _feedScrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: List<Widget>.generate(6, (_) => const NewsSkeleton()),
      ),
    );
  }

  Widget _newsListForFeed(List<Article> visibleArticles, ThemeData theme) {
    return ListView.builder(
      controller: _feedScrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: visibleArticles.length,
      itemBuilder: (context, index) {
        final article = visibleArticles[index];
        final title = _isHindi
            ? (article.titleHindi.trim().isNotEmpty
                  ? article.titleHindi
                  : 'हिंदी शीर्षक उपलब्ध नहीं')
            : article.title;
        return TelemetryImpressionDetector(
          articleUrl: article.url,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              elevation: 0,
              color: theme.colorScheme.surface,
              margin: EdgeInsets.zero,
              clipBehavior: Clip.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () =>
                        _openArticlePreview(article, visibleArticles),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                width: 88,
                                height: 88,
                                child: ArticleNetworkImage(
                                  article: article,
                                  width: 88,
                                  height: 88,
                                  iconSize: 32,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _feedSummaryPreview(article),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontSize: 13,
                                      height: 1.35,
                                    ),
                                  ),
                                  DeepAnalysisButton(
                                    deepAnalysis: article.deepAnalysis,
                                    isHindi: _isHindi,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 4, top: 6, bottom: 6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ArticleSourceFavicon(
                          articleUrl: article.url,
                          size: 22,
                        ),
                        const SizedBox(height: 2),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 44,
                            minHeight: 44,
                          ),
                          iconSize: 22,
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            _bookmarkedUrls.contains(article.url.trim())
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                          ),
                          tooltip:
                              _bookmarkedUrls.contains(article.url.trim())
                                  ? (_isHindi
                                        ? 'बुकमार्क हटाएँ'
                                        : 'Remove bookmark')
                                  : (_isHindi ? 'बुकमार्क करें' : 'Bookmark'),
                          onPressed: () => _onBookmarkIconPressed(article),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNewsFeedBody(ThemeData theme) {
    if (_initialLoading && _articles.isEmpty) {
      return _skeletonLoadingFeed();
    }

    if (_feedError != null && _articles.isEmpty) {
      final friendly = _friendlyNewsLoadError(_feedError!);
      final wifiIssue =
          _feedError is SocketException ||
          friendly.toLowerCase().contains('offline') ||
          friendly.toLowerCase().contains('connection') ||
          friendly.toLowerCase().contains('network') ||
          friendly.toLowerCase().contains('reach');

      return RefreshIndicator(
        onRefresh: _reloadNewsFeedForPullRefresh,
        child: _buildEmptyOrErrorFeed(
          theme: theme,
          subtitle: friendly,
          showWifiIssue: wifiIssue,
          onRefresh: _restartNewsFetch,
        ),
      );
    }

    final visibleArticles = _articles
        .where(_passesCategoryFilters)
        .where((article) => _matchesSearch(article, _searchQuery))
        .toList();

    if (visibleArticles.isEmpty) {
      final subtitle = _articles.isEmpty
          ? (_isHindi
                ? 'अभी दिखाने के लिए कोई खबर नहीं है।'
                : 'There are no stories to show right now.')
          : (_isHindi
                ? 'इस फ़िल्टर से कोई खबर नहीं मिली। दूसरी श्रेणी चुनें या रीफ़्रेश करें।'
                : 'No stories match this filter. Try another category or tap Refresh.');

      return RefreshIndicator(
        onRefresh: _reloadNewsFeedForPullRefresh,
        child: _buildEmptyOrErrorFeed(
          theme: theme,
          subtitle: subtitle,
          showWifiIssue: false,
          onRefresh: _restartNewsFetch,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _reloadNewsFeedForPullRefresh,
      child: _newsListForFeed(visibleArticles, theme),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxW = constraints.maxWidth.isFinite &&
                            constraints.maxWidth > 0
                        ? constraints.maxWidth
                        : MediaQuery.sizeOf(context).width * 0.85;
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxW),
                          child: _nyusGuruLogoTitleRow(context, logoHeight: 60),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.bookmarks_rounded),
                title: Text(_isHindi ? 'बुकमार्क' : 'Bookmarks'),
                onTap: () async {
                  final nav = Navigator.of(context);
                  await nav.maybePop();
                  if (!context.mounted) return;
                  _openBookmarksPage();
                },
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Text(
                  _isHindi ? 'भाषा' : 'Language',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment<bool>(value: false, label: Text('English')),
                    ButtonSegment<bool>(value: true, label: Text('Hindi')),
                  ],
                  selected: {_isHindi},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _isHindi = selection.first;
                    });
                    _persistUserPrefs();
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
                child: Text(
                  _isHindi ? 'समाचार श्रेणियाँ' : 'News categories',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 12),
                  children: [
                    for (final cat in _newsFilterCategories)
                      CheckboxListTile(
                        value: _isCategoryFilterChecked(cat),
                        onChanged: (v) {
                          setState(
                            () =>
                                _applyCategoryFilterToggle(cat, v ?? false),
                          );
                          _persistUserPrefs();
                        },
                        title: Text(_categoryDisplayLabel(cat)),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                child: Text(
                  _isHindi ? 'संस्करण 1.0.0' : 'Version 1.0.0',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        titleSpacing: 0,
        title: _isSearching
            ? TextField(
                key: const ValueKey<String>('appbar_search'),
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search titles...',
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.trim();
                  });
                },
              )
            : LayoutBuilder(
                key: const ValueKey<String>('appbar_logo'),
                builder: (context, constraints) {
                  final screenW = MediaQuery.sizeOf(context).width;
                  final maxW = constraints.maxWidth.isFinite &&
                          constraints.maxWidth > 0
                      ? constraints.maxWidth
                      : _toolbarFallbackTitleWidth(screenW);
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxW),
                        child: _nyusGuruLogoTitleRow(context, logoHeight: 48),
                      ),
                    ),
                  );
                },
              ),
        centerTitle: false,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: _isHindi ? 'शेयर करें' : 'Share app',
            onPressed: () =>
                shareNyusGuruApp(context, isHindi: _isHindi),
          ),
          IconButton(
            icon: const Icon(Icons.bookmarks_outlined),
            tooltip: _isHindi ? 'बुकमार्क' : 'Bookmarks',
            onPressed: _openBookmarksPage,
          ),
          IconButton(
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
            ),
            tooltip: Theme.of(context).brightness == Brightness.dark
                ? 'Light mode'
                : 'Dark mode',
            onPressed: widget.onToggleTheme,
          ),
          IconButton(
            icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded),
            tooltip: _isSearching ? 'Close search' : 'Search',
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _searchController.clear();
                  _searchQuery = '';
                }
                _isSearching = !_isSearching;
              });
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedCrossFade(
            duration: _kUiAnimDuration,
            sizeCurve: _kUiAnimCurve,
            firstCurve: _kUiAnimCurveIn,
            secondCurve: _kUiAnimCurveOut,
            alignment: Alignment.topCenter,
            crossFadeState: _showScrollActions
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Material(
                    color: theme.brightness == Brightness.dark
                        ? const Color(0xFF3A3A3C)
                        : _kLightLogoCanvas,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
          children: [
                    Expanded(
                      child: Text(
                        _scrollHintBarCopy(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          height: 1.2,
                          letterSpacing: 0.35,
                          color: theme.brightness == Brightness.dark
                              ? const Color(0xFFE8E8E8)
                              : const Color(0xFF2C2C2E),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        _scrollToTop();
                        _onMainFeedScrollActivity();
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        _isHindi ? 'शीर्ष' : 'Top',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                          decorationColor: theme.colorScheme.primary,
                        ),
                      ),
            ),
          ],
        ),
      ),
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                NotificationListener<ScrollNotification>(
                  onNotification: _onMainFeedScrollNotification,
                  child: _buildNewsFeedBody(theme),
                ),
                AnimatedSwitcher(
                  duration: _kUiAnimDuration,
                  switchInCurve: _kUiAnimCurveIn,
                  switchOutCurve: _kUiAnimCurveOut,
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                    final curved = CurvedAnimation(
                      parent: animation,
                      curve: _kUiAnimCurveIn,
                      reverseCurve: _kUiAnimCurveOut,
                    );
                    return FadeTransition(
                      opacity: curved,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.06),
                          end: Offset.zero,
                        ).animate(curved),
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.92, end: 1).animate(
                            curved,
                          ),
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: _noNewNewsOverlayText == null
                      ? const SizedBox.shrink(
                          key: ValueKey<String>('no_new_news_off'),
                        )
                      : IgnorePointer(
                          key: ValueKey<String>(
                            _noNewNewsOverlayText!,
                          ),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                              ),
                              child: Material(
                                elevation: 8,
                                borderRadius: BorderRadius.circular(16),
                                color: theme.colorScheme.inverseSurface,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 26,
                                    vertical: 18,
                                  ),
                                  child: Text(
                                    _noNewNewsOverlayText!,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                      color: theme.colorScheme.onInverseSurface,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
