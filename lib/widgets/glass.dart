import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:class_manager/state/app_state.dart';
import 'package:class_manager/theme/palette.dart';
import 'package:class_manager/widgets/glass_backdrop.dart';

/// 玻璃面板：边缘折射、分层高光、色散及跟随指针的弹性反馈。
///
/// 对应「卡片背景模糊」「卡片透明」「液态玻璃」「果冻效果」「色散」等设置。
class LiquidGlass extends StatefulWidget {
  final Widget child;
  final BorderRadius radius;
  final EdgeInsetsGeometry? padding;
  final Color tintColor; // 着色基准色
  final double? tintAlphaOverride;
  final double? blurOverride;
  final bool? liquidOverride;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? glowColor;
  final EdgeInsetsGeometry? margin;

  const LiquidGlass({
    super.key,
    required this.child,
    this.radius = const BorderRadius.all(Radius.circular(16)),
    this.padding,
    this.tintColor = Colors.white,
    this.tintAlphaOverride,
    this.blurOverride,
    this.liquidOverride,
    this.onTap,
    this.onLongPress,
    this.glowColor,
    this.margin,
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
    // 液态模式稍降低雾度，保留可见的背景折射；显式模糊值保持原样。
    final sigma =
        (widget.blurOverride ?? settings.cardBlur * (liquid ? 13 : 20)).clamp(
          0.0,
          40.0,
        );
    // 着色强度 → 不透明度：参照 iOS Liquid Glass（填充极淡，约 0.05~0.2）
    final tint = widget.tintAlphaOverride != null
        ? (widget.tintAlphaOverride! * 0.38).clamp(0.0, 0.55)
        : (0.05 + (1 - settings.cardTransparency) * 0.20).clamp(0.03, 0.30);
    final dispersion = liquid ? settings.dispersion.clamp(0.0, 1.0) : 0.0;
    final refraction = liquid ? settings.refraction.clamp(0.0, 1.0) : 0.0;
    final interactive = widget.onTap != null || widget.onLongPress != null;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    Widget content = ClipRRect(
      borderRadius: widget.radius,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: GlassBackdrop(
                radius: widget.radius,
                sigma: sigma,
                refraction: refraction,
                dispersion: dispersion,
              ),
            ),
          ),
          // 淡色玻璃底（iOS 风格：几乎透明，仅轻微冷调）
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
              ),
            ),
          ),
          // 高光和色散环只在玻璃表面绘制，不包裹或过滤文字。
          if (liquid)
            Positioned.fill(
              child: IgnorePointer(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: _pressed ? 1.0 : (_hovered ? 0.55 : 0.0)),
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  builder: (context, activity, _) => CustomPaint(
                    painter: _GlassEdgePainter(
                      radius: widget.radius,
                      light: _light,
                      activity: activity,
                      refraction: refraction,
                      dispersion: dispersion,
                    ),
                  ),
                ),
              ),
            )
          else
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: widget.radius,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
              ),
            ),
          if (widget.padding != null)
            Padding(padding: widget.padding!, child: widget.child)
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: widget.child,
            ),
        ],
      ),
    );

    content = Container(
      decoration: BoxDecoration(
        borderRadius: widget.radius,
        boxShadow: [
          BoxShadow(
            color: (widget.glowColor ?? Colors.black).withValues(
              alpha: liquid ? 0.24 : 0.20,
            ),
            blurRadius: liquid ? 24 : 14,
            offset: Offset(0, liquid ? 8 : 5),
          ),
          if (liquid)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
        ],
      ),
      child: content,
    );

    // 原始指针事件不争夺子控件的手势：输入框、滑杆和滚动仍正常工作。
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

    // 果冻效果：按压缩放 + 弹性回弹
    if (settings.jellyEffect && interactive && !reduceMotion) {
      content = GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => _release(),
        onTapCancel: _release,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : (liquid && _hovered ? 1.012 : 1.0),
          duration: _pressed
              ? const Duration(milliseconds: 70)
              : const Duration(milliseconds: 480),
          curve: _pressed ? Curves.easeOut : Curves.elasticOut,
          child: content,
        ),
      );
    } else if (interactive) {
      content = GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: content,
      );
    }

    return Container(margin: widget.margin, child: content);
  }
}

/// 分层光学边缘，参考 liquid-glass-react 的遮罩描边及指针高光。
/// 即使没有 Impeller 折射能力，也保持相同的表面光泽和厚度。
class _GlassEdgePainter extends CustomPainter {
  const _GlassEdgePainter({
    required this.radius,
    required this.light,
    required this.activity,
    required this.refraction,
    required this.dispersion,
  });

  final BorderRadius radius;
  final Alignment light;
  final double activity;
  final double refraction;
  final double dispersion;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    if (size.isEmpty) return;
    final rrect = radius.toRRect(rect).scaleRadii();
    final thickness = math.min(
      size.shortestSide * 0.12,
      2.0 + refraction * 3.0,
    );

    canvas.save();
    canvas.clipRRect(rrect);

    // 微弱的表面光泽，保留中心透明度。
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: light,
          end: Alignment(-light.x, -light.y),
          colors: [
            Colors.white.withValues(alpha: 0.055 + activity * 0.025),
            Colors.white.withValues(alpha: 0.0),
            Colors.black.withValues(alpha: 0.025),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(rect),
    );

    // 渐变内圈沿完整圆角行进，替代平直的顶部/底部高光线。
    final rim = Path()
      ..fillType = PathFillType.evenOdd
      ..addRRect(rrect)
      ..addRRect(rrect.deflate(thickness));
    canvas.drawPath(
      rim,
      Paint()
        ..shader = LinearGradient(
          begin: light,
          end: Alignment(-light.x, -light.y),
          colors: [
            Colors.white.withValues(alpha: 0.34 + activity * 0.16),
            Colors.white.withValues(alpha: 0.035),
            Colors.black.withValues(alpha: 0.09),
            Colors.white.withValues(alpha: 0.20),
          ],
          stops: const [0, 0.38, 0.65, 1],
        ).createShader(rect),
    );
    // 细外圈与内圈共同形成玻璃厚度，不改变卡片尺寸。
    canvas.drawRRect(
      rrect.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          begin: light,
          end: Alignment(-light.x, -light.y),
          colors: [
            Colors.white.withValues(alpha: 0.68),
            Colors.white.withValues(alpha: 0.08),
            Colors.white.withValues(alpha: 0.35),
          ],
        ).createShader(rect),
    );
    canvas.drawRRect(
      rrect.deflate(thickness + 0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = Colors.white.withValues(alpha: 0.11),
    );
    if (dispersion > 0) {
      canvas.drawPath(
        rim,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF71DEFF).withValues(alpha: dispersion * 0.25),
              Colors.transparent,
              const Color(0xFFFFA3BA).withValues(alpha: dispersion * 0.25),
            ],
          ).createShader(rect),
      );
    }
    if (activity > 0) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            center: light,
            radius: 0.8,
            colors: [
              Colors.white.withValues(alpha: 0.12 * activity),
              Colors.transparent,
            ],
          ).createShader(rect),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GlassEdgePainter oldDelegate) =>
      oldDelegate.radius != radius ||
      oldDelegate.light != light ||
      oldDelegate.activity != activity ||
      oldDelegate.refraction != refraction ||
      oldDelegate.dispersion != dispersion;
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
