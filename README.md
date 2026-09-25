# HuePop

HuePop is a Flutter coloring studio for Android and iOS with smart region fill, brushes, palettes, undo/redo, zoom/pan, autosave, remote artwork catalogs, and lifetime premium content.

## Production content root

- Web root: `https://bigupstar.com/huepop/`
- Artwork directory: `https://bigupstar.com/huepop/artwork/`
- Catalog: `https://bigupstar.com/huepop/artwork/artworks.json`

The catalog is dynamic. Adding an artwork to `artworks.json` makes it available to the app without a new app build.

## Premium

HuePop Lifetime Premium is designed as a one-time non-consumable in-app purchase. Premium unlocks all catalog items with `premium: true`, plus Glitter, Stickers, and future premium additions.

Placeholder product IDs are configured in `lib/services/huepop_config.dart` and must be registered in App Store Connect / Google Play before release.

See `BUILD_NOTES.txt` and `server/artwork/README_UPLOAD.txt`.
