import 'dart:async' show Timer, unawaited;
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_page_transitions.dart';
import 'article_image.dart';
import 'article_model.dart';
import 'article_share.dart';
import 'article_source_icon.dart';
import 'high_value_signal_service.dart';
import 'in_app_browser_page.dart';
import 'feed_personalization_service.dart';
import 'session_one_service.dart';
import 'deep_analysis_overlay.dart';
import 'user_interaction_logger.dart';

const Color _kNyusBrandBlue = Color(0xFF3A5680);

/// Tokens derived from tags for fuzzy "closest words" matching between articles.
Set<String> _tagTokens(Article article) {
  final tokens = <String>{};
  for (final raw in article.tags) {
    final lowered = raw.toLowerCase().replaceAll('#', ' ');
    for (final piece in lowered.split(RegExp(r'[^\w\u0900-\u097F]+'))) {
      if (piece.length >= 2) {
        tokens.add(piece);
      }
    }
  }
  return tokens;
}

double _tagSimilarity(Article a, Article b) {
  final ta = _tagTokens(a);
  final tb = _tagTokens(b);
  if (ta.isEmpty || tb.isEmpty) return 0;
  final inter = ta.intersection(tb).length;
  final union = ta.union(tb).length;
  return union == 0 ? 0 : inter / union;
}

/// [center] first, then other articles in this pool ranked by tag similarity.
List<Article> orderedHorizontalNeighbors(Article center, List<Article> pool) {
  final others = pool.where((a) => a.url != center.url).toList();
  final scored = others
      .map((a) => MapEntry(a, _tagSimilarity(center, a)))
      .where((e) => e.value > 0)
      .toList();
  scored.sort((a, b) {
    final bySim = b.value.compareTo(a.value);
    if (bySim != 0) return bySim;
    return b.key.harvestedAt.compareTo(a.key.harvestedAt);
  });
  return [center, ...scored.map((e) => e.key)];
}

/// Brief screen: full article image as a faint watermark behind text on white.
class ArticlePreviewBody extends StatelessWidget {
  static const double _watermarkOpacity = 0.11;

  const ArticlePreviewBody({
    super.key,
    required this.article,
    required this.isHindi,
    required this.timeAgoLabel,
    required this.liked,
    required this.moreLikeThis,
    required this.onToggleLike,
    required this.onToggleMoreLikeThis,
  });

  final Article article;
  final bool isHindi;
  final String timeAgoLabel;
  final bool liked;
  final bool moreLikeThis;
  final VoidCallback onToggleLike;
  final VoidCallback onToggleMoreLikeThis;

  String get _title => isHindi
      ? (article.titleHindi.trim().isNotEmpty
            ? article.titleHindi
            : 'हिंदी शीर्षक उपलब्ध नहीं')
      : article.title;

  String get _summary => isHindi
      ? (article.summaryHindi.trim().isNotEmpty
            ? article.summaryHindi
            : 'हिंदी सार उपलब्ध नहीं')
      : (article.summary.trim().isNotEmpty
            ? article.summary
            : 'No summary available yet.');

