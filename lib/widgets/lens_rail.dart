import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// Dock travel spring. Retargeting keeps velocity, with a soft arrival overshoot.
class LensRailController extends AnimationController {
  LensRailController({required super.vsync, required double initialValue})
    : super.unbounded(value: initialValue);

  void settle(double target, {required bool animate}) {
    if (!animate) {
      stop();
      value = target;
      return;
    }
    if (!isAnimating && (value - target).abs() < 0.0001) return;
    animateWith(
      SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 360, damping: 22),
        value,
        target,
        velocity,
        snapToEnd: true,
        tolerance: const Tolerance(distance: 0.001, velocity: 0.01),
      ),
    );
  }
}

/// Lens opticalSelection's one-shot edge light; never pulses on initial mount.
class LensSelectionGlow extends StatefulWidget {
  const LensSelectionGlow({
    super.key,
    required this.trigger,
    required this.active,
    required this.animate,
    required this.color,
    required this.radius,
    required this.child,
  });

  final Object trigger;
  final bool active;
  final bool animate;
  final Color color;
  final BorderRadius radius;
  final Widget child;

  @override
  State<LensSelectionGlow> createState() => _LensSelectionGlowState();
}

class _LensSelectionGlowState extends State<LensSelectionGlow>
    with SingleTickerProviderStateMixin {
  late final _flow = AnimationController(
    vsync: this,
    value: 1,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didUpdateWidget(covariant LensSelectionGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.animate || !widget.active) {
      _flow.stop();
      _flow.value = 1;
    } else if (oldWidget.trigger != widget.trigger) {
      _flow.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _flow,
    child: widget.child,
    builder: (context, child) => Stack(
      children: [
        child!,
        if (widget.active && _flow.value > 0 && _flow.value < 1)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _SelectionLight(
                  widget.radius,
                  widget.color,
                  _flow.value,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _SelectionLight extends CustomPainter {
  const _SelectionLight(this.radius, this.color, this.progress);
  final BorderRadius radius;
  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = radius.toRRect(Offset.zero & size).scaleRadii().deflate(0.8);
    final path = Path()..addRRect(rect);
    final metric = path.computeMetrics().first;
    final end = metric.length * progress;
    final start = end - metric.length * 0.18;
    final beam = Path()
      ..addPath(metric.extractPath(math.max(0, start), end), Offset.zero);
    if (start < 0) {
      beam.addPath(
        metric.extractPath(metric.length + start, metric.length),
        Offset.zero,
      );
    }
    canvas.save();
    canvas.clipRRect(rect);
    canvas.drawPath(
      beam,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.6)
        ..color = Color.lerp(
          color,
          Colors.white,
          0.55,
        )!.withValues(alpha: 0.65 * math.sin(math.pi * progress)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SelectionLight oldDelegate) =>
      radius != oldDelegate.radius ||
      color != oldDelegate.color ||
      progress != oldDelegate.progress;
}
