import 'package:flutter/material.dart';

class ColorButton extends StatelessWidget {
  final Color color;
  final void Function(Color color) onPressed;
  final Color currentColor;
  final Widget? icon;

  const ColorButton(
      {super.key,
      required this.color,
      required this.onPressed,
      required this.currentColor,
      this.icon});

  @override
  Widget build(BuildContext context) {
    final isSelected = color == currentColor;
    return Column(
      children: [
        ElevatedButton(
            onPressed: () => onPressed(color),
            style: ElevatedButton.styleFrom(
              shape: const CircleBorder(),
              backgroundColor: color,
              padding: const EdgeInsets.all(2),
            ),
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? color == Colors.white
                          ? Colors.black
                          : Colors.white
                      : color,
                  width: 2,
                ),
              ),
              child: icon,
            )),
        const SizedBox(height: 10),
      ],
    );
  }
}
