import 'dart:convert';

import 'package:class_manager/models/schedule_adjustment.dart';
import 'package:class_manager/models/agenda_event.dart';
import 'package:class_manager/theme/lens_material.dart';

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

  /// 显示课表网格（关闭后课表背景的白色网格消失）。
  bool showGrid;

  /// 个人姓名（用于「我的」页问候语）。
  String userName;
  HomeViewMode homeViewMode;
  // A newly added field can be null on instances retained by hot reload:
  // constructors are not rerun. Keep the public setting non-null even then.
  final List<String>? _agendaCustomCategories;
  List<String> get agendaCustomCategories =>
      _agendaCustomCategories ?? const [];

  bool holidayAdjustmentEnabled;
  bool useNationalHolidays;
  final List<ScheduleAdjustment> scheduleAdjustments;

  AppSettings({
    this.startDate = '2026-09-07',
    this.themeColorIndex = 0,
    this.immersiveBackground = true,
    this.backgroundBlur = 0.0,
    this.cardTransparency = 0.45,
    this.cardBlur = LensMaterial.defaultBlur,
    this.liquidGlass = true,
    this.jellyEffect = true,
    this.saturation = 1.0,
    this.refraction = LensMaterial.defaultRefraction,
    this.dispersion = LensMaterial.defaultDispersion,
    this.wallpaperPath,
    this.showGrid = true,
    this.userName = '',
    this.homeViewMode = HomeViewMode.courses,
    List<String>? agendaCustomCategories,
    this.holidayAdjustmentEnabled = false,
    this.useNationalHolidays = true,
    List<ScheduleAdjustment> scheduleAdjustments = const [],
  }) : scheduleAdjustments = List.unmodifiable(scheduleAdjustments),
       _agendaCustomCategories = agendaCustomCategories == null
           ? null
           : List.unmodifiable(agendaCustomCategories);

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
    'show_grid': showGrid ? 1 : 0,
    'user_name': userName,
    'home_view_mode': homeViewMode.name,
    'agenda_custom_categories': jsonEncode(agendaCustomCategories),
    'holiday_adjustment_enabled': holidayAdjustmentEnabled ? 1 : 0,
    'use_national_holidays': useNationalHolidays ? 1 : 0,
    'schedule_adjustments': ScheduleAdjustment.encode(scheduleAdjustments),
  };

  factory AppSettings.fromMap(Map<String, Object?> m) => AppSettings(
    startDate: (m['start_date'] as String?) ?? '2026-09-07',
    themeColorIndex: (m['theme_color_index'] as int?) ?? 0,
    immersiveBackground: ((m['immersive_background'] as int?) ?? 1) == 1,
    backgroundBlur: (m['background_blur'] as num?)?.toDouble() ?? 0.0,
    cardTransparency: (m['card_transparency'] as num?)?.toDouble() ?? 0.45,
    cardBlur: (m['card_blur'] as num?)?.toDouble() ?? LensMaterial.defaultBlur,
    liquidGlass: ((m['liquid_glass'] as int?) ?? 1) == 1,
    jellyEffect: ((m['jelly_effect'] as int?) ?? 1) == 1,
    saturation: (m['saturation'] as num?)?.toDouble() ?? 1.0,
    refraction:
        (m['refraction'] as num?)?.toDouble() ?? LensMaterial.defaultRefraction,
    dispersion:
        (m['dispersion'] as num?)?.toDouble() ?? LensMaterial.defaultDispersion,
    wallpaperPath: m['wallpaper_path'] as String?,
    showGrid: ((m['show_grid'] as int?) ?? 1) == 1,
    userName: (m['user_name'] as String?) ?? '',
    homeViewMode: HomeViewMode.fromStored(m['home_view_mode']),
    agendaCustomCategories: _decodeCategories(m['agenda_custom_categories']),
    holidayAdjustmentEnabled:
        ((m['holiday_adjustment_enabled'] as int?) ?? 0) == 1,
    useNationalHolidays: ((m['use_national_holidays'] as int?) ?? 1) == 1,
    scheduleAdjustments: ScheduleAdjustment.decode(
      m['schedule_adjustments'] as String?,
    ),
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
    bool? showGrid,
    String? userName,
    HomeViewMode? homeViewMode,
    List<String>? agendaCustomCategories,
    bool? holidayAdjustmentEnabled,
    bool? useNationalHolidays,
    List<ScheduleAdjustment>? scheduleAdjustments,
  }) => AppSettings(
    startDate: startDate ?? this.startDate,
    themeColorIndex: themeColorIndex ?? this.themeColorIndex,
    immersiveBackground: immersiveBackground ?? this.immersiveBackground,
    backgroundBlur: backgroundBlur ?? this.backgroundBlur,
    cardTransparency: cardTransparency ?? this.cardTransparency,
    cardBlur: cardBlur ?? this.cardBlur,
    liquidGlass: liquidGlass ?? this.liquidGlass,
    jellyEffect: jellyEffect ?? this.jellyEffect,
    saturation: saturation ?? this.saturation,
    refraction: refraction ?? this.refraction,
    dispersion: dispersion ?? this.dispersion,
    wallpaperPath: clearWallpaper
        ? null
        : (wallpaperPath ?? this.wallpaperPath),
    showGrid: showGrid ?? this.showGrid,
    userName: userName ?? this.userName,
    homeViewMode: homeViewMode ?? this.homeViewMode,
    agendaCustomCategories:
        agendaCustomCategories ?? this.agendaCustomCategories,
    holidayAdjustmentEnabled:
        holidayAdjustmentEnabled ?? this.holidayAdjustmentEnabled,
    useNationalHolidays: useNationalHolidays ?? this.useNationalHolidays,
    scheduleAdjustments: scheduleAdjustments ?? this.scheduleAdjustments,
  );

  static List<String> _decodeCategories(Object? value) {
    try {
      final decoded = jsonDecode(value as String? ?? '[]');
      return decoded is List
          ? decoded
                .whereType<String>()
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toSet()
                .toList()
          : [];
    } catch (_) {
      return [];
    }
  }
}
