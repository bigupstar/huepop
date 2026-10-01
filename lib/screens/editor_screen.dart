import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/artwork.dart';
import '../models/editor_models.dart';
import '../state/huepop_app_state.dart';
import '../utils/region_engine.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.artwork, required this.appState, this.localArtworkPath});
  final Artwork artwork;
  final HuePopAppState appState;
  final String? localArtworkPath;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final GlobalKey _exportKey = GlobalKey();
  final TransformationController _transformController = TransformationController();

  RegionData? _regions;
  ui.Image? _fillImage;
  ui.Image? _outlineImage;
  bool _loading = true;
  String? _error;

  final List<EditAction> _actions = <EditAction>[];
  final List<EditAction> _redo = <EditAction>[];
  StrokeAction? _draftStroke;

  EditorTool _tool = EditorTool.fill;
  FillStyle _fillStyle = FillStyle.solid;
  BackgroundStyle _background = BackgroundStyle.white;
  Color _color = const Color(0xFFFF4FA3);
  double _brushSize = 22;
  double _opacity = 1;
  double _hardness = .85;
  bool _edgeProtection = true;
  bool _showReference = false;
  bool _saving = false;
  String _selectedSticker = '✨';
  int? _activeStrokeRegion;
  double _lastPressure = 1.0;

  static const List<Color> _quickColors = <Color>[
    Color(0xFF111111), Color(0xFFFFFFFF), Color(0xFFFF3B30), Color(0xFFFF9500),
    Color(0xFFFFCC00), Color(0xFF34C759), Color(0xFF00C7BE), Color(0xFF32ADE6),
    Color(0xFF007AFF), Color(0xFF5856D6), Color(0xFFAF52DE), Color(0xFFFF2D55),
    Color(0xFFFFB3C7), Color(0xFF8B5E3C), Color(0xFF6B7280), Color(0xFFB7F7E5),
  ];

  @override
  void initState() {
    super.initState();
    final saved = widget.appState.savedState(widget.artwork.id);
    if (saved != null) {
      _actions.addAll(saved.actions);
      _background = saved.background;
    }
    _loadArtwork();
  }

  @override
  void dispose() {
    _fillImage?.dispose();
    _outlineImage?.dispose();
    _transformController.dispose();
    super.dispose();
  }

  Future<RegionData> _loadRemoteRegionData() async {
    final response = await http.get(Uri.parse(widget.artwork.imageUrl)).timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300 || response.bodyBytes.isEmpty) {
      throw HttpException('Unable to download artwork (HTTP ${response.statusCode}).');
    }
    return loadRegionDataFromBytes(response.bodyBytes);
  }

  Future<void> _premiumFeatureDialog(String feature) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.workspace_premium_rounded, color: huePopPurple, size: 40),
        title: Text('$feature is a Premium feature'),
        content: Text('Unlock HuePop Lifetime Premium to use $feature, premium artwork collections, and offline downloads.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  void _selectTool(EditorTool tool) {
    final premiumTool = tool == EditorTool.glitter || tool == EditorTool.sticker;
    if (premiumTool && !widget.appState.premiumUnlocked) {
      _premiumFeatureDialog(tool == EditorTool.glitter ? 'Glitter' : 'Stickers');
      return;
    }
    setState(() => _tool = tool);
  }

  void _selectFillStyle(FillStyle style) {
    if (style == FillStyle.glitter && !widget.appState.premiumUnlocked) {
      _premiumFeatureDialog('Glitter');
      return;
    }
    setState(() {
      _fillStyle = style;
      _tool = EditorTool.fill;
    });
  }

  Future<void> _loadArtwork() async {
    try {
      final regions = widget.localArtworkPath != null
          ? await loadRegionDataFromBytes(await File(widget.localArtworkPath!).readAsBytes())
          : await _loadRemoteRegionData();
      final outlinePixels = Uint8List(regions.width * regions.height * 4);
      for (var i = 0; i < regions.width * regions.height; i++) {
        final p = i * 4;
        final r = regions.sourceRgba[p];
        final g = regions.sourceRgba[p + 1];
        final b = regions.sourceRgba[p + 2];
        final a = regions.sourceRgba[p + 3];
        final lum = ((r * 299) + (g * 587) + (b * 114)) ~/ 1000;
        final lineAlpha = a == 0 ? 0 : ((255 - lum) * 1.45).round().clamp(0, 255).toInt();
        outlinePixels[p] = 0;
        outlinePixels[p + 1] = 0;
        outlinePixels[p + 2] = 0;
        outlinePixels[p + 3] = lineAlpha;
      }
      final outline = await rgbaToImage(outlinePixels, regions.width, regions.height);
      if (!mounted) return;
      setState(() {
        _regions = regions;
        _outlineImage = outline;
      });
      await _rebuildFillImage();
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Map<int, FillAction> get _latestFills {
    final map = <int, FillAction>{};
    for (final action in _actions) {
      if (action is FillAction) map[action.regionId] = action;
    }
    return map;
  }

  double get _progress {
    final regions = _regions;
    if (regions == null || regions.paintablePixelCount == 0) return 0;
    var colored = 0;
    for (final id in _latestFills.keys) {
      if (id >= 0 && id < regions.regionSizes.length) colored += regions.regionSizes[id];
    }
    final fillProgress = colored / regions.paintablePixelCount;
    final strokeBonus = _actions.whereType<StrokeAction>().length * .005;
    return (fillProgress + strokeBonus).clamp(0.0, 1.0).toDouble();
  }

  Future<void> _rebuildFillImage() async {
    final regions = _regions;
    if (regions == null) return;
    final fills = _latestFills;
    final rgba = Uint8List(regions.width * regions.height * 4);
    if (fills.isNotEmpty) {
      for (var i = 0; i < regions.regionIds.length; i++) {
        final regionId = regions.regionIds[i];
        final fill = fills[regionId];
        if (fill == null) continue;
        final x = i % regions.width;
        final y = i ~/ regions.width;
        final c = _styledFillColor(fill, x, y, regions.width, regions.height);
        final p = i * 4;
        rgba[p] = (c >> 16) & 0xFF;
        rgba[p + 1] = (c >> 8) & 0xFF;
        rgba[p + 2] = c & 0xFF;
        rgba[p + 3] = (c >> 24) & 0xFF;
      }
    }
    final image = await rgbaToImage(rgba, regions.width, regions.height);
    if (!mounted) {
      image.dispose();
      return;
    }
    final old = _fillImage;
    setState(() => _fillImage = image);
    old?.dispose();
  }

  int _styledFillColor(FillAction fill, int x, int y, int width, int height) {
    final base = fill.color;
    final nx = x / math.max(width - 1, 1);
    final ny = y / math.max(height - 1, 1);
    Color color = base;
    switch (fill.style) {
      case FillStyle.solid:
        color = base;
        break;
      case FillStyle.linearGradient:
        color = Color.lerp(base, Colors.white, nx * .42)!;
        break;
      case FillStyle.radialGradient:
        final d = math.sqrt(math.pow(nx - .5, 2) + math.pow(ny - .5, 2)).clamp(0.0, .8).toDouble() / .8;
        color = Color.lerp(base, Colors.white, d * .48)!;
        break;
      case FillStyle.rainbow:
        color = HSVColor.fromAHSV(1, (nx * 330 + ny * 50) % 360, .78, .95).toColor();
        break;
      case FillStyle.glitter:
        final sparkle = ((x * 73856093) ^ (y * 19349663)) & 31;
        color = sparkle < 3 ? Color.lerp(base, Colors.white, .78)! : Color.lerp(base, Colors.black, sparkle / 170)!;
        break;
      case FillStyle.dots:
        color = ((x ~/ 12 + y ~/ 12) % 2 == 0) ? base : Color.lerp(base, Colors.white, .55)!;
        break;
      case FillStyle.stars:
        final star = ((x ~/ 18) * 17 + (y ~/ 18) * 23) % 11 == 0;
        color = star ? Color.lerp(base, Colors.white, .82)! : base;
        break;
    }
    return color.toARGB32();
  }

  void _chooseColor(Color color) {
    setState(() => _color = color);
    widget.appState.rememberColor(color.toARGB32());
  }

  void _addAction(EditAction action, {bool rebuildFill = false}) {
    setState(() {
      _actions.add(action);
      _redo.clear();
    });
    if (rebuildFill) _rebuildFillImage();
    _autoSave();
  }

  Future<void> _undo() async {
    if (_actions.isEmpty) return;
    final action = _actions.removeLast();
    _redo.add(action);
    setState(() {});
    if (action is FillAction) await _rebuildFillImage();
    _autoSave();
  }

  Future<void> _redoAction() async {
    if (_redo.isEmpty) return;
    final action = _redo.removeLast();
    _actions.add(action);
    setState(() {});
    if (action is FillAction) await _rebuildFillImage();
    _autoSave();
  }

  Future<void> _autoSave() async {
    setState(() => _saving = true);
    await widget.appState.saveArtwork(
      widget.artwork.id,
      SavedArtworkState(actions: List<EditAction>.from(_actions), background: _background, updatedAt: DateTime.now(), progress: _progress),
    );
    if (mounted) setState(() => _saving = false);
  }

  int _regionAt(PointData point) => _regions?.regionAtNormalized(point.x, point.y) ?? -1;

  void _tapCanvas(TapUpDetails details, Size canvasSize) {
    if (_regions == null || canvasSize.width <= 0 || canvasSize.height <= 0) return;
    final point = PointData(details.localPosition.dx / canvasSize.width, details.localPosition.dy / canvasSize.height);
    final region = _regionAt(point);
    switch (_tool) {
      case EditorTool.fill:
        if (region >= 0) _addAction(FillAction(regionId: region, colorValue: _color.toARGB32(), style: _fillStyle), rebuildFill: true);
        break;
      case EditorTool.eyedropper:
        final fill = _latestFills[region];
        if (fill != null) {
          _chooseColor(fill.color);
        } else {
          final sampled = _regions!.sourceColorAtNormalized(point.x, point.y);
          _chooseColor(Color(sampled));
        }
        break;
      case EditorTool.sticker:
        if (!widget.appState.premiumUnlocked) {
          _premiumFeatureDialog('Stickers');
          return;
        }
        _addAction(StickerAction(emoji: _selectedSticker, x: point.x, y: point.y, size: 42));
        break;
      case EditorTool.eraser:
        // A tap with the eraser removes the most recent fill from that enclosed region.
        if (region >= 0) {
          final index = _actions.lastIndexWhere((a) => a is FillAction && a.regionId == region);
          if (index >= 0) {
            final removed = _actions.removeAt(index);
            _redo.add(removed);
            setState(() {});
            _rebuildFillImage();
            _autoSave();
          }
        }
        break;
      default:
        break;
    }
  }

  bool get _isStrokeTool => <EditorTool>{
        EditorTool.brush, EditorTool.pencil, EditorTool.marker, EditorTool.crayon,
        EditorTool.airbrush, EditorTool.watercolor, EditorTool.glitter, EditorTool.pattern,
        EditorTool.eraser,
      }.contains(_tool);

  void _panStart(DragStartDetails details, Size size) {
    if (_tool == EditorTool.glitter && !widget.appState.premiumUnlocked) {
      _premiumFeatureDialog('Glitter');
      return;
    }
    if (!_isStrokeTool || size.width <= 0 || size.height <= 0) return;
    final p = PointData(details.localPosition.dx / size.width, details.localPosition.dy / size.height, _lastPressure);
    _activeStrokeRegion = _edgeProtection ? _regionAt(p) : null;
    _draftStroke = StrokeAction(
      tool: _tool,
      colorValue: _color.toARGB32(),
      width: _brushSize,
      opacity: _opacity,
      hardness: _hardness,
      edgeRegionId: _activeStrokeRegion,
      points: <PointData>[p],
    );
    setState(() {});
  }

  void _panUpdate(DragUpdateDetails details, Size size) {
    final draft = _draftStroke;
    if (draft == null || size.width <= 0 || size.height <= 0) return;
    final p = PointData(details.localPosition.dx / size.width, details.localPosition.dy / size.height, _lastPressure);
    if (_edgeProtection && _activeStrokeRegion != null && _activeStrokeRegion! >= 0 && _regionAt(p) != _activeStrokeRegion) return;
    _draftStroke = StrokeAction(
      tool: draft.tool,
      colorValue: draft.colorValue,
      width: draft.width,
      opacity: draft.opacity,
      hardness: draft.hardness,
      edgeRegionId: draft.edgeRegionId,
      points: <PointData>[...draft.points, p],
    );
    setState(() {});
  }

  void _panEnd(DragEndDetails details) {
    final draft = _draftStroke;
    if (draft == null) return;
    setState(() {
      if (draft.points.length > 1) {
        _actions.add(draft);
        _redo.clear();
      }
      _draftStroke = null;
      _activeStrokeRegion = null;
    });
    _autoSave();
  }

  Future<void> _exportAndShare() async {
    try {
      final boundary = _exportKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 2.5);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) return;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/huepop_${widget.artwork.id}_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes.buffer.asUint8List());
      await Share.shareXFiles(<XFile>[XFile(file.path)], text: 'Colored with HuePop');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not export artwork: $e')));
    }
  }

  Future<void> _clearMenu() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const ListTile(title: Text('Clear artwork', style: TextStyle(fontWeight: FontWeight.w900))),
          ListTile(leading: const Icon(Icons.brush_outlined), title: const Text('Clear brush strokes'), onTap: () => Navigator.pop(context, 'strokes')),
          ListTile(leading: const Icon(Icons.format_color_fill), title: const Text('Clear fills'), onTap: () => Navigator.pop(context, 'fills')),
          ListTile(leading: const Icon(Icons.delete_outline), title: const Text('Clear everything'), onTap: () => Navigator.pop(context, 'all')),
        ]),
      ),
    );
    if (choice == null) return;
    setState(() {
      if (choice == 'strokes') _actions.removeWhere((a) => a is StrokeAction);
      if (choice == 'fills') _actions.removeWhere((a) => a is FillAction);
      if (choice == 'all') _actions.clear();
      _redo.clear();
    });
    await _rebuildFillImage();
    _autoSave();
  }

  double _normalizedPressure(double pressure, double min, double max) {
    if (max <= min || pressure <= 0) return 1.0;
    return ((pressure - min) / (max - min)).clamp(.2, 1.0).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final compactPhone = MediaQuery.sizeOf(context).width < 600;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 4,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.artwork.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, fontSize: compactPhone ? 16 : 20)),
          Text('${(_progress * 100).round()}% colored', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400)),
        ]),
        actions: [
          if (_saving) const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Center(child: SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)))),
          IconButton(tooltip: 'Undo', onPressed: _actions.isEmpty ? null : _undo, icon: const Icon(Icons.undo)),
          IconButton(tooltip: 'Redo', onPressed: _redo.isEmpty ? null : _redoAction, icon: const Icon(Icons.redo)),
          if (!compactPhone) IconButton(tooltip: 'Show original', onPressed: () => setState(() => _showReference = !_showReference), icon: Icon(_showReference ? Icons.visibility : Icons.visibility_outlined)),
          if (!compactPhone) IconButton(tooltip: 'Reset zoom', onPressed: () => _transformController.value = Matrix4.identity(), icon: const Icon(Icons.center_focus_strong)),
          IconButton(tooltip: 'Save & share', onPressed: _exportAndShare, icon: const Icon(Icons.ios_share)),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear') _clearMenu();
              if (value == 'favorite') widget.appState.toggleFavorite(widget.artwork.id);
              if (value == 'reference') setState(() => _showReference = !_showReference);
              if (value == 'zoom') _transformController.value = Matrix4.identity();
            },
            itemBuilder: (_) => [
              if (compactPhone) PopupMenuItem(value: 'reference', child: Text(_showReference ? 'Hide original' : 'Show original')),
              if (compactPhone) const PopupMenuItem(value: 'zoom', child: Text('Reset zoom')),
              PopupMenuItem(value: 'favorite', child: Text(widget.appState.favorites.contains(widget.artwork.id) ? 'Remove favorite' : 'Add to favorites')),
              const PopupMenuItem(value: 'clear', child: Text('Clear…')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 14), Text('Preparing smart coloring regions…')]))
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Unable to open artwork.\n$_error', textAlign: TextAlign.center)))
              : LayoutBuilder(builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 900;
                  final editor = Column(children: [
                    if (!wide) _MobileToolBar(selected: _tool, premiumUnlocked: widget.appState.premiumUnlocked, onSelected: _selectTool),
                    Expanded(child: _buildCanvas()),
                    _BottomControls(
                      color: _color,
                      quickColors: _quickColors,
                      appState: widget.appState,
                      size: _brushSize,
                      opacity: _opacity,
                      hardness: _hardness,
                      edgeProtection: _edgeProtection,
                      fillStyle: _fillStyle,
                      background: _background,
                      onColor: _chooseColor,
                      onMoreColors: _showColorPicker,
                      onPalettes: _showPalettePicker,
                      onSize: (value) => setState(() => _brushSize = value),
                      onOpacity: (value) => setState(() => _opacity = value),
                      onHardness: (value) => setState(() => _hardness = value),
                      onEdgeProtection: (value) => setState(() => _edgeProtection = value),
                      onFillStyle: _selectFillStyle,
                      onBackground: (value) { setState(() => _background = value); _autoSave(); },
                      onSticker: _showStickerPicker,
                    ),
                  ]);
                  if (!wide) return editor;
                  return Row(children: [
                    _DesktopToolRail(selected: _tool, premiumUnlocked: widget.appState.premiumUnlocked, onSelected: _selectTool),
                    Expanded(child: editor),
                  ]);
                }),
    );
  }

  Widget _buildCanvas() {
    final regions = _regions!;
    return Container(
      color: const Color(0xFFE8E6ED),
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 6 : 12),
      child: Center(
        child: InteractiveViewer(
          transformationController: _transformController,
          minScale: .8,
          maxScale: 7,
          panEnabled: _tool == EditorTool.pan,
          scaleEnabled: true,
          boundaryMargin: const EdgeInsets.all(300),
          child: AspectRatio(
            aspectRatio: regions.width / regions.height,
            child: LayoutBuilder(builder: (context, box) {
              final size = Size(box.maxWidth, box.maxHeight);
              return Listener(
                onPointerDown: (event) => _lastPressure = _normalizedPressure(event.pressure, event.pressureMin, event.pressureMax),
                onPointerMove: (event) => _lastPressure = _normalizedPressure(event.pressure, event.pressureMin, event.pressureMax),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) => _tapCanvas(details, size),
                  onPanStart: _isStrokeTool ? (details) => _panStart(details, size) : null,
                  onPanUpdate: _isStrokeTool ? (details) => _panUpdate(details, size) : null,
                  onPanEnd: _isStrokeTool ? _panEnd : null,
                  child: RepaintBoundary(
                  key: _exportKey,
                  child: Stack(fit: StackFit.expand, children: [
                    _Background(style: _background),
                    if (!_showReference)
                      CustomPaint(
                        painter: _PaintLayerPainter(fillImage: _fillImage, actions: [..._actions, if (_draftStroke != null) _draftStroke!]),
                      ),
                    if (_showReference)
                      widget.localArtworkPath != null
                          ? Image.file(File(widget.localArtworkPath!), fit: BoxFit.fill, errorBuilder: (_, __, ___) => Image.network(widget.artwork.imageUrl, fit: BoxFit.fill))
                          : Image.network(widget.artwork.imageUrl, fit: BoxFit.fill)
                    else if (_outlineImage != null)
                      RawImage(image: _outlineImage, fit: BoxFit.fill, filterQuality: FilterQuality.high),
                    if (!_showReference)
                      CustomPaint(painter: _StickerPainter(_actions.whereType<StickerAction>().toList())),
                  ]),
                ),
              ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Future<void> _showColorPicker() async {
    var hue = HSVColor.fromColor(_color).hue;
    var saturation = HSVColor.fromColor(_color).saturation;
    var value = HSVColor.fromColor(_color).value;
    Color draft = _color;
    final hexController = TextEditingController(text: '#${_color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}');
    final rgbController = TextEditingController(text: '${(_color.r * 255).round().clamp(0, 255)}, ${(_color.g * 255).round().clamp(0, 255)}, ${(_color.b * 255).round().clamp(0, 255)}');
    final selected = await showDialog<Color>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setLocal) {
        void syncFields() {
          hexController.text = '#${draft.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
          rgbController.text = '${(draft.r * 255).round().clamp(0, 255)}, ${(draft.g * 255).round().clamp(0, 255)}, ${(draft.b * 255).round().clamp(0, 255)}';
        }
        void update() {
          draft = HSVColor.fromAHSV(1, hue, saturation, value).toColor();
          syncFields();
          setLocal(() {});
        }
        void applyHex(String raw) {
          var text = raw.trim().replaceAll('#', '');
          if (text.length == 3) text = text.split('').map((e) => '$e$e').join();
          if (text.length != 6) return;
          final parsed = int.tryParse(text, radix: 16);
          if (parsed == null) return;
          draft = Color(0xFF000000 | parsed);
          final hsv = HSVColor.fromColor(draft);
          hue = hsv.hue; saturation = hsv.saturation; value = hsv.value;
          syncFields();
          setLocal(() {});
        }
        void applyRgb(String raw) {
          final parts = raw.split(',').map((e) => int.tryParse(e.trim())).toList();
          if (parts.length != 3 || parts.any((e) => e == null)) return;
          final r = parts[0]!.clamp(0, 255).toInt();
          final g = parts[1]!.clamp(0, 255).toInt();
          final b = parts[2]!.clamp(0, 255).toInt();
          draft = Color.fromARGB(255, r, g, b);
          final hsv = HSVColor.fromColor(draft);
          hue = hsv.hue; saturation = hsv.saturation; value = hsv.value;
          syncFields();
          setLocal(() {});
        }
        return AlertDialog(
          title: const Text('Choose any color'),
          content: SizedBox(width: 430, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(height: 70, decoration: BoxDecoration(color: draft, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.black12))),
            const SizedBox(height: 12),
            _LabeledSlider(label: 'Hue', value: hue, min: 0, max: 360, onChanged: (v) { hue = v; update(); }),
            _LabeledSlider(label: 'Saturation', value: saturation, min: 0, max: 1, onChanged: (v) { saturation = v; update(); }),
            _LabeledSlider(label: 'Brightness', value: value, min: 0, max: 1, onChanged: (v) { value = v; update(); }),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: hexController, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'HEX', hintText: '#FF4FA3'), onSubmitted: applyHex)),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: rgbController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'RGB', hintText: '255, 79, 163'), onSubmitted: applyRgb)),
            ]),
            const SizedBox(height: 6),
            const Text('Press Enter/Done after editing HEX or RGB.', style: TextStyle(fontSize: 11, color: Colors.black54)),
          ]))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(onPressed: () { applyHex(hexController.text); Navigator.pop(context, draft); }, child: const Text('Use color')),
          ],
        );
      }),
    );
    hexController.dispose();
    rgbController.dispose();
    if (selected != null) _chooseColor(selected);
  }


  Future<void> _showPalettePicker() async {
    const palettes = <String, List<Color>>{
      'Pastel': [Color(0xFFFFB3C7), Color(0xFFFFD6A5), Color(0xFFFDFFB6), Color(0xFFCAFFBF), Color(0xFF9BF6FF), Color(0xFFA0C4FF), Color(0xFFBDB2FF)],
      'Neon': [Color(0xFFFF2BD6), Color(0xFFB7FF00), Color(0xFF00F5FF), Color(0xFFFFEA00), Color(0xFFFF5A00), Color(0xFF7A00FF)],
      'Ocean': [Color(0xFF003F5C), Color(0xFF0077B6), Color(0xFF00B4D8), Color(0xFF90E0EF), Color(0xFF48CAE4), Color(0xFF023E8A)],
      'Nature': [Color(0xFF355E3B), Color(0xFF6B8E23), Color(0xFF8FBC8F), Color(0xFFB8860B), Color(0xFF8B5E3C), Color(0xFFF4A261)],
      'Autumn': [Color(0xFF7F2A1D), Color(0xFFB34700), Color(0xFFD2691E), Color(0xFFFFA500), Color(0xFFDAA520), Color(0xFF6B4423)],
      'Candy': [Color(0xFFFF5DA2), Color(0xFFFF9CEE), Color(0xFFB28DFF), Color(0xFF6EB5FF), Color(0xFF7BF1A8), Color(0xFFFFD56B)],
      'Skin tones': [Color(0xFFFFDFC4), Color(0xFFF0C8A0), Color(0xFFD9A066), Color(0xFFB77A4D), Color(0xFF8D5524), Color(0xFF5C351E)],
    };
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          shrinkWrap: true,
          children: palettes.entries.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: entry.value.map((c) => InkWell(
                onTap: () { _chooseColor(c); Navigator.pop(context); },
                borderRadius: BorderRadius.circular(20),
                child: Container(width: 38, height: 38, decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: Colors.black12))),
              )).toList()),
            ]),
          )).toList(),
        ),
      ),
    );
  }

  Future<void> _showStickerPicker() async {
    if (!widget.appState.premiumUnlocked) {
      await _premiumFeatureDialog('Stickers');
      return;
    }
    const stickers = <String>['✨', '⭐', '💖', '🌸', '🌈', '🦋', '☁️', '🌻', '🍀', '🎈', '👑', '🐾'];
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Wrap(spacing: 16, runSpacing: 16, children: stickers.map((sticker) => InkWell(
            onTap: () => Navigator.pop(context, sticker),
            borderRadius: BorderRadius.circular(16),
            child: Container(width: 64, height: 64, alignment: Alignment.center, decoration: BoxDecoration(color: Colors.black.withValues(alpha: .05), borderRadius: BorderRadius.circular(16)), child: Text(sticker, style: const TextStyle(fontSize: 36))),
          )).toList()),
        ),
      ),
    );
    if (selected != null) setState(() { _selectedSticker = selected; _tool = EditorTool.sticker; });
  }
}

