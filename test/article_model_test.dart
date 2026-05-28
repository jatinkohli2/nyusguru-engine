import 'package:flutter_test/flutter_test.dart';
import 'package:nyusguru_app/article_model.dart';

void main() {
  test('Article.fromJson parses deep_analysis', () {
    final article = Article.fromJson(<String, dynamic>{
      'url': 'https://example.com/a',
      'title': 'Title',
      'title_hindi': 'शीर्षक',
      'summary': 'EN',
      'summary_hindi': 'HI',
      'deep_analysis': 'Contextual deep brief about the story.',
      'tags': <String>['Politics'],
      'harvested_at': '2026-05-28T10:00:00Z',
    });

    expect(article.deepAnalysis, 'Contextual deep brief about the story.');
  });

  test('Article.fromJson omits empty deep_analysis', () {
    final article = Article.fromJson(<String, dynamic>{
      'url': 'https://example.com/b',
      'title': 'Title',
      'title_hindi': '',
      'summary': 'EN',
      'summary_hindi': '',
      'deep_analysis': '',
      'tags': <String>[],
      'harvested_at': '2026-05-28T10:00:00Z',
    });

    expect(article.deepAnalysis, isNull);
  });
}
