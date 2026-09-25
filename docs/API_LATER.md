# HuePop API — planned later

The Flutter app is intentionally **local-first** for this build. No PHP/API folder is required yet.

Production web root:

`https://bigupstar.com/huepop/`

The app keeps this value in `lib/services/huepop_config.dart`.

When the server phase begins, suggested endpoints are:

- `api/artworks.php` — artwork catalog, collection, labels, URLs, dimensions
- `api/collections.php` — collection metadata
- `api/entitlements.php` — optional server-side entitlement mirror
- `api/daily.php` — optional daily challenge selection
- `artwork/{collection}/{id}/page.png` — downloadable 2000×2000 coloring source
- `artwork/{collection}/{id}/thumb.jpg` — lightweight library thumbnail

The Flutter repository can then switch `remoteCatalogEnabled` to `true` and use the remote catalog while retaining bundled starter artwork as an offline fallback.

Apple/Google in-app purchases are separate from the HuePop web API. Live purchases require product IDs created in App Store Connect and Google Play Console. The current project includes premium/free UI and a developer entitlement preview so the product can be built before those IDs exist.