class _Background extends StatelessWidget {
  const _Background({required this.style});
  final BackgroundStyle style;
  @override
  Widget build(BuildContext context) {
    Decoration decoration;
    switch (style) {
      case BackgroundStyle.white:
        decoration = const BoxDecoration(color: Colors.white);
        break;
      case BackgroundStyle.cream:
        decoration = const BoxDecoration(color: Color(0xFFFFF7E8));
        break;
      case BackgroundStyle.sky:
        decoration = const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFBDE9FF), Color(0xFFF8FDFF)]));
        break;
      case BackgroundStyle.sunset:
        decoration = const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF6956B8), Color(0xFFFF819A), Color(0xFFFFD47C)]));
        break;
      case BackgroundStyle.field:
        decoration = const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: [.0, .58, .59, 1], colors: [Color(0xFFB7E7FF), Color(0xFFE8FAFF), Color(0xFF9DDB72), Color(0xFF4E9C52)]));
        break;
      case BackgroundStyle.night:
        decoration = const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF14152E), Color(0xFF34346B)]));
        break;
    }
    return DecoratedBox(decoration: decoration);
  }
}

class _PaintLayerPainter extends CustomPainter {
  const _PaintLayerPainter({required this.fillImage, required this.actions});
  final ui.Image? fillImage;
  final List<EditAction> actions;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Offset.zero & size, Paint());
    final fill = fillImage;
    if (fill != null) {
      canvas.drawImageRect(fill, Rect.fromLTWH(0, 0, fill.width.toDouble(), fill.height.toDouble()), Offset.zero & size, Paint()..filterQuality = FilterQuality.low);
    }
    for (final action in actions) {
      if (action is! StrokeAction || action.points.isEmpty) continue;
      _drawStroke(canvas, size, action);
    }
    canvas.restore();
  }

  void _drawStroke(Canvas canvas, Size size, StrokeAction stroke) {
    final points = stroke.points.map((p) => Offset(p.x * size.width, p.y * size.height)).toList();
    if (points.length < 2) return;
    final baseWidth = stroke.width * (size.shortestSide / 700).clamp(.65, 2.2);
    final paint = Paint()
      ..color = stroke.color.withValues(alpha: stroke.opacity)
      ..strokeWidth = baseWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (stroke.isEraser) {
      paint
        ..blendMode = BlendMode.clear
        ..strokeWidth = baseWidth * 1.35;
    }

    switch (stroke.tool) {
      case EditorTool.pencil:
        paint.strokeWidth = math.max(1.5, baseWidth * .35);
        break;
      case EditorTool.marker:
        paint.color = stroke.color.withValues(alpha: stroke.opacity * .55);
        paint.strokeWidth = baseWidth * 1.25;
        break;
      case EditorTool.crayon:
        paint.color = stroke.color.withValues(alpha: stroke.opacity * .72);
        paint.strokeWidth = baseWidth * 1.1;
        break;
      case EditorTool.airbrush:
        paint.color = stroke.color.withValues(alpha: stroke.opacity * .16);
        paint.maskFilter = MaskFilter.blur(BlurStyle.normal, baseWidth * (1.05 - stroke.hardness).clamp(.08, .95));
        paint.strokeWidth = baseWidth * 2.1;
        break;
      case EditorTool.watercolor:
        paint.color = stroke.color.withValues(alpha: stroke.opacity * .22);
        paint.strokeWidth = baseWidth * 1.7;
        if (stroke.hardness < .7) paint.maskFilter = MaskFilter.blur(BlurStyle.normal, baseWidth * (.7 - stroke.hardness) * .35);
        break;
      case EditorTool.glitter:
        paint.color = stroke.color.withValues(alpha: stroke.opacity * .7);
        paint.strokeWidth = math.max(2, baseWidth * .32);
        break;
      case EditorTool.pattern:
        paint.color = stroke.color.withValues(alpha: stroke.opacity * .85);
        paint.strokeWidth = math.max(2, baseWidth * .48);
        break;
      default:
        break;
    }

    if (stroke.tool == EditorTool.pencil || stroke.tool == EditorTool.brush || stroke.tool == EditorTool.watercolor) {
      for (var i = 0; i < points.length - 1; i++) {
        final pressure = ((stroke.points[i].pressure + stroke.points[i + 1].pressure) / 2).clamp(.2, 1.0);
        final segmentPaint = Paint()
          ..color = paint.color
          ..strokeCap = paint.strokeCap
          ..strokeJoin = paint.strokeJoin
          ..style = paint.style
          ..blendMode = paint.blendMode
          ..strokeWidth = paint.strokeWidth * pressure;
        if (paint.maskFilter != null) segmentPaint.maskFilter = paint.maskFilter;
        canvas.drawLine(points[i], points[i + 1], segmentPaint);
      }
    } else {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }

    if (stroke.tool == EditorTool.crayon || stroke.tool == EditorTool.glitter || stroke.tool == EditorTool.pattern) {
      final dotPaint = Paint()..color = stroke.color.withValues(alpha: stroke.opacity * .7);
      for (var i = 0; i < points.length; i += stroke.tool == EditorTool.glitter ? 2 : 4) {
        final p = points[i];
        if (stroke.tool == EditorTool.pattern) {
          canvas.drawCircle(p, math.max(1.5, baseWidth * .18), dotPaint..style = PaintingStyle.stroke..strokeWidth = 1.3);
        } else {
          final radius = stroke.tool == EditorTool.glitter ? math.max(1.4, baseWidth * .13) : math.max(.8, baseWidth * .08);
          canvas.drawCircle(Offset(p.dx + (i % 3 - 1) * radius * 2, p.dy + (i % 5 - 2) * radius), radius, dotPaint..style = PaintingStyle.fill);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PaintLayerPainter oldDelegate) => oldDelegate.fillImage != fillImage || oldDelegate.actions != actions;
}

class _StickerPainter extends CustomPainter {
  const _StickerPainter(this.stickers);
  final List<StickerAction> stickers;
  @override
  void paint(Canvas canvas, Size size) {
    for (final sticker in stickers) {
      final painter = TextPainter(text: TextSpan(text: sticker.emoji, style: TextStyle(fontSize: sticker.size)), textDirection: TextDirection.ltr)..layout();
      painter.paint(canvas, Offset(sticker.x * size.width - painter.width / 2, sticker.y * size.height - painter.height / 2));
    }
  }
  @override
  bool shouldRepaint(covariant _StickerPainter oldDelegate) => oldDelegate.stickers != stickers;
}

class _DesktopToolRail extends StatelessWidget {
  const _DesktopToolRail({required this.selected, required this.premiumUnlocked, required this.onSelected});
  final EditorTool selected;
  final bool premiumUnlocked;
  final ValueChanged<EditorTool> onSelected;
  @override
  Widget build(BuildContext context) => Container(
        width: 88,
        color: Colors.white,
        child: ListView(padding: const EdgeInsets.symmetric(vertical: 8), children: _toolButtons(selected, onSelected, premiumUnlocked: premiumUnlocked, vertical: true)),
      );
}

class _MobileToolBar extends StatelessWidget {
  const _MobileToolBar({required this.selected, required this.premiumUnlocked, required this.onSelected});
  final EditorTool selected;
  final bool premiumUnlocked;
  final ValueChanged<EditorTool> onSelected;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 68,
        child: Material(
          color: Colors.white,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 8), children: _toolButtons(selected, onSelected, premiumUnlocked: premiumUnlocked, vertical: false)),
        ),
      );
}

