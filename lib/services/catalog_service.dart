import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/artwork.dart';
import 'huepop_config.dart';

class CatalogService {
  const CatalogService();

  Future<List<Artwork>> loadCatalog() async {
    final manifestUri = Uri.parse(HuePopConfig.artworkManifestUrl);
    final response = await http.get(manifestUri).timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Artwork catalog returned HTTP ${response.statusCode}.');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final List<dynamic> records;
    if (decoded is List) {
      records = decoded;
    } else if (decoded is Map<String, dynamic> && decoded['artworks'] is List) {
      records = decoded['artworks'] as List<dynamic>;
    } else {
      throw const FormatException('artworks.json must be a JSON array or contain an "artworks" array.');
    }

    final artworks = records
        .whereType<Map>()
        .map((item) => Artwork.fromJson(Map<String, dynamic>.from(item), manifestUri: manifestUri))
        .where((artwork) => artwork.id.isNotEmpty && artwork.imageUrl.isNotEmpty)
        .toList()
      ..sort((a, b) {
        final order = a.sortOrder.compareTo(b.sortOrder);
        return order != 0 ? order : a.title.compareTo(b.title);
      });

    if (artworks.isEmpty) {
      throw const FormatException('The artwork catalog contains no usable artworks.');
    }
    return artworks;
  }
}
