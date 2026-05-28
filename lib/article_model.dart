class Article {
  const Article({
    required this.url,
    required this.title,
    required this.titleHindi,
    required this.summary,
    required this.summaryHindi,
    this.deepAnalysis,
    this.imageUrl,
    this.animeImageUrl,
    required this.tags,
    required this.harvestedAt,
  });

  final String url;
  final String title;
  final String titleHindi;
  final String summary;
  final String summaryHindi;

  /// ~250-word contextual brief from engine `deep_analyzer.py` (Google + OpenAI).
  final String? deepAnalysis;
  final String? imageUrl;

  /// Anime-style illustration cached by Edge Function (`ensure-anime-image`).
  final String? animeImageUrl;
  final List<String> tags;
  final DateTime harvestedAt;

  factory Article.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'];
    final rawAnimeUrl = json['anime_image_url'] ?? json['animeImageUrl'];
    final parsedAnimeUrl = switch (rawAnimeUrl) {
      null || '' => '',
      final String s => s.trim(),
      final Object o =>
        (o.toString().trim().isEmpty || o.toString() == 'null')
            ? ''
            : o.toString().trim(),
    };

    final rawImageUrl = json['image_url'] ?? json['imageUrl'];
    final parsedImageUrl = switch (rawImageUrl) {
      null || '' => '',
      final String s => s.trim(),
      final Object o =>
        (o.toString().trim().isEmpty || o.toString() == 'null')
            ? ''
            : o.toString().trim(),
    };
    final parsedTags = rawTags is List
        ? rawTags.whereType<Object?>().map((tag) => '$tag').toList()
        : const <String>[];

    final rawDeep = json['deep_analysis'] ?? json['deepAnalysis'];
    final parsedDeep = switch (rawDeep) {
      null || '' => '',
      final String s => s.trim(),
      final Object o =>
        (o.toString().trim().isEmpty || o.toString() == 'null')
            ? ''
            : o.toString().trim(),
    };

    return Article(
      url: (json['url'] ?? '') as String,
      title: (json['title'] ?? '') as String,
      titleHindi: (json['title_hindi'] ?? '') as String,
      summary: (json['summary'] ?? '') as String,
      summaryHindi: (json['summary_hindi'] ?? '') as String,
      deepAnalysis: parsedDeep.isEmpty ? null : parsedDeep,
      imageUrl: parsedImageUrl.isEmpty ? null : parsedImageUrl,
      animeImageUrl: parsedAnimeUrl.isEmpty ? null : parsedAnimeUrl,
      tags: parsedTags,
      harvestedAt:
          DateTime.tryParse('${json['harvested_at']}') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'url': url,
    'title': title,
    'title_hindi': titleHindi,
    'summary': summary,
    'summary_hindi': summaryHindi,
    'deep_analysis': deepAnalysis,
    'image_url': imageUrl,
    'anime_image_url': animeImageUrl,
    'tags': tags,
    'harvested_at': harvestedAt.toUtc().toIso8601String(),
  };
}
