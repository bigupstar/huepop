# HuePop 0.2.0 Mobile + Offline Test Checklist

## Phone layouts
- Test at least one small Android phone emulator (roughly 360x800 logical pixels).
- Test at least one iPhone simulator.
- Confirm all six bottom navigation items remain tappable and readable.
- Confirm Daily Challenge stacks vertically on narrow screens.
- Confirm Library grids do not overflow.
- Confirm editor title and app bar do not overflow; Show Original and Reset Zoom are available in the overflow menu on phones.
- Confirm pinch zoom, Pan tool, brush tools and bottom color controls remain usable.

## Tablet layouts
- Confirm tablets use the left NavigationRail.
- Confirm artwork grids use the additional width cleanly.
- Confirm editor switches to the desktop/tablet tool rail at wide widths.

## Offline downloads
- With Developer premium preview OFF, tap a download icon and confirm the Premium message appears.
- Turn Developer premium preview ON.
- Download 5 different pages and verify Downloads shows 5 / 5.
- Try to download a sixth page and confirm Offline Library Full appears.
- Open each downloaded page from Downloads and color it.
- Remove one downloaded page and verify the slot becomes available again.
- Verify removing a download does not remove saved coloring progress from My Art.
- Disable Developer premium preview after downloading premium artwork and confirm already-downloaded pages can still be opened for finishing.
- Relaunch the app and confirm downloaded pages persist.

## Notes
The starter catalog is currently bundled in the app. The Download action copies a source page into HuePop private application storage. The same storage path is ready to receive actual downloaded bytes when the remote catalog/API is enabled later.
