# HuePop 0.2.2 - Color Cloud + Premium Creative Tools

This build keeps HuePop tablet-first while supporting phones and offline coloring.

## Artwork source
HuePop loads its live catalog from the HuePop Color Cloud. Artwork images are remote and are not bundled in the app.

The Profile screen intentionally displays only:
- Artwork Refresh
- Huepop Color Cloud

The production catalog URL remains internal to app configuration.

## Premium features in this build
- Premium artwork access based on the catalog `premium` flag
- Up to 5 offline artwork downloads
- Glitter brush
- Glitter fill style
- Stickers

Free users can see Glitter and Stickers with lock indicators. Attempting to use either displays the Premium prompt.

## Branding
- `assets/app-icon.png` is the launcher/store icon source
- `assets/brand-image.png` is used in HuePop branding and splash/header UI

## Local build
```powershell
flutter clean
flutter pub get
flutter analyze
flutter build apk --debug
```
