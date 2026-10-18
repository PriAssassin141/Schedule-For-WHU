import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Live native backdrop lens for Skia and viewport-clipped Impeller surfaces.
/// A narrow bevel and a clear magnifying core use native matrix filters.
/// The bevel samples the still-unpainted core, avoiding repeated refraction.
class LensBackdropRefraction extends StatelessWidget {
  const LensBackdropRefraction({
    super.key,
    required this.radius,
    required this.refraction,
    required this.pressure,
    required this.sigma,
  });

  final BorderRadius radius;
  final double refraction;
  final double pressure;
  final double sigma;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      final bevel = math.min(size.shortestSide * 0.035, 1.8);
      const bands = 1;
      return Stack(
        fit: StackFit.expand,
        children: [
          for (var i = 0; i <= bands; i++)
            ClipPath(
              clipper: _LensBand(
                radius,
                i * bevel / bands,
                i == bands ? null : (i + 1) * bevel / bands,
              ),
              child: RawMagnifier(
                size: size,
                magnificationScale: _scale(i / bands),
                child: sigma <= 0.01
                    ? const SizedBox.expand()
                    : BackdropFilter(
                        filter: ui.ImageFilter.blur(
                          sigmaX: sigma,
                          sigmaY: sigma,
                        ),
                        child: const SizedBox.expand(),
                      ),
              ),
            ),
        ],
      );
    },
  );

  double _scale(double depth) {
    final curvature = math.pow(1 - depth, 1.65).toDouble();
    return 1 + refraction * (0.065 + curvature * 0.055) * (1 + pressure * 0.15);
  }
}

class _LensBand extends CustomClipper<Path> {
  const _LensBand(this.radius, this.outerInset, this.innerInset);
  final BorderRadius radius;
  final double outerInset;
  final double? innerInset;

  @override
  Path getClip(Size size) {
    final rrect = radius.toRRect(Offset.zero & size).scaleRadii();
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addRRect(rrect.deflate(outerInset))
      ..addPath(
        innerInset == null
            ? Path()
            : (Path()..addRRect(rrect.deflate(innerInset!))),
        Offset.zero,
      );
  }

  @override
  bool shouldReclip(covariant _LensBand oldClipper) =>
      radius != oldClipper.radius ||
      outerInset != oldClipper.outerInset ||
      innerInset != oldClipper.innerInset;
}
