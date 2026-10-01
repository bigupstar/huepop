import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/artwork.dart';
import '../models/editor_models.dart';
import '../services/huepop_config.dart';

enum OfflineDownloadResult {
  downloaded,
  alreadyDownloaded,
  premiumRequired,
  limitReached,
  failed,
}

class HuePopAppState extends ChangeNotifier {
  static const String _premiumKey = 'huepop.premium.preview';
  static const String _favoritesKey = 'huepop.favorites';
  static const String _recentColorsKey = 'huepop.recentColors';
  static const String _favoriteColorsKey = 'huepop.favoriteColors';
  static const String _offlineIdsKey = 'huepop.offline.ids';
  static const String _catalogCacheKey = 'huepop.catalog.cache.v2';

  static const int maxOfflineDownloads = 5;

  SharedPreferences? _prefs;
  Directory? _offlineDirectory;

  bool initialized = false;
  bool premiumUnlocked = false;
  bool catalogRefreshing = false;
  String? catalogError;
  DateTime? catalogLastUpdated;
  final List<Artwork> artworks = <Artwork>[];
  final Set<String> favorites = <String>{};
  final List<int> recentColors = <int>[];
  final Set<int> favoriteColors = <int>{};
  final Set<String> offlineArtworkIds = <String>{};
  final Map<String, String> _offlinePaths = <String, String>{};
  int offlineStorageBytes = 0;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    premiumUnlocked = _prefs!.getBool(_premiumKey) ?? false;
    favorites
      ..clear()
      ..addAll(_prefs!.getStringList(_favoritesKey) ?? const <String>[]);
    recentColors
      ..clear()
      ..addAll((_prefs!.getStringList(_recentColorsKey) ?? const <String>[])
          .map(int.tryParse)
          .whereType<int>());
    favoriteColors
      ..clear()
      ..addAll((_prefs!.getStringList(_favoriteColorsKey) ?? const <String>[])
          .map(int.tryParse)
          .whereType<int>());

    final support = await getApplicationSupportDirectory();
    _offlineDirectory = Directory('${support.path}${Platform.pathSeparator}huepop_offline');
    await _offlineDirectory!.create(recursive: true);

    offlineArtworkIds
      ..clear()
      ..addAll(_prefs!.getStringList(_offlineIdsKey) ?? const <String>[]);

    _loadCachedCatalog();
    await _reconcileOfflineFiles();

