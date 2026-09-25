import 'dart:io';

class HuePopConfig {
  const HuePopConfig._();

  static const String webBaseUrl = 'https://bigupstar.com/huepop/';
  static const String artworkBaseUrl = '${webBaseUrl}artwork/';
  static const String artworkManifestUrl = '${artworkBaseUrl}artworks.json';

  /// These are IN-APP PURCHASE product IDs, not the app bundle/package ID.
  /// Register these exact values in App Store Connect / Google Play before release,
  /// or change them here first and then register the changed values.
  static const String iosPremiumProductId = 'com.huepop.app.premium_lifetime';
  static const String androidPremiumProductId = 'huepop_premium_lifetime';

  static const String premiumFallbackPrice = r'$4.99';

  static String get premiumProductId {
    if (Platform.isIOS) return iosPremiumProductId;
    return androidPremiumProductId;
  }
}
