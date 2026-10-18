import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Lens-compatible reflection when custom backdrop shaders are unavailable.
/// A narrow directional rim, opposite caustic and quiet broad reflection;
/// deliberately no continuous bright white ring or double border.
class LensReflection extends CustomPainter {
  const LensReflection({
    required this.radius,
    required this.pointer,
    required this.pressure,
    required this.hover,
    required this.dispersion,
  });

  final BorderRadius radius;
  final Alignment pointer;
  final double pressure;
  final double hover;
  final double dispersion;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final rrect = radius.toRRect(rect).scaleRadii();
    final position = pointer.alongSize(size);
    final light = Offset(
      pointer.x * size.width * 0.5 - 80,
      pointer.y * size.height * 0.5 - 150,
    );
    final lightAngle = math.atan2(light.dy, light.dx);
    final colors = <Color>[];
    final caustic = <Color>[];
    final stops = <double>[];
    for (var i = 0; i <= 64; i++) {
      final angle = i / 64 * math.pi * 2;
      final facing = math.cos(angle - lightAngle);
      final directional = math.pow(math.max(facing, 0), 7).toDouble();
      final opposite = math.pow(math.max(-facing, 0), 7).toDouble() * 0.52;
      final tint = Color.lerp(
        const Color(0xFFE4F8FF),
        Colors.white,
        1 - dispersion * directional * 0.3,
      )!;
      colors.add(
        tint.withValues(alpha: 0.018 + directional * 0.35 + opposite * 0.15),
      );
      caustic.add(Colors.white.withValues(alpha: opposite * 0.038));
      stops.add(i / 64);
    }
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRRect(
      rrect.deflate(0.65),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.95
        ..shader = SweepGradient(
          colors: colors,
          stops: stops,
        ).createShader(rect),
    );
    if (size.shortestSide > 8) {
      canvas.drawRRect(
        rrect.deflate(3),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.8)
          ..shader = SweepGradient(
            colors: caustic,
            stops: stops,
          ).createShader(rect),
      );
    }
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment(-0.6 + pointer.x * 0.12, -0.9),
          end: const Alignment(0.6, 0.9),
          colors: [
            Colors.white.withValues(alpha: 0.022 + pressure * 0.016),
            Colors.transparent,
            const Color(0xFFABCCE5).withValues(alpha: 0.012),
          ],
          stops: const [0, 0.6, 1],
        ).createShader(rect),
    );
    if (hover > 0 || pressure > 0) {
      canvas.drawCircle(
        position,
        size.longestSide,
        Paint()
          ..shader =
              RadialGradient(
                colors: [
                  Colors.white.withValues(
                    alpha: 0.024 * (0.4 + hover + pressure * 0.2),
                  ),
                  Colors.transparent,
                ],
              ).createShader(
                Rect.fromCenter(center: position, width: 360, height: 300),
              ),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant LensReflection oldDelegate) =>
      oldDelegate.radius != radius ||
      oldDelegate.pointer != pointer ||
      oldDelegate.pressure != pressure ||
      oldDelegate.hover != hover ||
      oldDelegate.dispersion != dispersion;
}