    initialized = true;
    notifyListeners();
    await refreshCatalog(silent: true);
  }

  void _loadCachedCatalog() {
    final cached = _prefs?.getString(_catalogCacheKey);
    if (cached == null || cached.isEmpty) return;
    try {
      final decoded = jsonDecode(cached);
      if (decoded is! List) return;
      artworks
        ..clear()
        ..addAll(decoded.whereType<Map>().map((item) => Artwork.fromJson(
              Map<String, dynamic>.from(item),
              catalogUri: HuePopConfig.catalogUri,
            )));
    } catch (_) {
      // A damaged cache is ignored; the cloud refresh below can replace it.
    }
  }

  Future<bool> refreshCatalog({bool silent = false}) async {
    if (catalogRefreshing) return false;
    catalogRefreshing = true;
    catalogError = null;
    if (!silent) notifyListeners();
    try {
      final response = await http.get(HuePopConfig.catalogUri).timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('Color Cloud returned HTTP ${response.statusCode}.');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! List) throw const FormatException('Color Cloud catalog is not a list.');
      final loaded = decoded
          .whereType<Map>()
          .map((item) => Artwork.fromJson(Map<String, dynamic>.from(item), catalogUri: HuePopConfig.catalogUri))
          .where((artwork) => artwork.imageUrl.isNotEmpty)
          .toList();
      if (loaded.isEmpty) throw const FormatException('Color Cloud returned no artwork.');
      artworks
        ..clear()
        ..addAll(loaded);
      await _prefs?.setString(_catalogCacheKey, response.body);
      catalogLastUpdated = DateTime.now();
      await _reconcileOfflineFiles();
      return true;
    } catch (e) {
      catalogError = '$e';
      return false;
    } finally {
      catalogRefreshing = false;
      notifyListeners();
    }
  }

  Artwork? get dailyChallenge {
    if (artworks.isEmpty) return null;
    final day = DateTime.now().difference(DateTime(2026, 1, 1)).inDays.abs();
    return artworks[day % artworks.length];
  }

  bool canOpen(Artwork artwork) => !artwork.isPremium || premiumUnlocked || isOffline(artwork.id);

  Future<void> setPremiumPreview(bool value) async {
    premiumUnlocked = value;
    await _prefs?.setBool(_premiumKey, value);
    notifyListeners();
  }

  Future<void> toggleFavorite(String artworkId) async {
    favorites.contains(artworkId) ? favorites.remove(artworkId) : favorites.add(artworkId);
    await _prefs?.setStringList(_favoritesKey, favorites.toList());
    notifyListeners();
  }

  Future<void> rememberColor(int colorValue) async {
    recentColors.remove(colorValue);
    recentColors.insert(0, colorValue);
    if (recentColors.length > 10) recentColors.removeRange(10, recentColors.length);
    await _prefs?.setStringList(_recentColorsKey, recentColors.map((value) => '$value').toList());
    notifyListeners();
  }

  Future<void> toggleFavoriteColor(int colorValue) async {
    favoriteColors.contains(colorValue) ? favoriteColors.remove(colorValue) : favoriteColors.add(colorValue);
    await _prefs?.setStringList(_favoriteColorsKey, favoriteColors.map((value) => '$value').toList());
    notifyListeners();
  }

  String _saveKey(String artworkId) => 'huepop.artwork.$artworkId';

  SavedArtworkState? savedState(String artworkId) {
    final encoded = _prefs?.getString(_saveKey(artworkId));
    if (encoded == null || encoded.isEmpty) return null;
    try {
      return SavedArtworkState.decode(encoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveArtwork(String artworkId, SavedArtworkState state) async {
    await _prefs?.setString(_saveKey(artworkId), state.encode());
    notifyListeners();
  }

  Future<void> clearArtwork(String artworkId) async {
    await _prefs?.remove(_saveKey(artworkId));
    notifyListeners();
  }

  bool hasProgress(String artworkId) => _prefs?.containsKey(_saveKey(artworkId)) ?? false;

  double progressFor(String artworkId) => savedState(artworkId)?.progress ?? 0;

  List<Artwork> get inProgress => artworks
      .where((artwork) => hasProgress(artwork.id) && progressFor(artwork.id) < .995)
      .toList();

  List<Artwork> get completed => artworks
      .where((artwork) => progressFor(artwork.id) >= .995)
      .toList();

  List<Artwork> get offlineArtworks => artworks
      .where((artwork) => offlineArtworkIds.contains(artwork.id))
      .toList();

  int get offlineCount => offlineArtworkIds.length;
  int get offlineSlotsRemaining => maxOfflineDownloads - offlineCount;
  bool get offlineLibraryFull => offlineCount >= maxOfflineDownloads;

  bool isOffline(String artworkId) => offlineArtworkIds.contains(artworkId) && _offlinePaths.containsKey(artworkId);

  String? offlinePathFor(String artworkId) => isOffline(artworkId) ? _offlinePaths[artworkId] : null;

  String _offlineFilePath(Artwork artwork) {
    final uri = Uri.tryParse(artwork.imageUrl);
    final last = uri?.pathSegments.isNotEmpty == true ? uri!.pathSegments.last : '';
    final extension = last.contains('.') ? last.split('.').last.toLowerCase() : 'png';
    return '${_offlineDirectory!.path}${Platform.pathSeparator}${artwork.id}.$extension';
  }

  Future<OfflineDownloadResult> downloadForOffline(Artwork artwork) async {
    if (!premiumUnlocked) return OfflineDownloadResult.premiumRequired;
    if (isOffline(artwork.id)) return OfflineDownloadResult.alreadyDownloaded;
    if (offlineLibraryFull) return OfflineDownloadResult.limitReached;
    if (_offlineDirectory == null) return OfflineDownloadResult.failed;

    try {
      final response = await http.get(Uri.parse(artwork.imageUrl)).timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300 || response.bodyBytes.isEmpty) {
        return OfflineDownloadResult.failed;
      }
      final path = _offlineFilePath(artwork);
      final file = File(path);
      await file.writeAsBytes(response.bodyBytes, flush: true);
      offlineArtworkIds.add(artwork.id);
      _offlinePaths[artwork.id] = path;
      await _prefs?.setStringList(_offlineIdsKey, offlineArtworkIds.toList());
      await _refreshOfflineStorageSize();
      notifyListeners();
      return OfflineDownloadResult.downloaded;
    } catch (_) {
      return OfflineDownloadResult.failed;
    }
  }

  Future<void> removeOffline(String artworkId) async {
    final path = _offlinePaths[artworkId];
    if (path != null) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
    offlineArtworkIds.remove(artworkId);
    _offlinePaths.remove(artworkId);
    await _prefs?.setStringList(_offlineIdsKey, offlineArtworkIds.toList());
    await _refreshOfflineStorageSize();
    notifyListeners();
  }

  Future<void> _reconcileOfflineFiles() async {
    if (_offlineDirectory == null) return;
    final byId = <String, Artwork>{for (final artwork in artworks) artwork.id: artwork};
    final valid = <String>{};
    _offlinePaths.clear();
    for (final id in offlineArtworkIds) {
      final artwork = byId[id];
      if (artwork == null) continue;
      final path = _offlineFilePath(artwork);
      if (await File(path).exists()) {
        valid.add(id);
        _offlinePaths[id] = path;
      }
    }
    offlineArtworkIds
      ..clear()
      ..addAll(valid);
    await _prefs?.setStringList(_offlineIdsKey, offlineArtworkIds.toList());
    await _refreshOfflineStorageSize();
  }

  Future<void> _refreshOfflineStorageSize() async {
    var total = 0;
    for (final path in _offlinePaths.values) {
      try {
        total += await File(path).length();
      } catch (_) {}
    }
    offlineStorageBytes = total;
  }

  String get formattedOfflineStorage {
    final bytes = offlineStorageBytes;
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }
}
