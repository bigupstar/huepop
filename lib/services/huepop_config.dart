class HuePopConfig {
  const HuePopConfig._();

  static const String webBaseUrl = 'https://bigupstar.com/huepop/';
  static const String catalogUrl = 'https://bigupstar.com/huepop/artwork/artworks.json';
  static const String colorCloudLabel = 'Huepop Color Cloud';

  static Uri get catalogUri => Uri.parse(catalogUrl);
  static Uri web(String relativePath) => Uri.parse(webBaseUrl).resolve(relativePath);
}
