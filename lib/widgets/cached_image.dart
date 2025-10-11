import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class ImageCacheService {
  static Future<File> _downloadImage(String url, String filename) async {
    final response = await http.get(Uri.parse(url));
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(response.bodyBytes);
    return file;
  }

  static Future<String> getImagePath(String url) async {
    if (kIsWeb) {
      // On web, return the URL directly; use browser cache
      return url;
    }
    final filename = url.split('/').last; // crude filename generator
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$filename');

    if (await file.exists()) {
      return file.path; // already downloaded
    } else {
      final downloaded = await _downloadImage(url, filename);
      return downloaded.path;
    }
  }
}


class CachedImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final WidgetBuilder placeholderBuilder;
  final Widget Function(BuildContext, Object, StackTrace?) errorBuilder;

  const CachedImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    required this.placeholderBuilder,
    required this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: ImageCacheService.getImagePath(imageUrl),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return placeholderBuilder(context);
        }
        if (snapshot.hasError) {
          return errorBuilder(context, snapshot.error!, snapshot.stackTrace);
        }
        if (snapshot.hasData) {
          final pathOrUrl = snapshot.data!;
          if (kIsWeb) {
            return Image.network(
              pathOrUrl,
              fit: fit,
              width: double.infinity,
              height: double.infinity,
            );
          } else {
            return Image.file(
              File(pathOrUrl),
              fit: fit,
              width: double.infinity,
              height: double.infinity,
            );
          }
        }
        return errorBuilder(context, 'Unknown state', null);
      },
    );
  }
}
