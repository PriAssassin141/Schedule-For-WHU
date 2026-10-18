import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// A single spring drives both the surface pose and its optical pressure.
/// Re-grabbing inherits current velocity; no idle animation or drag recognizer.
class LensMotion extends StatefulWidget {
  const LensMotion({
    super.key,
    required this.pressed,
    required this.enabled,
    required this.direction,
    required this.builder,
  });

  final bool pressed;
  final bool enabled;
  final Alignment direction;
  final Widget Function(BuildContext context, double pressure) builder;

  @override
  State<LensMotion> createState() => _LensMotionState();
}

class _LensMotionState extends State<LensMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressure = AnimationController.unbounded(
    vsync: this,
    value: widget.enabled && widget.pressed ? 1 : 0,
  );

  @override
  void didUpdateWidget(covariant LensMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      _pressure.stop();
      _pressure.value = 0;
    } else if (widget.pressed != oldWidget.pressed || !oldWidget.enabled) {
      _pressure.animateWith(
        SpringSimulation(
          const SpringDescription(mass: 1, stiffness: 310, damping: 18),
          _pressure.value,
          widget.pressed ? 1 : 0,
          _pressure.velocity,
          snapToEnd: true,
          tolerance: const Tolerance(distance: 0.005, velocity: 0.025),
        ),
      );
    }
  }

  @override
  void dispose() {
    _pressure.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _pressure,
    builder: (context, _) {
      final pressure = widget.enabled ? _pressure.value.clamp(0.0, 1.16) : 0.0;
      // Lens's 0.70 elasticity and 0.035 lift. Stretch is deliberately bounded
      // because course cards keep their fixed grid slots instead of free dragging.
      final lift = 1 + pressure * 0.70 * 0.035;
      final along = 1 + pressure * 0.014;
      final across = 1 / along;
      final angle = math.atan2(widget.direction.y, widget.direction.x);
      final c = math.cos(angle), s = math.sin(angle);
      final transform = Matrix4.identity()
        ..setEntry(0, 0, (along * c * c + across * s * s) * lift)
        ..setEntry(0, 1, (along - across) * c * s * lift)
        ..setEntry(1, 0, (along - across) * c * s * lift)
        ..setEntry(1, 1, (along * s * s + across * c * c) * lift);
      return Transform(
        alignment: Alignment.center,
        transform: transform,
        child: widget.builder(context, pressure),
      );
    },
  );
}
