import 'package:flutter/material.dart';

class DrawingArea extends StatefulWidget {
  final Color color;

  const DrawingArea({super.key, required this.color});

  @override
  _DrawingAreaState createState() => _DrawingAreaState();
}

const int MAX_DRAWING_LENGTH = 100;

class _DrawingAreaState extends State<DrawingArea> {
  // For some reason, this is not working with List.empty<Offset>()
  List<PointsAndColor> points = [(List<Offset>.empty(), Colors.white)];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) {
        setState(() {
          points.add(([], widget.color));
        });
      },
      onPanUpdate: (details) {
        setState(() {
          if (points.last.$1.length > MAX_DRAWING_LENGTH) {
            points.add(([points.last.$1.last], widget.color));
          }
          points[points.length - 1] =
              ([...points.last.$1, details.localPosition], points.last.$2);
        });
      },
      onPanEnd: (details) {},
      child: Stack(
          children: points
              .asMap()
              .map((index, shape) => MapEntry(
                  index,
                  RepaintBoundary(
                      key: Key(index.toString()),
                      child: CustomPaint(
                        painter: DrawingPainter(shape, index),
                        size: Size.infinite,
                        isComplex: true,
                        willChange: index == points.length - 1,
                      ))))
              .values
              .toList()),
    );
  }
}

class DrawingPainter extends CustomPainter {
  final PointsAndColor pointsAndColor;
  final int index;
  DrawingPainter(this.pointsAndColor, this.index);

  @override
  void paint(Canvas canvas, Size size) {
    final points = pointsAndColor.$1;
    final color = pointsAndColor.$2;

    Paint paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = color == Colors.white ? 40.0 : 20.0;

    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }
  }

  @override
  bool shouldRepaint(DrawingPainter oldDelegate) {
    return oldDelegate.pointsAndColor != pointsAndColor;
  }
}

typedef PointsAndColor = (List<Offset> list, Color color);
