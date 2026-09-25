import 'package:flutter/material.dart';
import 'package:varityskirja/colorbutton.dart';

const List<Color> COLORS = [
  Colors.red,
  Colors.green,
  Colors.blue,
  Colors.yellow,
  Colors.orange,
  Color.fromARGB(255, 248, 108, 206),
  Colors.white,
  Color.fromARGB(255, 100, 100, 100),
  Colors.brown
];

class ColorPicker extends StatelessWidget {
  final void Function(Color color) onColorChanged;
  final Color currentColor;

  const ColorPicker(
      {super.key, required this.onColorChanged, required this.currentColor});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 10,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ...COLORS.map((color) => ColorButton(
              color: color,
              onPressed: onColorChanged,
              currentColor: currentColor))
        ],
      ),
    );
  }
}
