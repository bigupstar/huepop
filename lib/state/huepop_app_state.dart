import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/artwork.dart';
import '../models/editor_models.dart';
import '../services/artwork_cache_service.dart';
import '../services/catalog_service.dart';
import '../services/huepop_config.dart';

class HuePopAppState extends ChangeNotifier {
  static const String _premiumKey = 'huepop.premium.lifetime';
  static const String _favoritesKey = 'huepop.favorites';
  static const String _recentColorsKey = 'huepop.recentColors';
  static const String _favoriteColorsKey = 'huepop.favoriteColors';

  final CatalogService _catalogService = const CatalogService();
  final ArtworkCacheService _artworkCache = const ArtworkCacheService();
  final InAppPurchase _iap = InAppPurchase.instance;

  SharedPreferences? _prefs;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  bool initialized = false;
  bool premiumUnlocked = false;
  bool catalogLoading = true;
  String? catalogError;
  List<Artwork> artworks = <Artwork>[];

  bool storeAvailable = false;
  bool purchasePending = false;
  String? storeMessage;
  ProductDetails? premiumProduct;

  final Set<String> favorites = <String>{};
  final List<int> recentColors = <int>[];
  final Set<int> favoriteColors = <int>{};

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

    _purchaseSubscription = _iap.purchaseStream.listen(
      _handlePurchases,
      onError: (Object error) {
        storeMessage = 'Store error: $error';
        purchasePending = false;
        notifyListeners();
      },
    );

    initialized = true;
    notifyListeners();

    await Future.wait<void>([
      refreshCatalog(),
      _initializeStore(),
    ]);
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }

  Future<void> refreshCatalog() async {
    catalogLoading = true;
    catalogError = null;
    notifyListeners();
    try {
      artworks = await _catalogService.loadCatalog();
    } catch (error) {
      catalogError = '$error';
      artworks = <Artwork>[];
    } finally {
      catalogLoading = false;
      notifyListeners();
    }
  }

  Future<Uint8List> artworkBytes(Artwork artwork) => _artworkCache.loadBytes(artwork);

  Artwork? get dailyChallenge {
    if (artworks.isEmpty) return null;
    final free = artworks.where((artwork) => !artwork.isPremium).toList();
    final pool = free.isEmpty ? artworks : free;
    final day = DateTime.now().difference(DateTime(2026, 1, 1)).inDays.abs();
    return pool[day % pool.length];
  }

  bool canOpen(Artwork artwork) => !artwork.isPremium || premiumUnlocked;

  String get premiumPrice => premiumProduct?.price ?? HuePopConfig.premiumFallbackPrice;

  Future<void> _initializeStore() async {
    try {
      storeAvailable = await _iap.isAvailable();
      if (!storeAvailable) {
        storeMessage = 'The App Store / Play Store is not available on this device.';
        notifyListeners();
        return;
      }
      final response = await _iap.queryProductDetails(<String>{HuePopConfig.premiumProductId});
      if (response.error != null) storeMessage = response.error!.message;
      if (response.productDetails.isNotEmpty) {
        premiumProduct = response.productDetails.first;
        storeMessage = null;
      } else {
        storeMessage = 'Premium product is not registered in the store yet.';
      }
      notifyListeners();
    } catch (error) {
      storeMessage = 'Could not connect to the store: $error';
      notifyListeners();
    }
  }

  Future<void> buyLifetimePremium() async {
    if (premiumUnlocked || purchasePending) return;
    final product = premiumProduct;
    if (!storeAvailable || product == null) {
      storeMessage = 'Premium purchase is not available yet. Register ${HuePopConfig.premiumProductId} in the store first.';
      notifyListeners();
      return;
    }
    purchasePending = true;
    storeMessage = null;
    notifyListeners();
    try {
      final started = await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!started) {
        purchasePending = false;
        storeMessage = 'The purchase could not be started.';
        notifyListeners();
      }
    } catch (error) {
      purchasePending = false;
      storeMessage = 'Purchase error: $error';
      notifyListeners();
    }
  }

  Future<void> restorePremium() async {
    storeMessage = 'Checking previous purchases…';
    notifyListeners();
    try {
      await _iap.restorePurchases();
    } catch (error) {
      storeMessage = 'Restore error: $error';
      notifyListeners();
    }
  }

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != HuePopConfig.premiumProductId) continue;
      switch (purchase.status) {
        case PurchaseStatus.pending:
          purchasePending = true;
          storeMessage = 'Purchase pending…';
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _setPremiumUnlocked(true);
          purchasePending = false;
          storeMessage = purchase.status == PurchaseStatus.restored
              ? 'Lifetime Premium restored.'
              : 'Lifetime Premium unlocked.';
          break;
        case PurchaseStatus.error:
          purchasePending = false;
          storeMessage = purchase.error?.message ?? 'Purchase failed.';
          break;
        case PurchaseStatus.canceled:
          purchasePending = false;
          storeMessage = 'Purchase canceled.';
          break;
      }
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
    notifyListeners();
  }

  Future<void> _setPremiumUnlocked(bool value) async {
    premiumUnlocked = value;
    await _prefs?.setBool(_premiumKey, value);
    notifyListeners();
  }

  Future<void> setDeveloperPremiumPreview(bool value) async {
    if (!kDebugMode) return;
    await _setPremiumUnlocked(value);
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
      .where((artwork) => hasProgress(artwork.progressId) && progressFor(artwork.progressId) < .995)
      .toList();

  List<Artwork> get completed => artworks
      .where((artwork) => progressFor(artwork.progressId) >= .995)
      .toList();
}
