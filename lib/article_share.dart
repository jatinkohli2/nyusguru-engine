import 'package:flutter/foundation.dart'
    show TargetPlatform, debugPrint, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'article_model.dart';

/// Popover anchor for iPad/macOS only — invalid rects break sharing on some devices.
Rect? validShareOrigin(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return null;
  final size = box.size;
  if (!size.isFinite || size.width < 8 || size.height < 8) return null;
  final topLeft = box.localToGlobal(Offset.zero);
  if (!topLeft.dx.isFinite || !topLeft.dy.isFinite) return null;
  final rect = topLeft & size;
  if (rect.isEmpty ||
      !rect.left.isFinite ||
      !rect.top.isFinite ||
      !rect.width.isFinite ||
      !rect.height.isFinite) {
    return null;
  }
  return rect;
}

Future<void> _tryClipboardFallback(
  BuildContext context, {
  required String text,
  required bool isHindi,
}) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        isHindi
            ? 'शेयर उपलब्ध नहीं। टेक्स्ट क्लिपबोर्ड पर कॉपी हो गया — किसी भी ऐप में चिपकाएँ।'
            : 'Share unavailable. Text copied — paste it into any app.',
      ),
    ),
  );
}

Future<void> _invokeShare(
  BuildContext context, {
  required String text,
  required String subject,
  required bool isHindi,
}) async {
  final payload = text.trim();
  if (payload.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isHindi
                ? 'शेयर करने के लिए कोई सामग्री नहीं है।'
                : 'Nothing to share.',
          ),
        ),
      );
    }
    return;
  }

  final sub = subject.trim().isEmpty ? null : subject.trim();

  Future<bool> attempt(ShareParams params) async {
    try {
      await SharePlus.instance.share(params);
      return true;
    } catch (e, st) {
      debugPrint('share_plus: $e\n$st');
      return false;
    }
  }

  if (!context.mounted) return;

  final origin = validShareOrigin(context);
  final preferPopover =
      !kIsWeb &&
      origin != null &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  // iPad/macOS: popover anchor first; Android/Desktop/Web: plain share avoids rect bugs.
  if (preferPopover) {
    if (await attempt(
      ShareParams(
        text: payload,
        subject: sub,
        title: sub,
        sharePositionOrigin: origin,
      ),
    )) {
      return;
    }
    if (!context.mounted) return;
  }

  if (await attempt(ShareParams(text: payload, subject: sub, title: sub))) {
    return;
  }

  if (!context.mounted) return;
  await _tryClipboardFallback(context, text: payload, isHindi: isHindi);
}

/// Opens the OS share sheet (all apps that accept text/links).
Future<void> shareNyusGuruArticle(
  BuildContext context, {
  required Article article,
  required bool isHindi,
}) async {
  final url = article.url.trim();
  final title = isHindi && article.titleHindi.trim().isNotEmpty
      ? article.titleHindi.trim()
      : article.title.trim();

  if (url.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isHindi
                ? 'शेयर करने के लिए कोई लिंक नहीं है।'
                : 'Nothing to share — missing link.',
          ),
        ),
      );
    }
    return;
  }

  var summaryBody = isHindi
      ? article.summaryHindi.trim()
      : article.summary.trim();
  if (summaryBody.length > 420) {
    summaryBody = '${summaryBody.substring(0, 417)}…';
  }

  final buffer = StringBuffer(title);
  if (summaryBody.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln()
      ..write(summaryBody);
  }
  buffer
    ..writeln()
    ..writeln()
    ..write(url);

  await _invokeShare(
    context,
    text: buffer.toString(),
    subject: title,
    isHindi: isHindi,
  );
}

/// Share invite text when no article is selected (main feed screen).
Future<void> shareNyusGuruApp(
  BuildContext context, {
  required bool isHindi,
}) async {
  final text = isHindi
      ? 'NyusGuru — अंग्रेज़ी और हिंदी में समाचार सार। इस ऐप को आज़माएँ!'
      : 'NyusGuru — bilingual news summaries in English & Hindi. Try the app!';

  await _invokeShare(
    context,
    text: text,
    subject: 'NyusGuru',
    isHindi: isHindi,
  );
}
