import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Registered hostname for [articleUrl], without leading `www.`.
String? articleSourceHost(String? rawUrl) {
  final u = rawUrl?.trim() ?? '';
  if (u.isEmpty) return null;
  final uri = Uri.tryParse(u);
  if (uri == null || !uri.hasAuthority) return null;
  var host = uri.host.toLowerCase();
  if (host.startsWith('www.')) {
    host = host.substring(4);
  }
  return host.isEmpty ? null : host;
}

/// Remote favicon URL for news source attribution (domain-only; no article fetch).
String? articleSourceFaviconUrl(String? rawUrl) {
  final host = articleSourceHost(rawUrl);
  if (host == null) return null;
  return Uri.https('www.google.com', '/s2/favicons', <String, String>{
    'domain': host,
    'sz': '64',
  }).toString();
}

/// Small site icon derived from the article’s link host.
class ArticleSourceFavicon extends StatelessWidget {
  const ArticleSourceFavicon({
    super.key,
    required this.articleUrl,
    this.size = 20,
  });

  final String articleUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final host = articleSourceHost(articleUrl);
    final favUrl = articleSourceFaviconUrl(articleUrl);
    final radius = BorderRadius.circular(size * 0.22);
    final dpr = MediaQuery.devicePixelRatioOf(context);

    final fallback = _FallbackSourceIcon(theme: theme, size: size);

    final inner = favUrl == null
        ? fallback
        : ClipRRect(
            borderRadius: radius,
            child: SizedBox(
              width: size,
              height: size,
              child: ColoredBox(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.35,
                ),
                child: CachedNetworkImage(
                  imageUrl: favUrl,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  fadeInDuration: Duration.zero,
                  fadeOutDuration: Duration.zero,
                  memCacheWidth: (size * dpr).round(),
                  errorWidget: (context, url, error) => fallback,
                ),
              ),
            ),
          );

    return Tooltip(
      message: host ?? 'Unknown source',
      child: Semantics(
        label: host == null ? 'News source' : 'News source: $host',
        child: SizedBox(width: size, height: size, child: inner),
      ),
    );
  }
}

class _FallbackSourceIcon extends StatelessWidget {
  const _FallbackSourceIcon({required this.theme, required this.size});

  final ThemeData theme;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(size * 0.22),
        ),
        child: Center(
          child: Icon(
            Icons.public_rounded,
            size: size * 0.62,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
