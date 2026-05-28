import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'anime_illustration_service.dart';
import 'article_model.dart';

const Map<String, String> kArticleImageRequestHeaders = <String, String>{
  'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
  'User-Agent':
      'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Mobile Safari/537.36',
};

String? normalizeArticleImageUrl(String? raw, String articlePageUrl) {
  if (raw == null) return null;
  var t = raw.trim();
  if (t.isEmpty || t == 'null' || t == 'none') return null;
  if (t.startsWith('data:')) return t;
  if (t.startsWith('//')) {
    return 'https:$t';
  }
  final parsed = Uri.tryParse(t);
  if (parsed == null) return null;
  if (parsed.hasScheme) {
    if (parsed.scheme == 'http' || parsed.scheme == 'https') return t;
    return null;
  }
  if (t.startsWith('/')) {
    final base = Uri.tryParse(articlePageUrl);
    if (base != null && base.hasScheme && base.hasAuthority) {
      return base.resolve(t).toString();
    }
  }
  return null;
}

/// Stock thumbnail only when the API sends no `image_url` (no blocking HTTP).
String articlePicsumFallbackUrl(Article article) {
  final seed = '${article.url.hashCode.abs()}';
  return 'https://picsum.photos/seed/$seed/800/480';
}

/// Shows publisher/anime/picsum without waiting on slow AnimeGAN requests.
class ArticleNetworkImage extends StatefulWidget {
  const ArticleNetworkImage({
    super.key,
    required this.article,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.width,
    this.height,
    this.iconSize = 32,
  });

  final Article article;
  final BoxFit fit;
  final Alignment alignment;
  final double? width;
  final double? height;
  final double iconSize;

  @override
  State<ArticleNetworkImage> createState() => _ArticleNetworkImageState();
}

class _ArticleNetworkImageState extends State<ArticleNetworkImage> {
  List<String> _urls = <String>[];
  int _index = 0;
  bool _pendingAdvance = false;

  @override
  void initState() {
    super.initState();
    _applyImmediateUrls();
    _upgradeAnimeInBackground();
  }