  void _openFullArticle(BuildContext context) {
    final raw = article.url.trim();
    final parsedUrl = Uri.tryParse(raw);
    if (raw.isEmpty ||
        parsedUrl == null ||
        !parsedUrl.hasScheme ||
        !parsedUrl.hasAuthority) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isHindi
                ? 'अमान्य या खाली लेख लिंक।'
                : 'Invalid or missing article link.',
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push<void>(
      NyusPageTransitions.pushRoute<void>(
        InAppBrowserPage(url: raw, title: _title),
        settings: const RouteSettings(name: 'in_app_browser'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    final titleStyle =
        theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800) ??
        const TextStyle(fontWeight: FontWeight.w800, fontSize: 20);
    final timeStyle =
        theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ) ??
        TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant);
    final summaryStyle =
        theme.textTheme.bodyLarge?.copyWith(height: 1.42) ??
        const TextStyle(fontSize: 16, height: 1.42);

    final summaryFontSize = summaryStyle.fontSize ?? 16;
    final summaryHeightFactor = summaryStyle.height ?? 1.42;
    final summaryLineHeight = summaryFontSize * summaryHeightFactor;

    final surface = theme.colorScheme.surface;

    return ColoredBox(
      color: surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    clipBehavior: Clip.hardEdge,
                    fit: StackFit.expand,
                    children: [
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: _watermarkOpacity,
                            child: ArticleNetworkImage(
                              article: article,
                              fit: BoxFit.contain,
                              iconSize: 36,
                            ),
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  _title,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: titleStyle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: ArticleSourceFavicon(
                                  articleUrl: article.url,
                                  size: 24,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            timeAgoLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: timeStyle,
                          ),
                          if (article.tags.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (
                                  var i = 0;
                                  i < math.min(article.tags.length, 12);
                                  i++
                                )
                                  Chip(
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    labelPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    label: Text(
                                      article.tags[i],
                                      style: theme.textTheme.labelSmall,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 10),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, inner) {
                                final lines = math.max(
                                  5,
                                  (inner.maxHeight / summaryLineHeight).floor(),
                                );
                                return Align(
                                  alignment: Alignment.topLeft,
                                  child: Text(
                                    _summary,
                                    maxLines: lines,
                                    textAlign: TextAlign.justify,
                                    overflow: TextOverflow.ellipsis,
                                    softWrap: true,
                                    style: summaryStyle,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          ColoredBox(
            color: surface,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomInset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ChoiceChip(
                        label: Text(isHindi ? 'पसंद' : 'Like'),
                        selected: liked,
                        onSelected: (_) => onToggleLike(),
                        avatar: Icon(
                          liked
                              ? Icons.thumb_up_rounded
                              : Icons.thumb_up_alt_outlined,
                          size: 18,
                        ),
                      ),
                      ChoiceChip(
                        label: Text(
                          isHindi ? 'ऐसी और खबरें' : 'More like this',
                        ),
                        selected: moreLikeThis,
                        onSelected: (_) => onToggleMoreLikeThis(),
                        avatar: Icon(
                          moreLikeThis
                              ? Icons.auto_awesome_rounded
                              : Icons.auto_awesome_outlined,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (article.deepAnalysis != null &&
                      article.deepAnalysis!.trim().isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () => showDeepAnalysisSheet(
                        context,
                        article.deepAnalysis!.trim(),
                        isHindi: isHindi,
                      ),
                      icon: const Icon(Icons.insights_outlined),
                      label: Text(
                        isHindi ? 'गहन विश्लेषण' : 'Deep Analysis',
                      ),
                    ),
                  if (article.deepAnalysis != null &&
                      article.deepAnalysis!.trim().isNotEmpty)
                    const SizedBox(height: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _kNyusBrandBlue,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _openFullArticle(context),
                    icon: const Icon(Icons.language_rounded),
                    label: Text(
                      isHindi
                          ? 'वेब पर पूरा लेख पढ़ें'
                          : 'Read full article on site',
                    ),
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

/// Vertical = next/previous in [verticalArticles] (chip/search selection).
/// Horizontal = same-row articles ranked by overlapping tag words (Jaccard on tokens).
class ArticlePreviewSurveyPage extends StatefulWidget {
  const ArticlePreviewSurveyPage({
    super.key,
    required this.verticalArticles,
    required this.initialVerticalIndex,
    required this.tagNeighborCandidates,
    required this.isHindi,
    required this.timeAgoFor,
    this.showNavigationHints = true,
  });

  final List<Article> verticalArticles;
  final int initialVerticalIndex;
  final List<Article> tagNeighborCandidates;
  final bool isHindi;
  final String Function(Article article) timeAgoFor;
  final bool showNavigationHints;

  @override
  State<ArticlePreviewSurveyPage> createState() =>
      _ArticlePreviewSurveyPageState();
}

class _ArticlePreviewSurveyPageState extends State<ArticlePreviewSurveyPage>
    with WidgetsBindingObserver {
  late final PageController _verticalController;
  late int _verticalIndex;
  late Article _articleForShare;
  final Set<String> _likedUrls = <String>{};
  final Set<String> _moreLikeThisUrls = <String>{};
  Timer? _session1DwellTimer;

  bool _isLiked(Article article) => _likedUrls.contains(article.url.trim());
  bool _isMoreLikeThis(Article article) =>
      _moreLikeThisUrls.contains(article.url.trim());

  Future<void> _persistSignal(Article article) async {
    final url = article.url.trim();
    if (url.isEmpty) return;
    await HighValueSignalService.recordPreferenceSignal(
      articleUrl: url,
      liked: _likedUrls.contains(url),
      moreLikeThis: _moreLikeThisUrls.contains(url),
      isHindi: widget.isHindi,
      tags: article.tags,
    );
  }

  void _toggleLike(Article article) {
    final url = article.url.trim();
    if (url.isEmpty) return;
    setState(() {
      if (_likedUrls.contains(url)) {
        _likedUrls.remove(url);
      } else {
        _likedUrls.add(url);
        FeedPersonalizationService.instance.recordLiked(article.tags);
      }
    });
    _persistSignal(article);
  }

  void _toggleMoreLikeThis(Article article) {
    final url = article.url.trim();
    if (url.isEmpty) return;
    setState(() {
      if (_moreLikeThisUrls.contains(url)) {
        _moreLikeThisUrls.remove(url);
      } else {
        _moreLikeThisUrls.add(url);
        FeedPersonalizationService.instance.recordMoreLikeThis(article.tags);
      }
    });
    _persistSignal(article);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final maxIdx = math.max(0, widget.verticalArticles.length - 1);
    _verticalIndex = widget.initialVerticalIndex.clamp(0, maxIdx).toInt();
    _verticalController = PageController(initialPage: _verticalIndex);
    _articleForShare = widget.verticalArticles[_verticalIndex];
    UserInteractionLogger.instance.beginDwellSession(
      _articleForShare.url,
      source: 'article_preview_open',
      tags: _articleForShare.tags,
    );
    _session1DwellTimer = Timer(const Duration(seconds: 30), () {
      unawaited(SessionOneService.instance.onFirstArticleDwell30s());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      UserInteractionLogger.instance.endDwellSession(reason: 'app_background');
    } else if (state == AppLifecycleState.resumed) {
      UserInteractionLogger.instance.beginDwellSession(
        _articleForShare.url,
        source: 'app_foreground',
        tags: _articleForShare.tags,
      );
    }
  }

  void _onVerticalPageChanged(int index) {
    final article = widget.verticalArticles[index];
    UserInteractionLogger.instance.beginDwellSession(
      article.url,
      source: 'vertical_swipe',
      tags: article.tags,
    );
    setState(() {
      _verticalIndex = index;
      _articleForShare = article;
    });
  }

  void _onHorizontalArticleVisible(int rowIndex, Article article) {
    if (rowIndex != _verticalIndex) return;
    UserInteractionLogger.instance.beginDwellSession(
      article.url,
      source: 'horizontal_swipe',
      tags: article.tags,
    );
    setState(() => _articleForShare = article);
  }

  @override
  void dispose() {
    _session1DwellTimer?.cancel();
    UserInteractionLogger.instance.endDwellSession(reason: 'route_pop');
    WidgetsBinding.instance.removeObserver(this);
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isHindi = widget.isHindi;
    final hint = isHindi
        ? '↑↓ फ़ीड · ←→ मिलते टैग'
        : 'Swipe ↑↓ feed · ←→ related tags';

    final surface = Theme.of(context).colorScheme.surface;

    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: isHindi ? 'शेयर करें' : 'Share',
            onPressed: () => shareNyusGuruArticle(
              context,
              article: _articleForShare,
              isHindi: isHindi,
            ),
          ),
        ],
        title: widget.showNavigationHints
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isHindi ? 'लेख' : 'Brief',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    hint,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              )
            : Text(
                isHindi ? 'लेख' : 'Brief',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
      ),
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        controller: _verticalController,
        itemCount: widget.verticalArticles.length,
        onPageChanged: _onVerticalPageChanged,
        itemBuilder: (context, vIdx) {
          final anchor = widget.verticalArticles[vIdx];
          return _HorizontalNeighborsPager(
            key: ValueKey<String>(anchor.url),
            verticalRowIndex: vIdx,
            onVisibleArticleChanged: _onHorizontalArticleVisible,
            anchor: anchor,
            candidatePool: widget.tagNeighborCandidates,
            isHindi: widget.isHindi,
            timeAgoFor: widget.timeAgoFor,
            isLiked: _isLiked,
            isMoreLikeThis: _isMoreLikeThis,
            onToggleLike: _toggleLike,
            onToggleMoreLikeThis: _toggleMoreLikeThis,
          );
        },
      ),
    );
  }
}

class _HorizontalNeighborsPager extends StatefulWidget {
  const _HorizontalNeighborsPager({
    super.key,
    required this.verticalRowIndex,
    required this.onVisibleArticleChanged,
    required this.anchor,
    required this.candidatePool,
    required this.isHindi,
    required this.timeAgoFor,
    required this.isLiked,
    required this.isMoreLikeThis,
    required this.onToggleLike,
    required this.onToggleMoreLikeThis,
  });

  final int verticalRowIndex;
  final void Function(int rowIndex, Article article) onVisibleArticleChanged;
  final Article anchor;
  final List<Article> candidatePool;
  final bool isHindi;
  final String Function(Article article) timeAgoFor;
  final bool Function(Article article) isLiked;
  final bool Function(Article article) isMoreLikeThis;
  final void Function(Article article) onToggleLike;
  final void Function(Article article) onToggleMoreLikeThis;

  @override
  State<_HorizontalNeighborsPager> createState() =>
      _HorizontalNeighborsPagerState();
}

class _HorizontalNeighborsPagerState extends State<_HorizontalNeighborsPager> {
  late final PageController _horizontalController;
  late final List<Article> _pages;

  @override
  void initState() {
    super.initState();
    _pages = orderedHorizontalNeighbors(widget.anchor, widget.candidatePool);
    _horizontalController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _pages.isEmpty) return;
      widget.onVisibleArticleChanged(widget.verticalRowIndex, _pages.first);
    });
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      scrollDirection: Axis.horizontal,
      controller: _horizontalController,
      itemCount: _pages.length,
      onPageChanged: (hIdx) {
        widget.onVisibleArticleChanged(widget.verticalRowIndex, _pages[hIdx]);
      },
      itemBuilder: (context, hIdx) {
        final article = _pages[hIdx];
        return ArticlePreviewBody(
          article: article,
          isHindi: widget.isHindi,
          timeAgoLabel: widget.timeAgoFor(article),
          liked: widget.isLiked(article),
          moreLikeThis: widget.isMoreLikeThis(article),
          onToggleLike: () => widget.onToggleLike(article),
          onToggleMoreLikeThis: () => widget.onToggleMoreLikeThis(article),
        );
      },
    );
  }
}

/// Opens a single brief without swipe neighbors ([tagNeighborCandidates] empty).
class ArticlePreviewPage extends StatelessWidget {
  const ArticlePreviewPage({
    super.key,
    required this.article,
    required this.isHindi,
    required this.timeAgoLabel,
  });

  final Article article;
  final bool isHindi;
  final String timeAgoLabel;

  @override
  Widget build(BuildContext context) {
    return ArticlePreviewSurveyPage(
      verticalArticles: <Article>[article],
      initialVerticalIndex: 0,
      tagNeighborCandidates: const <Article>[],
      isHindi: isHindi,
      timeAgoFor: (_) => timeAgoLabel,
      showNavigationHints: false,
    );
  }
}
