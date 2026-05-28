import 'package:flutter/widgets.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'feed_personalization_service.dart';
import 'user_interaction_logger.dart';

/// Emits [TelemetryEventType.articleImpression] once when ≥ [visibleFractionThreshold]
/// of this subtree is on screen (feed cards, bookmark rows).
class TelemetryImpressionDetector extends StatefulWidget {
  const TelemetryImpressionDetector({
    super.key,
    required this.articleUrl,
    required this.child,
    this.tags = const <String>[],
    this.visibleFractionThreshold = 0.5,
  });

  final String articleUrl;
  final List<String> tags;
  final Widget child;
  final double visibleFractionThreshold;

  @override
  State<TelemetryImpressionDetector> createState() =>
      _TelemetryImpressionDetectorState();
}

class _TelemetryImpressionDetectorState
    extends State<TelemetryImpressionDetector> {
  bool _impressionRecorded = false;

  @override
  Widget build(BuildContext context) {
    final url = widget.articleUrl.trim();
    if (url.isEmpty) {
      return widget.child;
    }

    return VisibilityDetector(
      key: ValueKey<String>('telemetry_impression_$url'),
      onVisibilityChanged: (info) {
        if (_impressionRecorded) return;
        if (info.visibleFraction < widget.visibleFractionThreshold) return;
        _impressionRecorded = true;
        UserInteractionLogger.instance.recordArticleImpression(url);
        FeedPersonalizationService.instance.recordImpression(widget.tags);
      },
      child: widget.child,
    );
  }
}
