import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';

class RegionData {
  const RegionData({
    required this.width,
    required this.height,
    required this.sourceRgba,
    required this.regionIds,
    required this.regionSizes,
    required this.paintablePixelCount,
  });

  final int width;
  final int height;
  final Uint8List sourceRgba;
  final Int32List regionIds;
  final Int32List regionSizes;
  final int paintablePixelCount;

  int regionAtNormalized(double x, double y) {
    if (width <= 0 || height <= 0) return -1;
    final px = (x.clamp(0.0, 0.999999) * width).floor();
    final py = (y.clamp(0.0, 0.999999) * height).floor();
    return regionIds[(py * width) + px];
  }

  int sourceColorAtNormalized(double x, double y) {
    final px = (x.clamp(0.0, 0.999999) * width).floor();
    final py = (y.clamp(0.0, 0.999999) * height).floor();
    final i = ((py * width) + px) * 4;
    return (sourceRgba[i + 3] << 24) |
        (sourceRgba[i] << 16) |
        (sourceRgba[i + 1] << 8) |
        sourceRgba[i + 2];
  }
}

Future<RegionData> loadRegionDataFromBytes(Uint8List encodedBytes, {int boundaryThreshold = 105}) async {
  final codec = await ui.instantiateImageCodec(encodedBytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final rgbaData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (rgbaData == null) throw StateError('Unable to decode artwork pixels.');
  final rgba = Uint8List.fromList(rgbaData.buffer.asUint8List());
  final result = await compute(_labelRegions, <String, Object>{
    'pixels': rgba,
    'width': image.width,
    'height': image.height,
    'threshold': boundaryThreshold,
  });
  image.dispose();
  codec.dispose();

  return RegionData(
    width: result['width']! as int,
    height: result['height']! as int,
    sourceRgba: rgba,
    regionIds: result['regionIds']! as Int32List,
    regionSizes: result['regionSizes']! as Int32List,
    paintablePixelCount: result['paintablePixelCount']! as int,
  );
}

Map<String, Object> _labelRegions(Map<String, Object> input) {
  final pixels = input['pixels']! as Uint8List;
  final width = input['width']! as int;
  final height = input['height']! as int;
  final threshold = input['threshold']! as int;
  final count = width * height;
  final ids = Int32List(count)..fillRange(0, count, -2);

  bool isBoundary(int index) {
    final p = index * 4;
    final a = pixels[p + 3];
    if (a < 30) return false;
    final r = pixels[p];
    final g = pixels[p + 1];
    final b = pixels[p + 2];
    final luminance = ((r * 299) + (g * 587) + (b * 114)) ~/ 1000;
    return luminance < threshold;
  }

  for (var i = 0; i < count; i++) {
    if (isBoundary(i)) ids[i] = -1;
  }

  final sizes = <int>[];
  final queue = Int32List(count);
  var region = 0;
  var paintable = 0;

  for (var start = 0; start < count; start++) {
    if (ids[start] != -2) continue;
    var head = 0;
    var tail = 0;
    queue[tail++] = start;
    ids[start] = region;
    var size = 0;

    while (head < tail) {
      final current = queue[head++];
      size++;
      final x = current % width;
      final y = current ~/ width;

      void add(int next) {
        if (ids[next] == -2) {
          ids[next] = region;
          queue[tail++] = next;
        }
      }

      if (x > 0) add(current - 1);
      if (x + 1 < width) add(current + 1);
      if (y > 0) add(current - width);
      if (y + 1 < height) add(current + width);
    }

    sizes.add(size);
    paintable += size;
    region++;
  }

  return <String, Object>{
    'width': width,
    'height': height,
    'regionIds': ids,
    'regionSizes': Int32List.fromList(sizes),
    'paintablePixelCount': paintable,
  };
}

Future<ui.Image> rgbaToImage(Uint8List rgba, int width, int height) {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(rgba, width, height, ui.PixelFormat.rgba8888, completer.complete);
  return completer.future;
}
