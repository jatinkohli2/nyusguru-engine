import 'package:flutter/material.dart';

import 'news_categories.dart';

/// Quick filters for topics the user follows (Plan A step 4).
class FollowedTopicsBar extends StatelessWidget {
  const FollowedTopicsBar({
    super.key,
    required this.followedTopics,
    required this.selectedTopic,
    required this.isHindi,
    required this.onTopicSelected,
  });

  final Set<String> followedTopics;
  final String? selectedTopic;
  final bool isHindi;
  final void Function(String? topic) onTopicSelected;

  @override
  Widget build(BuildContext context) {
    if (followedTopics.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final label = isHindi ? 'फ़ॉलो किए विषय' : 'Topics you follow';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: Text(isHindi ? 'सभी फ़ॉलो' : 'All following'),
                  selected: selectedTopic == null,
                  onSelected: (_) => onTopicSelected(null),
                ),
                const SizedBox(width: 6),
                for (final topic in followedTopics)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(topic),
                      selected: selectedTopic == topic,
                      onSelected: (_) => onTopicSelected(topic),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static bool isValidTopic(String topic) =>
      kOnboardingInterestCategories.contains(topic);
}
