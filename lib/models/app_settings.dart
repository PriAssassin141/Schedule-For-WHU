/// 应用个性化设置（对应「个性化」页的各项配置）。
class AppSettings {
  /// 开学日期（第 1 周周一），'yyyy-MM-dd'。
  String startDate;

  /// 主题色索引（0..kThemeColors.length-1）。
  int themeColorIndex;

  /// 沉浸式背景：开启时壁纸铺满整屏。
  bool immersiveBackground;

  /// 背景模糊（0..1）。
  double backgroundBlur;

  /// 卡片透明（0..1，越大越透明）。
  double cardTransparency;

  /// 卡片背景模糊（0..1）。
  double cardBlur;

  /// 液态玻璃（性能要求高）。
  bool liquidGlass;

  /// 果冻效果。
  bool jellyEffect;

  /// 饱和度（0..2，1 为原始）。
  double saturation;

  /// 折射（0..1）。
  double refraction;

  /// 色散（0..1）。
  double dispersion;

  /// 背景图片路径；null 表示使用内置渐变装潢。
  String? wallpaperPath;

  AppSettings({
    this.startDate = '2026-09-07',
    this.themeColorIndex = 0,
    this.immersiveBackground = true,
    this.backgroundBlur = 0.0,
    this.cardTransparency = 0.45,
    this.cardBlur = 0.6,
    this.liquidGlass = true,
    this.jellyEffect = true,
    this.saturation = 1.0,
    this.refraction = 0.0,
    this.dispersion = 0.0,
    this.wallpaperPath,
  });

  Map<String, Object?> toMap() => {
        'start_date': startDate,
        'theme_color_index': themeColorIndex,
        'immersive_background': immersiveBackground ? 1 : 0,
        'background_blur': backgroundBlur,
        'card_transparency': cardTransparency,
        'card_blur': cardBlur,
        'liquid_glass': liquidGlass ? 1 : 0,
        'jelly_effect': jellyEffect ? 1 : 0,
        'saturation': saturation,
        'refraction': refraction,
        'dispersion': dispersion,
        'wallpaper_path': wallpaperPath,
      };

  factory AppSettings.fromMap(Map<String, Object?> m) => AppSettings(
        startDate: (m['start_date'] as String?) ?? '2026-09-07',
        themeColorIndex: (m['theme_color_index'] as int?) ?? 0,
        immersiveBackground: ((m['immersive_background'] as int?) ?? 1) == 1,
        backgroundBlur: (m['background_blur'] as num?)?.toDouble() ?? 0.0,
        cardTransparency: (m['card_transparency'] as num?)?.toDouble() ?? 0.45,
        cardBlur: (m['card_blur'] as num?)?.toDouble() ?? 0.6,
        liquidGlass: ((m['liquid_glass'] as int?) ?? 1) == 1,
        jellyEffect: ((m['jelly_effect'] as int?) ?? 1) == 1,
        saturation: (m['saturation'] as num?)?.toDouble() ?? 1.0,
        refraction: (m['refraction'] as num?)?.toDouble() ?? 0.0,
        dispersion: (m['dispersion'] as num?)?.toDouble() ?? 0.0,
        wallpaperPath: m['wallpaper_path'] as String?,
      );

  AppSettings copyWith({
    String? startDate,
    int? themeColorIndex,
    bool? immersiveBackground,
    double? backgroundBlur,
    double? cardTransparency,
    double? cardBlur,
    bool? liquidGlass,
    bool? jellyEffect,
    double? saturation,
    double? refraction,
    double? dispersion,
    String? wallpaperPath,
    bool clearWallpaper = false,
  }) =>
      AppSettings(
        startDate: startDate ?? this.startDate,
        themeColorIndex: themeColorIndex ?? this.themeColorIndex,
        immersiveBackground:
            immersiveBackground ?? this.immersiveBackground,
        backgroundBlur: backgroundBlur ?? this.backgroundBlur,
        cardTransparency: cardTransparency ?? this.cardTransparency,
        cardBlur: cardBlur ?? this.cardBlur,
        liquidGlass: liquidGlass ?? this.liquidGlass,
        jellyEffect: jellyEffect ?? this.jellyEffect,
        saturation: saturation ?? this.saturation,
        refraction: refraction ?? this.refraction,
        dispersion: dispersion ?? this.dispersion,
        wallpaperPath:
            clearWallpaper ? null : (wallpaperPath ?? this.wallpaperPath),
      );
}
