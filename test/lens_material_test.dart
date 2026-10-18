import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:class_manager/db/app_database.dart';
import 'package:class_manager/models/app_settings.dart';
import 'package:class_manager/screens/personalization_screen.dart';
import 'package:class_manager/state/app_state.dart';
import 'package:class_manager/theme/lens_material.dart';

void main() {
  test('新安装使用 Lens 厚润材质；老设置包括零值均保持不变', () {
    final defaults = AppSettings.fromMap({});
    expect(
      LensMaterial.identify(
        defaults.refraction,
        defaults.cardBlur,
        defaults.dispersion,
      ),
      'thick',
    );
    final legacy = settingsFromRows([
      {'key': 'refraction', 'value': '0'},
      {'key': 'dispersion', 'value': '0'},
      {'key': 'card_blur', 'value': '0.6'},
      {'key': 'liquid_glass', 'value': '0'},
    ]);
    expect(legacy.refraction, 0);
    expect(legacy.dispersion, 0);
    expect(legacy.cardBlur, 0.6);
    expect(legacy.liquidGlass, isFalse);
  });

  test('三个 Lens 预设写入数据库格式后均能完整读回', () {
    for (final entry in LensMaterial.presets.entries) {
      final material = entry.value;
      final saved = AppSettings(
        refraction: material.refraction,
        cardBlur: material.blur,
        dispersion: material.dispersion,
      );
      final loaded = settingsFromRows(
        saved
            .toMap()
            .entries
            .map(
              (entry) => {
                'key': entry.key,
                'value': entry.value?.toString() ?? '',
              },
            )
            .toList(),
      );
      expect(
        LensMaterial.identify(
          loaded.refraction,
          loaded.cardBlur,
          loaded.dispersion,
        ),
        entry.key,
      );
    }
  });

  testWidgets('预设菜单应用三个光学参数，自定义与高斯选择均被保留', (tester) async {
    final state = AppState.memory();
    await state.updateSettings(
      state.settings.copyWith(
        liquidGlass: false,
        refraction: 0.3,
        cardBlur: 0.7,
        dispersion: 0.1,
        userName: '测试',
        cardTransparency: 0.82,
      ),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: PersonalizationScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('lens_material')));
    await tester.pumpAndSettle();
    expect(find.text('自定义'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('lens_material')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('清透'));
    await tester.pumpAndSettle();
    expect(state.settings.refraction, 0.65);
    expect(state.settings.cardBlur, 0.12);
    expect(state.settings.dispersion, 0.35);
    expect(state.settings.liquidGlass, isFalse);
    expect(state.settings.userName, '测试');
    expect(state.settings.cardTransparency, 0.82);
    expect(tester.takeException(), isNull);
  });
}
