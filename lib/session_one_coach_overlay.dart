import 'package:flutter/material.dart';

import 'session_one_service.dart';

/// First-session coach: points users to tap the first story.
class SessionOneCoachOverlay extends StatelessWidget {
  const SessionOneCoachOverlay({
    super.key,
    required this.isHindi,
    required this.onDismiss,
  });

  final bool isHindi;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = isHindi
        ? 'अपनी पहली खबर पढ़ने के लिए किसी भी कहानी पर टैप करें'
        : 'Tap any story to read your first brief';

    return Positioned(
      left: 16,
      right: 16,
      top: 12,
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(14),
        color: theme.colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.touch_app_rounded,
                color: theme.colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: isHindi ? 'बंद करें' : 'Dismiss',
                onPressed: () {
                  SessionOneService.instance.dismissCoachMark();
                  onDismiss();
                },
                icon: Icon(
                  Icons.close_rounded,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