  @override
  void didUpdateWidget(ArticleNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.article.url != widget.article.url ||
        oldWidget.article.imageUrl != widget.article.imageUrl ||
        oldWidget.article.animeImageUrl != widget.article.animeImageUrl) {
      _urls = <String>[];
      _index = 0;
      _pendingAdvance = false;
      _applyImmediateUrls();
      _upgradeAnimeInBackground();
    }
  }

  void _applyImmediateUrls() {
    final anime = normalizeArticleImageUrl(
      widget.article.animeImageUrl,
      widget.article.url,
    );
    final src = normalizeArticleImageUrl(
      widget.article.imageUrl,
      widget.article.url,
    );

    final next = <String>[
      if (anime != null && anime.isNotEmpty) anime,
      if (src != null && src.isNotEmpty) src,
    ];

    if (next.isEmpty) {
      next.add(articlePicsumFallbackUrl(widget.article));
    }

    setState(() {
      _urls = next.toSet().toList();
      _index = 0;
    });
  }

  Future<void> _upgradeAnimeInBackground() async {
    final anime = normalizeArticleImageUrl(
      widget.article.animeImageUrl,
      widget.article.url,
    );
    final src = normalizeArticleImageUrl(
      widget.article.imageUrl,
      widget.article.url,
    );

    if (anime != null || src == null || src.isEmpty) return;

    final upgraded = await AnimeIllustrationService.fetchAnimeIllustration(
      articleUrl: widget.article.url,
      sourceImageUrl: src,
    );

    if (!mounted || upgraded == null || upgraded.isEmpty) return;

    setState(() {
      if (!_urls.contains(upgraded)) {
        _urls = <String>[upgraded, ..._urls];
      }
      _index = 0;
    });
  }

  void _scheduleTryNextUrl() {
    if (_index >= _urls.length - 1 || _pendingAdvance) return;
    _pendingAdvance = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingAdvance = false;
      if (!mounted) return;
      setState(() => _index += 1);
    });
  }

  /// [ResizeImage] applies both dimensions as an exact decode size and skews aspect
  /// ratio. Pass only width **or** height so decoding keeps proportions; layout
  /// [BoxFit] then fills the target box without stretching.
  (int?, int?) _decodeMemCacheSize(double devicePixelRatio) {
    final dpr = devicePixelRatio;
    if (widget.width != null && widget.height != null) {
      return ((widget.width! * dpr).round(), null);
    }
    if (widget.width != null) {
      return ((widget.width! * dpr).round(), null);
    }
    if (widget.height != null) {
      return (null, (widget.height! * dpr).round());
    }
    return (null, null);
  }

  Widget _buildDataUriImage(String url, int? cacheWidth, int? cacheHeight) {
    final uri = Uri.tryParse(url);
    final bytes = uri?.data?.contentAsBytes();
    if (bytes == null || bytes.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scheduleTryNextUrl();
      });
      return ColoredBox(
        color: Colors.grey.shade300,
        child: Icon(
          Icons.image_not_supported_outlined,
          size: widget.iconSize,
          color: Colors.grey.shade600,
        ),
      );
    }

    return Image.memory(
      bytes,
      key: ValueKey<String>('${widget.article.url}|$url'),
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      alignment: widget.alignment,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      errorBuilder: (context, error, stackTrace) {
        _scheduleTryNextUrl();
        if (_index >= _urls.length - 1 && !_pendingAdvance) {
          return _ArticleVisualFallback(
            article: widget.article,
            iconSize: widget.iconSize,
            width: widget.width,
            height: widget.height,
          );
        }
        return ColoredBox(
          color: Colors.grey.shade300,
          child: Icon(
            Icons.image_not_supported_outlined,
            size: widget.iconSize,
            color: Colors.grey.shade600,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_urls.isEmpty) {
      return _ArticleVisualFallback(
        article: widget.article,
        iconSize: widget.iconSize,
        width: widget.width,
        height: widget.height,
      );
    }

    final safeIndex = _index.clamp(0, _urls.length - 1);
    final url = _urls[safeIndex];

    final dpr = MediaQuery.devicePixelRatioOf(context);
    final decode = _decodeMemCacheSize(dpr);

    if (url.startsWith('data:')) {
      return _buildDataUriImage(url, decode.$1, decode.$2);
    }

    return CachedNetworkImage(
      imageUrl: url,
      cacheKey: '${widget.article.url}|$url',
      key: ValueKey<String>('${widget.article.url}|$url'),
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      alignment: widget.alignment,
      httpHeaders: kIsWeb ? null : kArticleImageRequestHeaders,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      memCacheWidth: decode.$1,
      memCacheHeight: decode.$2,
      progressIndicatorBuilder: (context, _, progress) {
        return ColoredBox(
          color: Colors.grey.shade200,
          child: Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: progress.progress,
              ),
            ),
          ),
        );
      },
      errorWidget: (context, _, _) {
        _scheduleTryNextUrl();
        if (_index >= _urls.length - 1 && !_pendingAdvance) {
          return _ArticleVisualFallback(
            article: widget.article,
            iconSize: widget.iconSize,
            width: widget.width,
            height: widget.height,
          );
        }
        return ColoredBox(
          color: Colors.grey.shade300,
          child: Icon(
            Icons.image_not_supported_outlined,
            size: widget.iconSize,
            color: Colors.grey.shade600,
          ),
        );
      },
    );
  }
}

class _ArticleVisualFallback extends StatelessWidget {
  const _ArticleVisualFallback({
    required this.article,
    required this.iconSize,
    this.width,
    this.height,
  });

  final Article article;
  final double iconSize;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final h = (article.url.hashCode.abs() % 360) / 360.0;
    final c1 = HSLColor.fromAHSL(1, h, 0.38, 0.52).toColor();
    final c2 = HSLColor.fromAHSL(1, (h + 0.08) % 1.0, 0.42, 0.38).toColor();

    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [c1, c2],
          ),
        ),
        child: Icon(
          Icons.article_outlined,
          size: iconSize,
          color: Colors.white.withValues(alpha: 0.92),
        ),
      ),
    );
  }
}
