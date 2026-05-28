import 'package:flutter/material.dart';

import 'app_page_transitions.dart';
import 'article_image.dart';
import 'article_model.dart';
import 'article_source_icon.dart';
import 'article_preview_page.dart';
import 'deep_analysis_overlay.dart';
import 'bookmark_storage.dart';
import 'telemetry_impression_detector.dart';
import 'user_interaction_logger.dart';

/// Saved articles from local storage ([BookmarkStorage]).
class BookmarksPage extends StatefulWidget {
  const BookmarksPage({
    super.key,
    required this.isHindi,
    required this.formatTimeAgo,
    this.onBookmarksChanged,
  });

  final bool isHindi;
  final String Function(DateTime timestamp) formatTimeAgo;
  final VoidCallback? onBookmarksChanged;

  @override
  State<BookmarksPage> createState() => _BookmarksPageState();
}

class _BookmarksPageState extends State<BookmarksPage> {
  List<Article> _bookmarks = <Article>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _reload();
    });
  }

  Future<void> _reload() async {
    if (mounted) setState(() => _loading = true);
    final list = await BookmarkStorage.loadArticles();
    if (!mounted) return;
    setState(() {
      _bookmarks = list;
      _loading = false;
    });
  }

  String _summaryPreview(Article article) {
    final raw = widget.isHindi
        ? article.summaryHindi.trim()
        : article.summary.trim();
    if (raw.isEmpty) {
      return widget.isHindi ? 'हिंदी सार उपलब्ध नहीं' : 'Tap for summary.';
    }
    const maxLen = 140;
    if (raw.length <= maxLen) return raw;
    return '${raw.substring(0, maxLen)}…';
  }

  Future<void> _toggleBookmark(Article article) async {
    final ok = await BookmarkStorage.removeByUrl(article.url);
    widget.onBookmarksChanged?.call();
    await _reload();
    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.isHindi
              ? 'बुकमार्क हटाया नहीं जा सका।'
              : 'Could not remove bookmark.',
        ),
      ),
    );
  }

  void _openArticlePreview(Article article) {
    UserInteractionLogger.instance.recordArticleClick(article.url);
    final u = article.url.trim();
    final ix = _bookmarks.indexWhere((a) => a.url.trim() == u);
    final initial = ix < 0 ? 0 : ix;
    Navigator.of(context).push<void>(
      NyusPageTransitions.pushRoute<void>(
        ArticlePreviewSurveyPage(
          verticalArticles: List<Article>.from(_bookmarks),
          initialVerticalIndex: initial,
          tagNeighborCandidates: List<Article>.from(_bookmarks),
          isHindi: widget.isHindi,
          timeAgoFor: (a) => widget.formatTimeAgo(a.harvestedAt),
        ),
        settings: const RouteSettings(name: 'bookmarks_article_preview'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isHindi ? 'बुकमार्क' : 'Bookmarks',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _bookmarks.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  widget.isHindi
                      ? 'अभी तक कोई लेख सेव नहीं किया गया।'
                      : 'No bookmarks yet. Tap the bookmark icon on a story to save it here.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _reload,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: _bookmarks.length,
                itemBuilder: (context, index) {
                  final article = _bookmarks[index];
                  final title = widget.isHindi
                      ? (article.titleHindi.trim().isNotEmpty
                            ? article.titleHindi
                            : 'हिंदी शीर्षक उपलब्ध नहीं')
                      : article.title;

                  return TelemetryImpressionDetector(
                    articleUrl: article.url,
                    tags: article.tags,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        elevation: 0,
                        color: theme.colorScheme.surface,
                        margin: EdgeInsets.zero,
                        clipBehavior: Clip.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => _openArticlePreview(article),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              title,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: theme.textTheme.titleSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              _summaryPreview(article),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: theme
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                    height: 1.25,
                                                  ),
                                            ),
                                            DeepAnalysisButton(
                                              deepAnalysis: article.deepAnalysis,
                                              isHindi: widget.isHindi,
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
                              padding: const EdgeInsets.only(
                                right: 4,
                                top: 6,
                                bottom: 6,
                              ),
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
                                    visualDensity: VisualDensity.compact,
                                    icon: Icon(
                                      Icons.bookmark_rounded,
                                      color: theme.colorScheme.primary,
                                    ),
                                    tooltip: widget.isHindi
                                        ? 'बुकमार्क हटाएँ'
                                        : 'Remove bookmark',
                                    onPressed: () => _toggleBookmark(article),
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
              ),
            ),
    );
  }
}
