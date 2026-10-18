import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:class_manager/state/app_state.dart';
import 'package:class_manager/theme/palette.dart';
import 'package:class_manager/widgets/glass_backdrop.dart';
import 'package:class_manager/widgets/lens_motion.dart';

/// Shared Lens surface: Snell refraction, quiet reflections and spring pressure.
/// Text and controls stay native; Gaussian mode remains an independent option.
class LiquidGlass extends StatefulWidget {
  final Widget child;
  final BorderRadius radius;
  final EdgeInsetsGeometry? padding;
  final Color tintColor;

  /// Optional translucent base above the backdrop, for readable modal surfaces.
  final Color? backgroundColor;
  final double? tintAlphaOverride;
  final double? blurOverride;
  final bool? liquidOverride;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? glowColor;
  final EdgeInsetsGeometry? margin;
  final double pressure;
  final bool refractFallback;

  const LiquidGlass({
    super.key,
    required this.child,
    this.radius = const BorderRadius.all(Radius.circular(16)),
    this.padding,
    this.tintColor = Colors.white,
    this.backgroundColor,
    this.tintAlphaOverride,
    this.blurOverride,
    this.liquidOverride,
    this.onTap,
    this.onLongPress,
    this.glowColor,
    this.margin,
    this.pressure = 0,
    this.refractFallback = false,
  });

  @override
  State<LiquidGlass> createState() => _LiquidGlassState();
}

class _LiquidGlassState extends State<LiquidGlass> {
  final _surfaceKey = GlobalKey();
  bool _pressed = false;
  bool _hovered = false;
  Alignment _light = const Alignment(-0.7, -0.8);

  void _moveLight(Offset position) {
    final size = _surfaceKey.currentContext?.size;
    if (size == null || size.isEmpty) return;
    final light = Alignment(
      (position.dx / size.width * 2 - 1).clamp(-1.0, 1.0),
      (position.dy / size.height * 2 - 1).clamp(-1.0, 1.0),
    );
    if ((light.x - _light.x).abs() + (light.y - _light.y).abs() > 0.03) {
      setState(() => _light = light);
    }
  }

  void _release() {
    if (!_pressed) return;
    setState(() {
      _pressed = false;
      if (!_hovered) _light = const Alignment(-0.7, -0.8);
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppState>().settings;
    final liquid = widget.liquidOverride ?? settings.liquidGlass;
    // Lens's nine-tap blur has sigma ~= 0.616 * radius. Native Gaussian blur
    // gives the same frosted weight without nine texture fetches per channel.
    final sigma = (widget.blurOverride ?? settings.cardBlur * (liquid ? 6 : 20))
        .clamp(0.0, 40.0);
    final configuredTint = widget.tintAlphaOverride != null
        ? (widget.tintAlphaOverride! * 0.38).clamp(0.0, 0.55)
        : (0.05 + (1 - settings.cardTransparency) * 0.20).clamp(0.03, 0.30);
    final readablePanel = liquid && Scrollable.maybeOf(context) != null;
    // A transparency setting of 100 must still leave settings groups legible.
    // Keep the saved value intact; only the rendered surface has a small floor.
    final panelTint =
        0.11 + (1 - settings.cardTransparency).clamp(0.0, 1.0) * 0.08;
    final tint = readablePanel && configuredTint < panelTint
        ? panelTint
        : configuredTint;
    final dispersion = liquid ? settings.dispersion.clamp(0.0, 1.0) : 0.0;
    final refraction = liquid ? settings.refraction.clamp(0.0, 1.0) : 0.0;
    final interactive = widget.onTap != null || widget.onLongPress != null;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    Widget surface(BuildContext context, double pressure) {
      Widget content = Container(
        decoration: BoxDecoration(
          borderRadius: widget.radius,
          // A scrolling backdrop lens must not sample its own filled shadow.
          boxShadow: readablePanel
              ? const []
              : [
                  BoxShadow(
                    color: (widget.glowColor ?? Colors.black).withValues(
                      alpha: 0.20,
                    ),
                    blurRadius: liquid ? 24 : 14,
                    spreadRadius: liquid ? -10 : 0,
                    offset: Offset(0, liquid ? 12 : 5),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: widget.radius,
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: GlassBackdrop(
                    radius: widget.radius,
                    sigma: sigma,
                    fallbackSigma:
                        (widget.blurOverride ?? settings.cardBlur * 20).clamp(
                          0.0,
                          40.0,
                        ),
                    refraction: refraction,
                    dispersion: dispersion,
                    liquid: liquid,
                    refractFallback: widget.refractFallback,
                    pointer: _light,
                    pressure: (pressure + widget.pressure).clamp(0.0, 1.16),
                    hover: _pressed ? 1 : (_hovered ? 0.55 : 0),
                  ),
                ),
              ),
              if (widget.backgroundColor != null)
                Positioned.fill(
                  child: ColoredBox(color: widget.backgroundColor!),
                ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: widget.radius,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        widget.tintColor.withValues(alpha: tint),
                        widget.tintColor.withValues(alpha: tint * 0.55),
                      ],
                    ),
                    border: readablePanel
                        ? Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                            width: 0.75,
                          )
                        : liquid
                        ? null
                        : Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                            width: 1,
                          ),
                  ),
                ),
              ),
              Padding(
                padding:
                    widget.padding ??
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: widget.child,
              ),
            ],
          ),
        ),
      );
      if (liquid) {
        content = MouseRegion(
          key: _surfaceKey,
          cursor: interactive ? SystemMouseCursors.click : MouseCursor.defer,
          onEnter: (event) {
            setState(() => _hovered = true);
            _moveLight(event.localPosition);
          },
          onHover: (event) => _moveLight(event.localPosition),
          onExit: (_) => setState(() {
            _hovered = false;
            if (!_pressed) _light = const Alignment(-0.7, -0.8);
          }),
          child: Listener(
            onPointerDown: (event) {
              setState(() => _pressed = true);
              _moveLight(event.localPosition);
            },
            onPointerMove: (event) => _moveLight(event.localPosition),
            onPointerUp: (_) => _release(),
            onPointerCancel: (_) => _release(),
            child: content,
          ),
        );
      }
      return content;
    }

    Widget content = interactive
        ? LensMotion(
            pressed: _pressed,
            enabled: settings.jellyEffect && !reduceMotion,
            direction: _light,
            builder: surface,
          )
        : surface(context, 0);
    if (interactive) {
      content = GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => _release(),
        onTapCancel: _release,
        child: content,
      );
    }
    return Container(margin: widget.margin, child: content);
  }
}

