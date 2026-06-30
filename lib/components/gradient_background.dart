import 'package:flutter/material.dart';

class GradientBackground extends StatelessWidget {
  const GradientBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Base solid color (the final fallback in the CSS background list)
        Container(color: const Color(0xFF0B1015)),

        // radial-gradient(120% 95% at 10% 6%, #163a44 0%, transparent 52%)
        _RadialLayer(
          color: const Color(0xFF163A44),
          center: const Alignment(-1, 1), // 10% 6% -> (-1..1)
          scaleX: 0.55,
          scaleY: 0.95,
          stopAt: 1.52,
        ),

        // radial-gradient(120% 90% at 92% 16%, #2a2552 0%, transparent 48%)
        _RadialLayer(
          color: const Color(0xFF2A2552),
          center: const Alignment(1.1, -0.38), // 92% 16%
          scaleX: 1.0,
          scaleY: 1.0,
          stopAt: 0.7,
        ),

        // radial-gradient(150% 130% at 62% 104%, #11212a 0%, transparent 58%)
        _RadialLayer(
          color: const Color(0xFF11212A),
          center: const Alignment(0.2, -1.2), // 62% 104%
          scaleX: 0.80,
          scaleY: 1.0,
          stopAt: 1.0,
        ),

        //if (child != null) child!,
      ],
    );
  }
}

class _RadialLayer extends StatelessWidget {
  const _RadialLayer({
    required this.color,
    required this.center,
    required this.scaleX,
    required this.scaleY,
    required this.stopAt,
  });

  final Color color;
  final Alignment center;
  final double scaleX;
  final double scaleY;
  final double stopAt;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: center,
          radius: 0.75, // base radius before scaling
          colors: [color, color.withValues(alpha: 0)],
          stops: [0.0, stopAt],
          transform: _EllipseTransform(scaleX, scaleY, center),
        ),
      ),
    );
  }
}

class _EllipseTransform extends GradientTransform {
  const _EllipseTransform(this.scaleX, this.scaleY, this.center);
  final double scaleX;
  final double scaleY;
  final Alignment center;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    final cx = bounds.left + (center.x + 1) / 2 * bounds.width;
    final cy = bounds.top + (center.y + 1) / 2 * bounds.height;
    return Matrix4.identity()
      ..translate(cx, cy)
      ..scale(1 / scaleX, 1 / scaleY)
      ..translate(-cx, -cy);
  }
}
