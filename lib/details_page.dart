import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // For the 'Read Original' button

class DetailsPage extends StatelessWidget {
  final Map article;

  const DetailsPage({super.key, required this.article});

  static const String _placeholderImage = 'https://via.placeholder.com/400x200';

  String _resolvedImageUrl() {
    final raw = article['image_url'];
    if (raw == null) return _placeholderImage;
    final s = raw.toString().trim();
    if (s.isEmpty) return _placeholderImage;
    return s;
  }

  // Helper to open the source URL
  Future<void> _launchUrl() async {
    final Uri url = Uri.parse(article['url'] ?? '');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(article['category'] ?? 'News Details')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Full Image
            CachedNetworkImage(
              imageUrl: _resolvedImageUrl(),
              width: double.infinity,
              height: 250,
              fit: BoxFit.cover,
              fadeInDuration: Duration.zero,
              fadeOutDuration: Duration.zero,
              progressIndicatorBuilder: (context, _, progress) => Container(
                height: 250,
                color: Colors.grey.shade200,
                alignment: Alignment.center,
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: progress.progress,
                  ),
                ),
              ),
              errorWidget: (context, url, error) {
                return CachedNetworkImage(
                  imageUrl: _placeholderImage,
                  width: double.infinity,
                  height: 250,
                  fit: BoxFit.cover,
                  fadeInDuration: Duration.zero,
                  fadeOutDuration: Duration.zero,
                  errorWidget: (context, url2, error2) => Container(
                    height: 250,
                    color: Colors.grey.shade300,
                    alignment: Alignment.center,
                    child: const Icon(Icons.image_not_supported_outlined),
                  ),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 2. Title
                  Text(
                    article['title'] ?? '',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // 3. Long Summary (Hindi)
                  Text(
                    article['summary_hindi'] ?? '',
                    textAlign: TextAlign.justify,
                    style: const TextStyle(fontSize: 18, color: Colors.black87),
                  ),
                  const SizedBox(height: 30),
                  // 4. Read Original Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _launchUrl,
                      icon: const Icon(Icons.launch),
                      label: const Text("Read Original Article"),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
