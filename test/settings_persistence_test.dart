import 'package:flutter_test/flutter_test.dart';

import 'package:class_manager/db/app_database.dart';
import 'package:class_manager/models/app_settings.dart';

/// 设置持久化：写入 settings 表后重新读取，所有字段都应保持一致。
///
/// 回归用例：新增设置项（show_grid / user_name）曾因读取端手写 key 列表
/// 而无法还原，导致重启后失效。
void main() {
  /// 模拟 saveSettings：把设置写成 settings 表的一行行记录。
  List<Map<String, Object?>> rowsOf(AppSettings s) => s
      .toMap()
      .entries
      .map((e) => {'key': e.key, 'value': e.value?.toString() ?? ''})
      .toList();

  test('全部字段写入后可完整读回', () {
    final saved = AppSettings(
      startDate: '2026-09-07',
      themeColorIndex: 4,
      backgroundBlur: 0.25,
      cardTransparency: 0.7,
      cardBlur: 0.4,
      liquidGlass: false,
      saturation: 1.4,
      refraction: 0.3,
      dispersion: 0.2,
      wallpaperPath: '/tmp/wall.jpg',
      showGrid: false,
      userName: '闫梓萱',
    );

    final loaded = settingsFromRows(rowsOf(saved));

    expect(loaded.startDate, '2026-09-07');
    expect(loaded.themeColorIndex, 4);
    expect(loaded.backgroundBlur, 0.25);
    expect(loaded.cardTransparency, 0.7);
    expect(loaded.cardBlur, 0.4);
    expect(loaded.liquidGlass, isFalse);
    expect(loaded.saturation, 1.4);
    expect(loaded.refraction, 0.3);
    expect(loaded.dispersion, 0.2);
    expect(loaded.wallpaperPath, '/tmp/wall.jpg');
    // 本次修复的两个字段
    expect(loaded.showGrid, isFalse, reason: '显示网格设置应持久化');
    expect(loaded.userName, '闫梓萱', reason: '个人姓名应持久化');
  });

  test('toMap 的每个字段都能被读回（防止将来再漏字段）', () {
    final defaults = AppSettings().toMap();
    final saved = AppSettings(
      showGrid: false,
      userName: '测试同学',
      wallpaperPath: '/wall.jpg',
      themeColorIndex: 2,
      saturation: 0.8,
    );
    final loaded = settingsFromRows(rowsOf(saved));
    final loadedMap = loaded.toMap();

    for (final key in defaults.keys) {
      expect(loadedMap.containsKey(key), isTrue, reason: '缺少字段 $key');
    }
    expect(loadedMap['user_name'], '测试同学');
    expect(loadedMap['show_grid'], 0);
    expect(loadedMap['wallpaper_path'], '/wall.jpg');
  });

  test('未存过的字段使用默认值；空值不会被当成字符串', () {
    // 空表
    final fresh = settingsFromRows(const []);
    expect(fresh.showGrid, isTrue);
    expect(fresh.userName, '');
    expect(fresh.wallpaperPath, isNull);

    // 壁纸被清空（写入空串）→ 读回 null
    final cleared = settingsFromRows([
      {'key': 'wallpaper_path', 'value': ''},
      {'key': 'show_grid', 'value': '0'},
    ]);
    expect(cleared.wallpaperPath, isNull);
    expect(cleared.showGrid, isFalse);
  });

  test('损坏/非法值回落到默认值', () {
    final loaded = settingsFromRows([
      {'key': 'theme_color_index', 'value': 'abc'},
      {'key': 'saturation', 'value': 'xyz'},
      {'key': 'show_grid', 'value': 'null'},
    ]);
    expect(loaded.themeColorIndex, 0);
    expect(loaded.saturation, 1.0);
    expect(loaded.showGrid, isTrue);
  });
}