List<Widget> _toolButtons(EditorTool selected, ValueChanged<EditorTool> onSelected, {required bool premiumUnlocked, required bool vertical}) {
  const tools = <(EditorTool, IconData, String)>[
    (EditorTool.fill, Icons.format_color_fill, 'Fill'),
    (EditorTool.brush, Icons.brush, 'Brush'),
    (EditorTool.pencil, Icons.edit, 'Pencil'),
    (EditorTool.marker, Icons.border_color, 'Marker'),
    (EditorTool.crayon, Icons.draw, 'Crayon'),
    (EditorTool.airbrush, Icons.blur_on, 'Airbrush'),
    (EditorTool.watercolor, Icons.water_drop_outlined, 'Water'),
    (EditorTool.glitter, Icons.auto_awesome, 'Glitter'),
    (EditorTool.pattern, Icons.grid_4x4, 'Pattern'),
    (EditorTool.eraser, Icons.auto_fix_normal, 'Eraser'),
    (EditorTool.eyedropper, Icons.colorize, 'Picker'),
    (EditorTool.sticker, Icons.emoji_emotions_outlined, 'Sticker'),
    (EditorTool.pan, Icons.pan_tool_alt, 'Pan'),
  ];
  return tools.map((item) {
    final active = item.$1 == selected;
    final locked = !premiumUnlocked && (item.$1 == EditorTool.glitter || item.$1 == EditorTool.sticker);
    final content = InkWell(
      onTap: () => onSelected(item.$1),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: vertical ? 80 : 72,
        height: vertical ? 66 : 60,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: active ? const Color(0xFFECE4FF) : Colors.transparent, borderRadius: BorderRadius.circular(14)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Stack(clipBehavior: Clip.none, children: [
            Icon(item.$2, color: active ? huePopPurple : Colors.black54),
            if (locked)
              const Positioned(right: -8, top: -8, child: Icon(Icons.lock_rounded, size: 13, color: huePopPurple)),
          ]),
          const SizedBox(height: 3),
          Text(item.$3, style: TextStyle(fontSize: 10, fontWeight: active ? FontWeight.w800 : FontWeight.w500, color: active ? huePopPurple : Colors.black54)),
        ]),
      ),
    );
    return content;
  }).toList();
}

