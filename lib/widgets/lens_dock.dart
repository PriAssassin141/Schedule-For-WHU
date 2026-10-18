import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/physics.dart';
import 'package:provider/provider.dart';

import 'package:class_manager/state/app_state.dart';
import 'package:class_manager/theme/palette.dart';
import 'package:class_manager/widgets/glass.dart';
import 'package:class_manager/widgets/lens_rail.dart';

class LensDockItem {
  const LensDockItem(this.icon, this.label);
  final IconData icon;
  final String label;
}

/// Lens dock: one moving material under native focusable navigation buttons.
class LensDock extends StatefulWidget {
  const LensDock({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onChanged,
  }) : assert(items.length > 1),
       assert(selectedIndex >= 0 && selectedIndex < items.length);

  final List<LensDockItem> items;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  State<LensDock> createState() => _LensDockState();
}

class _LensDockState extends State<LensDock> with TickerProviderStateMixin {
  late final _rail = LensRailController(
    vsync: this,
    initialValue: widget.selectedIndex.toDouble(),
  );
  final _focus = <FocusNode>[];
  late final _arrival = AnimationController.unbounded(vsync: this);
  bool _animate = false;
  bool _jellyEnabled = false;
  bool _pendingArrival = false;
  double _departure = 0;

  @override
  void initState() {
    super.initState();
    _syncFocus();
    _rail.addListener(_onTravel);
  }

