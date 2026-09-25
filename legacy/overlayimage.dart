import 'package:flutter/material.dart';
import 'package:varityskirja/blendmask.dart';

class OverlayImage extends StatelessWidget {
  const OverlayImage({super.key, required this.image, required this.child});

  final Image image;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        IgnorePointer(
          child: BlendMask(
            opacity: 1.0,
            blendMode: BlendMode.darken,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [image],
            ),
          ),
        ),
      ],
    );
  }
}
