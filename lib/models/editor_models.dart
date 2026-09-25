import 'dart:convert';
import 'package:flutter/material.dart';

enum EditorTool {
  fill,
  brush,
  pencil,
  marker,
  crayon,
  airbrush,
  watercolor,
  glitter,
  pattern,
  eraser,
  eyedropper,
  sticker,
  pan,
}

enum FillStyle { solid, linearGradient, radialGradient, rainbow, glitter, dots, stars }

enum BackgroundStyle { white, cream, sky, sunset, field, night }

class PointData {
  const PointData(this.x, this.y, [this.pressure = 1.0]);
  final double x;
  final double y;
  final double pressure;

  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'pressure': pressure};
  factory PointData.fromJson(Map<String, dynamic> json) => PointData(
        (json['x'] as num).toDouble(),
        (json['y'] as num).toDouble(),
        (json['pressure'] as num?)?.toDouble() ?? 1.0,
      );
}

sealed class EditAction {
  const EditAction();
  String get type;
  Map<String, dynamic> toJson();

  static EditAction fromJson(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'fill':
        return FillAction.fromJson(json);
      case 'stroke':
        return StrokeAction.fromJson(json);
      case 'sticker':
        return StickerAction.fromJson(json);
      default:
        throw FormatException('Unknown edit action: ${json['type']}');
    }
  }
}

class FillAction extends EditAction {
  const FillAction({required this.regionId, required this.colorValue, required this.style});
  final int regionId;
  final int colorValue;
  final FillStyle style;
  Color get color => Color(colorValue);
  @override
  String get type => 'fill';

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'regionId': regionId,
        'color': colorValue,
        'style': style.name,
      };

  factory FillAction.fromJson(Map<String, dynamic> json) => FillAction(
        regionId: json['regionId'] as int,
        colorValue: json['color'] as int,
        style: FillStyle.values.firstWhere(
          (value) => value.name == json['style'],
          orElse: () => FillStyle.solid,
        ),
      );
}

class StrokeAction extends EditAction {
  const StrokeAction({
    required this.tool,
    required this.colorValue,
    required this.width,
    required this.opacity,
    this.hardness = 1.0,
    required this.points,
    this.edgeRegionId,
  });

  final EditorTool tool;
  final int colorValue;
  final double width;
  final double opacity;
  final double hardness;
  final List<PointData> points;
  final int? edgeRegionId;
  Color get color => Color(colorValue);
  bool get isEraser => tool == EditorTool.eraser;
  @override
  String get type => 'stroke';

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'tool': tool.name,
        'color': colorValue,
        'width': width,
        'opacity': opacity,
        'hardness': hardness,
        'edgeRegionId': edgeRegionId,
        'points': points.map((point) => point.toJson()).toList(),
      };

  factory StrokeAction.fromJson(Map<String, dynamic> json) => StrokeAction(
        tool: EditorTool.values.firstWhere(
          (value) => value.name == json['tool'],
          orElse: () => EditorTool.brush,
        ),
        colorValue: json['color'] as int,
        width: (json['width'] as num).toDouble(),
        opacity: (json['opacity'] as num).toDouble(),
        hardness: (json['hardness'] as num?)?.toDouble() ?? 1.0,
        edgeRegionId: json['edgeRegionId'] as int?,
        points: (json['points'] as List<dynamic>)
            .map((point) => PointData.fromJson(Map<String, dynamic>.from(point as Map)))
            .toList(),
      );
}

class StickerAction extends EditAction {
  const StickerAction({required this.emoji, required this.x, required this.y, required this.size});
  final String emoji;
  final double x;
  final double y;
  final double size;
  @override
  String get type => 'sticker';

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'emoji': emoji,
        'x': x,
        'y': y,
        'size': size,
      };

  factory StickerAction.fromJson(Map<String, dynamic> json) => StickerAction(
        emoji: json['emoji'] as String,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        size: (json['size'] as num).toDouble(),
      );
}

class SavedArtworkState {
  const SavedArtworkState({
    required this.actions,
    required this.background,
    required this.updatedAt,
    this.favorite = false,
    this.progress = 0,
  });

  final List<EditAction> actions;
  final BackgroundStyle background;
  final DateTime updatedAt;
  final bool favorite;
  final double progress;

  String encode() => jsonEncode({
        'actions': actions.map((action) => action.toJson()).toList(),
        'background': background.name,
        'updatedAt': updatedAt.toIso8601String(),
        'favorite': favorite,
        'progress': progress,
      });

  factory SavedArtworkState.decode(String encoded) {
    final json = jsonDecode(encoded) as Map<String, dynamic>;
    return SavedArtworkState(
      actions: (json['actions'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => EditAction.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      background: BackgroundStyle.values.firstWhere(
        (value) => value.name == json['background'],
        orElse: () => BackgroundStyle.white,
      ),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
      favorite: json['favorite'] as bool? ?? false,
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
    );
  }
}
