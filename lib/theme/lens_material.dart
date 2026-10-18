/// Lens v1.1.0-showcase.1 material tokens, adapted from design-systems (MIT).
/// Keep all shared optical presets here rather than in individual controls.
class LensMaterial {
  const LensMaterial(this.name, this.refraction, this.blur, this.dispersion);

  final String name;
  final double refraction;
  final double blur;
  final double dispersion;

  static const defaultRefraction = 0.90;
  static const defaultBlur = 0.24;
  static const defaultDispersion = 0.65;
  static const thick = LensMaterial(
    '厚润',
    defaultRefraction,
    defaultBlur,
    defaultDispersion,
  );
  static const clear = LensMaterial('清透', 0.65, 0.12, 0.35);
  static const soft = LensMaterial('柔雾', 0.38, 0.64, 0.12);
  static const presets = {'thick': thick, 'clear': clear, 'soft': soft};

  static String identify(double refraction, double blur, double dispersion) {
    for (final entry in presets.entries) {
      final material = entry.value;
      if ((material.refraction - refraction).abs() < 0.001 &&
          (material.blur - blur).abs() < 0.001 &&
          (material.dispersion - dispersion).abs() < 0.001) {
        return entry.key;
      }
    }
    return 'custom';
  }
}
