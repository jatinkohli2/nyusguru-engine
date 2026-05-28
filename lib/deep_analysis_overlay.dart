import 'package:flutter/material.dart';

/// In-window scrollable deep analysis (modal bottom sheet).
class DeepAnalysisButton extends StatelessWidget {
  const DeepAnalysisButton({
    super.key,
    required this.deepAnalysis,
    this.isHindi = false,
  });

  final String? deepAnalysis;
  final bool isHindi;

  String get _label => isHindi ? 'गहन विश्लेषण' : 'Deep Analysis';

  bool get _hasContent =>
      deepAnalysis != null && deepAnalysis!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (!_hasContent) {
      return const SizedBox.shrink();
    }

    return TextButton.icon(
      onPressed: () => showDeepAnalysisSheet(
        context,
        deepAnalysis!.trim(),
        isHindi: isHindi,
      ),
      icon: const Icon(Icons.insights_outlined, size: 18),
      label: Text(_label),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

Future<void> showDeepAnalysisSheet(
  BuildContext context,
  String deepAnalysis, {
  bool isHindi = false,
}) {
  final theme = Theme.of(context);
  final title = isHindi ? 'गहन विश्लेषण' : 'Deep Analysis';
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) {
      final maxHeight = MediaQuery.sizeOf(ctx).height * 0.85;
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight - 80),
              child: SingleChildScrollView(
                child: SelectableText(
                  deepAnalysis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.45,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