/// 小号玻璃图标按钮（主页右上角 + / 分享 / 菜单）。
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  const GlassIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 38,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      radius: BorderRadius.circular(size / 2),
      padding: EdgeInsets.zero,
      tintAlphaOverride: 0.28,
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(icon, size: 19, color: Colors.white),
      ),
    );
  }
}

/// 大卡片内设置行的外壳：可选顶部细线分隔（对应图二的细线分区）。
class _SettingRowShell extends StatelessWidget {
  final bool showDivider;
  final EdgeInsetsGeometry padding;
  final Widget child;

  const _SettingRowShell({
    required this.showDivider,
    required this.padding,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: showDivider
          ? BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 0.6,
                ),
              ),
            )
          : null,
      child: child,
    );
  }
}

/// 设置滑杆行（个性化大卡片内使用，行间用细线分隔）。
class GlassSliderRow extends StatelessWidget {
  final String title;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final String Function(double)? label;
  final bool showDivider;

  const GlassSliderRow({
    super.key,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.label,
    this.showDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = themeColorOf(context.watch<AppState>().settings);
    final v = label?.call(value) ?? value.toStringAsFixed(2);
    return _SettingRowShell(
      showDivider: showDivider,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: SizedBox(
              height: 44,
              child: SliderTheme(
                data:
                    const SliderThemeData(
                      trackHeight: 3,
                      thumbColor: Colors.white,
                      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 9),
                      overlayShape: RoundSliderOverlayShape(overlayRadius: 16),
                    ).copyWith(
                      activeTrackColor: theme,
                      inactiveTrackColor: Colors.white.withValues(alpha: 0.14),
                    ),
                child: Slider(
                  value: value.clamp(min, max),
                  min: min,
                  max: max,
                  onChanged: onChanged,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 34,
            child: Text(
              v,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: theme,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 设置开关行（个性化大卡片内使用，行间用细线分隔）。
class GlassSwitchRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool showDivider;
  final EdgeInsetsGeometry padding;

  const GlassSwitchRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.showDivider = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  });

  @override
  Widget build(BuildContext context) {
    final theme = themeColorOf(context.watch<AppState>().settings);
    return _SettingRowShell(
      showDivider: showDivider,
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 10.5,
                    ),
                  ),
              ],
            ),
          ),
          SwitchTheme(
            data: SwitchThemeData(
              thumbColor: WidgetStateProperty.resolveWith((s) => Colors.white),
              trackColor: WidgetStateProperty.resolveWith(
                (s) => s.contains(WidgetState.selected)
                    ? theme
                    : Colors.white.withValues(alpha: 0.18),
              ),
              trackOutlineColor: const WidgetStatePropertyAll(
                Colors.transparent,
              ),
            ),
            child: Switch(value: value, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}
