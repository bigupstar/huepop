import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/artwork.dart';

class ArtworkCacheService {
  const ArtworkCacheService();

  Future<Uint8List> loadBytes(Artwork artwork) async {
    final dir = await getApplicationSupportDirectory();
    final cacheDir = Directory('${dir.path}${Platform.pathSeparator}huepop_artwork_cache');
    if (!await cacheDir.exists()) await cacheDir.create(recursive: true);

    final safeName = artwork.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final file = File('${cacheDir.path}${Platform.pathSeparator}$safeName.png');
    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      if (bytes.isNotEmpty) return bytes;
    }

    final response = await http.get(Uri.parse(artwork.imageUrl)).timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Artwork image returned HTTP ${response.statusCode}.');
    }
    final bytes = response.bodyBytes;
    if (bytes.isEmpty) throw StateError('Artwork image download was empty.');
    await file.writeAsBytes(bytes, flush: true);
    return bytes;
  }
}
