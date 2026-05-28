import 'package:flutter/material.dart';

import 'article_image.dart';
import 'article_model.dart';

/// Session 2 — “picked for you” header and compact story row.
class SessionTwoPickedSection extends StatelessWidget {
  const SessionTwoPickedSection({
    super.key,
    required this.pickedArticles,
    required this.isHindi,
    required this.titleFor,
    required this.summaryFor,
    required this.onArticleTap,
    this.personalizedRanking = false,
  });

  final List<Article> pickedArticles;
  final bool personalizedRanking;
  final bool isHindi;
  final String Function(Article article) titleFor;
  final String Function(Article article) summaryFor;
  final void Function(Article article) onArticleTap;

  @override
  Widget build(BuildContext context) {
    if (pickedArticles.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final heading = isHindi
        ? (personalizedRanking
              ? 'आपके लिए चुनी गई ३ खबरें · आपकी पसंद के अनुसार'
              : 'आपके लिए चुनी गई ३ खबरें')
        : (personalizedRanking
              ? '3 stories picked for you · based on your reads'
              : '3 stories picked for you');

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  heading,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...pickedArticles.map((article) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.35,
                ),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onArticleTap(article),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 64,
                            height: 64,
                            child: ArticleNetworkImage(
                              article: article,
                              width: 64,
                              height: 64,
                              iconSize: 24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                titleFor(article),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                summaryFor(article),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          const Divider(height: 20),
        ],
      ),
    );
  }
}