  void _onTravel() {
    final target = widget.selectedIndex.toDouble();
    if (!_pendingArrival) return;
    final crossed = (target - _departure) * (_rail.value - target) >= 0;
    if ((_rail.value - target).abs() > 0.08 && !crossed) return;
    _pendingArrival = false;
    // Impact happens at arrival, independently of the remaining rail velocity.
    // A signed spring first squashes the lens, then expands and settles it.
    _arrival.animateWith(
      SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 420, damping: 13),
        _arrival.value,
        0,
        5,
        snapToEnd: true,
        tolerance: const Tolerance(distance: 0.0001, velocity: 0.001),
      ),
    );
  }

  void _syncFocus() {
    while (_focus.length > widget.items.length) {
      _focus.removeLast().dispose();
    }
    while (_focus.length < widget.items.length) {
      _focus.add(FocusNode());
    }
    for (var i = 0; i < _focus.length; i++) {
      _focus[i].skipTraversal = i != widget.selectedIndex;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = context.watch<AppState>().settings;
    _animate = settings.liquidGlass && !MediaQuery.disableAnimationsOf(context);
    _jellyEnabled = _animate && settings.jellyEffect;
    if (!_jellyEnabled) {
      _pendingArrival = false;
      _arrival.stop();
      _arrival.value = 0;
    }
    if (!_animate) {
      _rail.settle(widget.selectedIndex.toDouble(), animate: false);
    }
  }

  @override
  void didUpdateWidget(covariant LensDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncFocus();
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _departure = _rail.value;
      _pendingArrival = _jellyEnabled;
      _rail.settle(widget.selectedIndex.toDouble(), animate: _animate);
    }
  }

  @override
  void dispose() {
    _rail.dispose();
    _arrival.dispose();
    for (final node in _focus) {
      node.dispose();
    }
    super.dispose();
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    int? next;
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowLeft) {
      final delta =
          (key == LogicalKeyboardKey.arrowRight ? 1 : -1) * (rtl ? -1 : 1);
      next =
          (widget.selectedIndex + delta + widget.items.length) %
          widget.items.length;
    } else if (key == LogicalKeyboardKey.home) {
      next = 0;
    } else if (key == LogicalKeyboardKey.end) {
      next = widget.items.length - 1;
    }
    if (next == null) return KeyEventResult.ignored;
    widget.onChanged(next);
    _focus[next].requestFocus();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppState>().settings;
    final liquid = settings.liquidGlass;
    final color = themeColorOf(settings);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Semantics(
      container: true,
      label: '主导航',
      child: Focus(
        canRequestFocus: false,
        onKeyEvent: _key,
        child: SizedBox(
          height: 64,
          child: LiquidGlass(
            radius: BorderRadius.circular(27),
            padding: const EdgeInsets.all(4),
            tintAlphaOverride: liquid ? 0.08 : 0.30,
            blurOverride: liquid ? settings.cardBlur * 2 : null,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth / widget.items.length;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (liquid)
                      AnimatedBuilder(
                        animation: Listenable.merge([_rail, _arrival]),
                        builder: (context, _) {
                          final position = _rail.value.clamp(
                            0.0,
                            widget.items.length - 1.0,
                          );
                          final physical = rtl
                              ? widget.items.length - 1 - position
                              : position;
                          final stretch = _animate && settings.jellyEffect
                              ? math.min(_rail.velocity.abs() * 0.009, 0.08)
                              : 0.0;
                          final impact = _jellyEnabled ? _arrival.value : 0.0;
                          final scaleX = (1 + stretch - impact).clamp(
                            0.84,
                            1.12,
                          );
                          final scaleY = (1 / (1 + stretch) + impact * 0.65)
                              .clamp(0.90, 1.10);
                          final extra = width * math.max(0, scaleX - 1) * 0.5;
                          final left = (physical * width).clamp(
                            extra,
                            math.max(
                              extra,
                              constraints.maxWidth - width - extra,
                            ),
                          );
                          return Positioned(
                            key: const ValueKey('dock_indicator_position'),
                            left: left.toDouble(),
                            top: 0,
                            bottom: 0,
                            width: width,
                            child: IgnorePointer(
                              child: Transform.scale(
                                key: const ValueKey('dock_lens_deformation'),
                                scaleX: scaleX,
                                scaleY: scaleY,
                                child: LensSelectionGlow(
                                  trigger: widget.selectedIndex,
                                  active: true,
                                  animate: _animate,
                                  color: color,
                                  radius: BorderRadius.circular(23),
                                  child: LiquidGlass(
                                    key: const ValueKey('dock_glass_indicator'),
                                    radius: BorderRadius.circular(23),
                                    padding: EdgeInsets.zero,
                                    tintColor: Color.lerp(
                                      color,
                                      Colors.white,
                                      0.18,
                                    )!,
                                    tintAlphaOverride: 0.20,
                                    blurOverride: settings.cardBlur * 1.5,
                                    refractFallback: true,
                                    pressure: stretch * 3 + impact.abs() * 3,
                                    child: CustomPaint(
                                      foregroundPainter: const _DockLensSheen(),
                                      child: SizedBox(
                                        width: width,
                                        height: constraints.maxHeight,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    Row(
                      children: [
                        for (var i = 0; i < widget.items.length; i++)
                          Expanded(
                            child: Semantics(
                              selected: i == widget.selectedIndex,
                              child: TextButton(
                                key: ValueKey('dock_tab_$i'),
                                focusNode: _focus[i],
                                onPressed: () => widget.onChanged(i),
                                style: TextButton.styleFrom(
                                  splashFactory: liquid
                                      ? NoSplash.splashFactory
                                      : null,
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(23),
                                  ),
                                  foregroundColor: i == widget.selectedIndex
                                      ? Colors.white
                                      : Colors.white60,
                                ),
                                child: SizedBox(
                                  height: constraints.maxHeight,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 42,
                                        height: 26,
                                        decoration:
                                            !liquid && i == widget.selectedIndex
                                            ? BoxDecoration(
                                                color: color.withValues(
                                                  alpha: 0.28,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(13),
                                              )
                                            : null,
                                        child: Icon(
                                          widget.items[i].icon,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        widget.items[i].label,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: i == widget.selectedIndex
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                        ),
                                      ),
                                      if (!liquid) ...[
                                        const SizedBox(height: 2),
                                        Container(
                                          width: 4,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: i == widget.selectedIndex
                                                ? color
                                                : Colors.transparent,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// A quiet surface reflection makes the selected lens legible on dark wallpaper.
/// The center stays transparent; the narrow rim fades on the unlit sides.
class _DockLensSheen extends CustomPainter {
  const _DockLensSheen();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shape = BorderRadius.circular(23).toRRect(rect).scaleRadii();
    canvas.drawRRect(
      shape,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x0EFFFFFF), Color(0x04FFFFFF), Color(0x08FFFFFF)],
          stops: [0, 0.55, 1],
        ).createShader(rect),
    );
    canvas.drawRRect(
      shape.deflate(0.45),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x2EFFFFFF), Color(0x09FFFFFF), Color(0x1AFFFFFF)],
          stops: [0, 0.58, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _DockLensSheen oldDelegate) => false;
}
