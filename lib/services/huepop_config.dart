class HuePopConfig {
  const HuePopConfig._();

  static const String webBaseUrl = 'https://bigupstar.com/huepop/';
  static const String catalogUrl = 'https://bigupstar.com/huepop/artwork/artworks.json';
  static const String colorCloudLabel = 'Huepop Color Cloud';

  static const String premiumApiBaseUrl = 'https://pay.bigupstar.com/huepop/api/';

  static Uri get catalogUri => Uri.parse(catalogUrl);
  static Uri get premiumApiUri => Uri.parse(premiumApiBaseUrl);
  static Uri web(String relativePath) => Uri.parse(webBaseUrl).resolve(relativePath);
  static Uri premiumApi(String endpoint) => premiumApiUri.resolve(endpoint);
}
