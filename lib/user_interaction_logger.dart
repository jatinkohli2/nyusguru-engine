import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import 'feed_personalization_service.dart';
import 'nyusguru_api_config.dart';

/// Interaction kinds streamed to [UserInteractionLogger].
enum TelemetryEventType {
  articleImpression('article_impression'),
  articleClick('article_click'),
  dwellTime('dwell_time');

  const TelemetryEventType(this.wireName);
  final String wireName;
}

/// One queued telemetry row (serialized for `log_user_telemetry`).
@immutable
class TelemetryEvent {
  const TelemetryEvent({
    required this.type,
    required this.articleUrl,
    required this.clientTs,
    this.dwellSeconds,
    this.metadata = const <String, dynamic>{},
  });

  final TelemetryEventType type;
  final String articleUrl;
  final DateTime clientTs;
  final int? dwellSeconds;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'event_type': type.wireName,
    'article_url': articleUrl,
    'client_ts': clientTs.toUtc().toIso8601String(),
    if (dwellSeconds != null) 'dwell_seconds': dwellSeconds,
    if (metadata.isNotEmpty) 'metadata': metadata,
  };
}

/// Batches impressions, taps, and dwell time; flushes via Supabase RPC off the UI path.
class UserInteractionLogger with WidgetsBindingObserver {
  UserInteractionLogger._();

  static final UserInteractionLogger instance = UserInteractionLogger._();

  static const int _maxBatchSize = 10;
  static const Duration _flushInterval = Duration(seconds: 30);
  static const int _maxRequeueAfterFailure = 48;

  final List<TelemetryEvent> _queue = <TelemetryEvent>[];
  final Set<String> _impressedArticleUrls = <String>{};

  Timer? _flushTimer;
  bool _flushInFlight = false;
  bool _started = false;

  String? _sessionId;
  String? _activeDwellUrl;
  DateTime? _activeDwellStarted;
  List<String> _activeDwellTags = <String>[];

  /// Call once after [WidgetsFlutterBinding.ensureInitialized].
  void start() {
    if (_started) return;
    _started = true;
    _sessionId = DateTime.now().microsecondsSinceEpoch.toString();
    WidgetsBinding.instance.addObserver(this);
    _flushTimer = Timer.periodic(_flushInterval, (_) => scheduleFlush());
  }

  /// Best-effort final flush (e.g. from root widget dispose).
  void stop() {
    if (!_started) return;
    _started = false;
    _flushTimer?.cancel();
    _flushTimer = null;
    WidgetsBinding.instance.removeObserver(this);
    endDwellSession(reason: 'logger_stop');
    scheduleFlush();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      endDwellSession(reason: 'app_background');
      scheduleFlush();
    }
  }

  /// Fires at most once per app session per [articleUrl] when the card is ≥50% visible.
  void recordArticleImpression(String articleUrl) {
    final url = articleUrl.trim();
    if (url.isEmpty || !_started) return;
    if (!_impressedArticleUrls.add(url)) return;

    _enqueue(
      TelemetryEvent(
        type: TelemetryEventType.articleImpression,
        articleUrl: url,
        clientTs: DateTime.now().toUtc(),
      ),
    );
  }

  /// Plan A funnel milestones (stored as clicks with [app://funnel/] URLs).
  void recordFunnelMilestone(String milestone) {
    final name = milestone.trim();
    if (name.isEmpty || !_started) return;

    _enqueue(
      TelemetryEvent(
        type: TelemetryEventType.articleClick,
        articleUrl: 'app://funnel/$name',
        clientTs: DateTime.now().toUtc(),
        metadata: <String, dynamic>{'funnel_milestone': name},
      ),
    );
  }

  /// Fires when the user opens an article for deep reading.
  void recordArticleClick(String articleUrl) {
    final url = articleUrl.trim();
    if (url.isEmpty || !_started) return;

    _enqueue(
      TelemetryEvent(
        type: TelemetryEventType.articleClick,
        articleUrl: url,
        clientTs: DateTime.now().toUtc(),
      ),
    );
  }

  /// Starts measuring dwell for [articleUrl]; ends any prior open article first.
  void beginDwellSession(
    String articleUrl, {
    String? source,
    List<String> tags = const <String>[],
  }) {
    final url = articleUrl.trim();
    if (url.isEmpty || !_started) return;
    if (_activeDwellUrl == url) return;

    endDwellSession(reason: 'article_switch');
    _activeDwellUrl = url;
    _activeDwellStarted = DateTime.now();
    _activeDwellTags = List<String>.from(tags);
  }

  /// Ends the current dwell session and enqueues [dwell_time] if duration ≥ 1s.
  void endDwellSession({String? reason}) {
    final url = _activeDwellUrl;
    final started = _activeDwellStarted;
    final tags = List<String>.from(_activeDwellTags);
    _activeDwellUrl = null;
    _activeDwellStarted = null;
    _activeDwellTags = <String>[];
    if (url == null || started == null || !_started) return;

    final seconds = DateTime.now().difference(started).inSeconds;
    if (seconds < 1) return;

    FeedPersonalizationService.instance.recordDwell(tags, seconds);

    final meta = <String, dynamic>{};
    if (reason != null && reason.isNotEmpty) {
      meta['end_reason'] = reason;
    }

    _enqueue(
      TelemetryEvent(
        type: TelemetryEventType.dwellTime,
        articleUrl: url,
        clientTs: DateTime.now().toUtc(),
        dwellSeconds: seconds,
        metadata: meta,
      ),
    );
  }

  void _enqueue(TelemetryEvent event) {
    _queue.add(event);
    if (_queue.length >= _maxBatchSize) {
      scheduleFlush();
    }
  }

  /// Schedules a background flush; never blocks the caller.
  void scheduleFlush() {
    if (!_started || _queue.isEmpty || _flushInFlight) return;
    final batch = List<TelemetryEvent>.from(_queue);
    _queue.clear();
    _flushInFlight = true;
    unawaited(
      _flushBatch(batch).whenComplete(() {
        _flushInFlight = false;
        if (_queue.length >= _maxBatchSize) {
          scheduleFlush();
        }
      }),
    );
  }

  Future<void> _flushBatch(List<TelemetryEvent> batch) async {
    if (batch.isEmpty) return;

    final headers = NyusGuruApiConfig.apiHeaders(
      jsonContent: true,
      minimalResponse: true,
    );

    final payload = <String, dynamic>{
      'events': batch.map((e) => e.toJson()).toList(),
      if (_sessionId != null) 'session_id': _sessionId,
      'client_platform': defaultTargetPlatform.name,
    };

    try {
      final response = await http
          .post(
            Uri.parse(NyusGuruApiConfig.logUserTelemetryRpcUrl),
            headers: headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      }

      if (kDebugMode) {
        debugPrint(
          'UserInteractionLogger flush failed: '
          '${response.statusCode} ${response.body}',
        );
      }
      _requeueFailed(batch);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('UserInteractionLogger flush error: $e\n$st');
      }
      _requeueFailed(batch);
    }
  }

  void _requeueFailed(List<TelemetryEvent> failed) {
    final combined = <TelemetryEvent>[...failed, ..._queue];
    if (combined.length > _maxRequeueAfterFailure) {
      _queue
        ..clear()
        ..addAll(combined.sublist(combined.length - _maxRequeueAfterFailure));
    } else {
      _queue
        ..clear()
        ..addAll(combined);
    }
  }
}
