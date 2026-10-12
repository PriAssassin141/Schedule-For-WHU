import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Filters only the scene behind a panel; the child and its text stay sharp.
/// Windows/Skia and shader-loading failures fall back to Gaussian blur.
class GlassBackdrop extends StatefulWidget {
  const GlassBackdrop({
    super.key,
    required this.radius,
    required this.sigma,
    required this.refraction,
    required this.dispersion,
  });

  final BorderRadius radius;
  final double sigma;
  final double refraction;
  final double dispersion;

  @override
  State<GlassBackdrop> createState() => _GlassBackdropState();
}

class _GlassBackdropState extends State<GlassBackdrop> {
  static Future<ui.FragmentProgram?>? _program;
  ui.FragmentShader? _shader;
  bool _loading = false;

  bool get _needsShader =>
      ui.ImageFilter.isShaderFilterSupported &&
      (widget.refraction > 0 || widget.dispersion > 0);

  @override
  void initState() {
    super.initState();
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
    if (!mounted || program == null) return;
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
        ui.ImageFilter? filter;
        if (widget.sigma > 0.01) {
          filter = ui.ImageFilter.blur(
            sigmaX: widget.sigma,
            sigmaY: widget.sigma,
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
            ..setFloat(9, widget.dispersion);
          final opticalFilter = ui.ImageFilter.shader(_shader!);
          filter = filter == null
              ? opticalFilter
              : ui.ImageFilter.compose(outer: opticalFilter, inner: filter);
        }
        return filter == null
            ? const SizedBox.expand()
            : BackdropFilter(filter: filter, child: const SizedBox.expand());
      },
    );
  }
}