class _BottomControls extends StatelessWidget {
  const _BottomControls({
    required this.color,
    required this.quickColors,
    required this.appState,
    required this.size,
    required this.opacity,
    required this.hardness,
    required this.edgeProtection,
    required this.fillStyle,
    required this.background,
    required this.onColor,
    required this.onMoreColors,
    required this.onPalettes,
    required this.onSize,
    required this.onOpacity,
    required this.onHardness,
    required this.onEdgeProtection,
    required this.onFillStyle,
    required this.onBackground,
    required this.onSticker,
  });
  final Color color;
  final List<Color> quickColors;
  final HuePopAppState appState;
  final double size;
  final double opacity;
  final double hardness;
  final bool edgeProtection;
  final FillStyle fillStyle;
  final BackgroundStyle background;
  final ValueChanged<Color> onColor;
  final VoidCallback onMoreColors;
  final VoidCallback onPalettes;
  final ValueChanged<double> onSize;
  final ValueChanged<double> onOpacity;
  final ValueChanged<double> onHardness;
  final ValueChanged<bool> onEdgeProtection;
  final ValueChanged<FillStyle> onFillStyle;
  final ValueChanged<BackgroundStyle> onBackground;
  final VoidCallback onSticker;

  @override
  Widget build(BuildContext context) {
    final recent = appState.recentColors.map(Color.new).toList();
    final colors = <Color>[...recent, ...quickColors];
    final unique = <int, Color>{};
    for (final c in colors) {
      unique[c.toARGB32()] = c;
    }
    return Material(
      color: Colors.white,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            height: 45,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                IconButton.filledTonal(tooltip: 'Full color picker', onPressed: onMoreColors, icon: const Icon(Icons.color_lens_outlined)),
                IconButton(tooltip: 'Theme palettes', onPressed: onPalettes, icon: const Icon(Icons.apps_rounded)),
                const SizedBox(width: 6),
                ...unique.values.map((c) => GestureDetector(
                      onLongPress: () => appState.toggleFavoriteColor(c.toARGB32()),
                      onTap: () => onColor(c),
                      child: Container(
                        width: 36,
                        height: 36,
                        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(color: c.toARGB32() == color.toARGB32() ? huePopPurple : Colors.black12, width: c.toARGB32() == color.toARGB32() ? 3 : 1),
                          boxShadow: c == Colors.white ? const [BoxShadow(color: Colors.black12, blurRadius: 2)] : null,
                        ),
                        child: appState.favoriteColors.contains(c.toARGB32()) ? Icon(Icons.star, size: 14, color: c.computeLuminance() > .55 ? Colors.black54 : Colors.white) : null,
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 48,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              SizedBox(width: 220, child: _CompactSlider(icon: Icons.line_weight, value: size, min: 4, max: 70, onChanged: onSize, label: '${size.round()}')),
              SizedBox(width: 220, child: _CompactSlider(icon: Icons.opacity, value: opacity, min: .1, max: 1, onChanged: onOpacity, label: '${(opacity * 100).round()}%')),
              SizedBox(width: 220, child: _CompactSlider(icon: Icons.blur_circular, value: hardness, min: .05, max: 1, onChanged: onHardness, label: '${(hardness * 100).round()}%')),
              const SizedBox(width: 8),
              Center(child: Tooltip(message: 'Smart edge protection', child: FilterChip(selected: edgeProtection, onSelected: onEdgeProtection, avatar: const Icon(Icons.shield_outlined, size: 18), label: const Text('Edges')))),
              const SizedBox(width: 8),
              Center(child: PopupMenuButton<FillStyle>(
                tooltip: 'Fill style',
                onSelected: onFillStyle,
                itemBuilder: (_) => FillStyle.values.map((s) => PopupMenuItem(
                  value: s,
                  child: Row(children: [
                    Expanded(child: Text(_pretty(s.name))),
                    if (s == FillStyle.glitter && !appState.premiumUnlocked) const Icon(Icons.lock_rounded, size: 16, color: huePopPurple),
                  ]),
                )).toList(),
                child: Chip(avatar: const Icon(Icons.gradient, size: 18), label: Text(_pretty(fillStyle.name))),
              )),
              const SizedBox(width: 8),
              Center(child: PopupMenuButton<BackgroundStyle>(
                tooltip: 'Background',
                onSelected: onBackground,
                itemBuilder: (_) => BackgroundStyle.values.map((s) => PopupMenuItem(value: s, child: Text(_pretty(s.name)))).toList(),
                child: Chip(avatar: const Icon(Icons.landscape_outlined, size: 18), label: Text(_pretty(background.name))),
              )),
              Center(child: Stack(clipBehavior: Clip.none, children: [IconButton(tooltip: 'Choose sticker', onPressed: onSticker, icon: const Icon(Icons.emoji_emotions_outlined)), if (!appState.premiumUnlocked) const Positioned(right: 2, top: 2, child: Icon(Icons.lock_rounded, size: 14, color: huePopPurple))])),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _CompactSlider extends StatelessWidget {
  const _CompactSlider({required this.icon, required this.value, required this.min, required this.max, required this.onChanged, required this.label});
  final IconData icon;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final String label;
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 18, color: Colors.black54),
        Expanded(child: Slider(value: value, min: min, max: max, onChanged: onChanged)),
        SizedBox(width: 38, child: Text(label, textAlign: TextAlign.right, style: const TextStyle(fontSize: 11))),
      ]);
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({required this.label, required this.value, required this.min, required this.max, required this.onChanged});
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  @override
  Widget build(BuildContext context) => Row(children: [
        SizedBox(width: 78, child: Text(label)),
        Expanded(child: Slider(value: value, min: min, max: max, onChanged: onChanged)),
      ]);
}

String _pretty(String value) {
  final spaced = value.replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m.group(1)}');
  return spaced[0].toUpperCase() + spaced.substring(1);
}
