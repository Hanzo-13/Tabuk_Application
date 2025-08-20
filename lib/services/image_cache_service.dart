import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class ImageCacheService {
  static const _boxName = 'imageCache';

  /// Initializes Hive for image caching
  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    Hive.init(dir.path);
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<Uint8List>(_boxName);
    }
  }

  /// Gets image bytes from Hive cache or downloads it
  static Future<Uint8List?> getImage(String url) async {
    try {
      final box = await Hive.openBox<Uint8List>(_boxName);

      if (box.containsKey(url)) {
        return box.get(url);
      }

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        await box.put(url, bytes);
        return bytes;
      }
    } catch (e) {
      debugPrint('ImageCacheService error: $e');
    }
    return null;
  }

  /// Clears all cached images
  static Future<void> clearCache() async {
    final box = await Hive.openBox<Uint8List>(_boxName);
    await box.clear();
  }
}
