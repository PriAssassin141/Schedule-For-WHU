import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:class_manager/widgets/lens_reflection.dart';
import 'package:class_manager/widgets/lens_backdrop_refraction.dart';

/// Filters only the scene behind a panel; the child and its text stay sharp.
/// Scrollable panels use native backdrop lenses on every backend, avoiding
/// runtime-effect UV changes under viewport clipping and scroll transforms.
class GlassBackdrop extends StatefulWidget {
  const GlassBackdrop({
    super.key,
    required this.radius,
    required this.sigma,
    this.fallbackSigma,
    required this.refraction,
    required this.dispersion,
    this.liquid = true,
    this.pointer = const Alignment(-0.7, -0.8),
    this.pressure = 0,
    this.hover = 0,
    this.refractFallback = false,
  });

  final BorderRadius radius;
  final double sigma;
  final double? fallbackSigma;
  final double refraction;
  final double dispersion;
  final bool liquid;
  final Alignment pointer;
  final double pressure;
  final double hover;
  final bool refractFallback;

  @override
  State<GlassBackdrop> createState() => _GlassBackdropState();
}

class _GlassBackdropState extends State<GlassBackdrop> {
  static Future<ui.FragmentProgram?>? _program;
  ui.FragmentShader? _shader;
  bool _loading = false;
  bool _insideScrollable = false;

  bool get _needsShader =>
      ui.ImageFilter.isShaderFilterSupported &&
      widget.liquid &&
      !_insideScrollable;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Impeller may crop the shader's input texture as a viewport clips the
    // panel. Its UV origin/extent then no longer describes the full panel.
    // Stay on one native path throughout scrolling, including while at rest.
    _insideScrollable = Scrollable.maybeOf(context) != null;
    _ensureShader();
  }

  @override
  void didUpdateWidget(covariant GlassBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ensureShader();
  }

  static Future<ui.FragmentProgram?> _loadProgram() async {
    try {
      return await ui.FragmentProgram.fromAsset('shaders/liquid_glass.frag');
    } catch (error) {
      debugPrint('Liquid glass shader unavailable, using blur: $error');
      return null;
    }
  }

  Future<void> _ensureShader() async {
    if (!_needsShader || _loading || _shader != null) return;
    _loading = true;
    final program = await (_program ??= _loadProgram());
    if (!mounted || program == null || !_needsShader) return;
    setState(() => _shader = program.fragmentShader());
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final ready = _needsShader && _shader != null;
        final sigma = ready
            ? widget.sigma
            : (widget.fallbackSigma ?? widget.sigma);
        ui.ImageFilter? filter;
        if (sigma > 0.01) {
          filter = ui.ImageFilter.blur(
            sigmaX: sigma,
            sigmaY: sigma,
            tileMode: ui.TileMode.clamp,
          );
        }
        if (_needsShader && _shader != null && !size.isEmpty) {
          final radii = widget.radius.toRRect(Offset.zero & size).scaleRadii();
          // Slots 0/1 and sampler 0 belong to the engine, never set them here.
          _shader!
            ..setFloat(2, size.width)
            ..setFloat(3, size.height)
            ..setFloat(4, radii.tlRadiusX)
            ..setFloat(5, radii.trRadiusX)
            ..setFloat(6, radii.brRadiusX)
            ..setFloat(7, radii.blRadiusX)
            ..setFloat(8, widget.refraction)
            ..setFloat(9, widget.dispersion)
            ..setFloat(10, widget.pointer.x)
            ..setFloat(11, widget.pointer.y)
            ..setFloat(12, widget.pressure)
            ..setFloat(13, widget.hover)
            ..setFloat(14, 1);
          final opticalFilter = ui.ImageFilter.shader(_shader!);
          filter = filter == null
              ? opticalFilter
              : ui.ImageFilter.compose(outer: opticalFilter, inner: filter);
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            if (widget.liquid &&
                !ready &&
                (widget.refractFallback || _insideScrollable) &&
                widget.refraction > 0)
              LensBackdropRefraction(
                radius: widget.radius,
                refraction: widget.refraction,
                pressure: widget.pressure,
                sigma: sigma,
              )
            else if (filter != null)
              BackdropFilter(filter: filter, child: const SizedBox.expand()),
            if (widget.liquid && (!_needsShader || _shader == null))
              CustomPaint(
                painter: LensReflection(
                  radius: widget.radius,
                  pointer: widget.pointer,
                  pressure: widget.pressure,
                  hover: widget.hover,
                  dispersion: widget.dispersion,
                ),
              ),
          ],
        );
      },
    );
  }
}
