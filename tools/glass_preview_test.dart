// Run explicitly: flutter test --no-pub tools/glass_preview_test.dart
// This writes visual QA images only inside artifacts/glass-preview/.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import 'package:class_manager/main.dart';
import 'package:class_manager/models/course.dart';
import 'package:class_manager/services/quark_update_service.dart';
import 'package:class_manager/state/app_state.dart';
import 'package:class_manager/widgets/app_background.dart';
import 'package:class_manager/widgets/glass.dart';
import '../test/support/update_fakes.dart';

class _PreviewBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

void main() {
  _PreviewBinding();
  testWidgets('导出导航、开关、课程卡与调休编辑的玻璃预览', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final fontFile = File('C:/Windows/Fonts/msyh.ttc');
    if (fontFile.existsSync()) {
      await tester.runAsync(() async {
        final bytes = ByteData.sublistView(await fontFile.readAsBytes());
        for (final name in ['Ahem', 'Roboto', 'Microsoft YaHei']) {
          await (FontLoader(name)..addFont(Future.value(bytes))).load();
        }
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      });
    }
    final boundaryKey = GlobalKey();
    final state = AppState.memory()
      ..browseWeek = 1
      ..courses = [
        Course(
          id: 1,
          name: '高级人工智能',
          teacher: '艾浩军',
          location: '新珈楼-B106',
          note: '携带笔记本电脑',
          day: 1,
          startPeriod: 6,
          endPeriod: 7,
          weeks: '1-16',
          colorValue: 0xFF7894E8,
        ),
      ];
    await tester.pumpWidget(
      Provider<UpdateCheckerFactory>.value(
        value: () => StubUpdateChecker(
          () async => sampleUpdate(
            description:
                'v1.0.4更新内容：①加入课表根据法定节假日调休智能更新功能；'
                '②加入了自动检查更新功能；③优化了液态玻璃的外观与动画',
          ),
        ),
        child: RepaintBoundary(
          key: boundaryKey,
          child: ClassManagerApp(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => precacheImage(
        const AssetImage(AppBackground.defaultWallpaperAsset),
        tester.element(find.byType(Scaffold).first),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> capture(String name) async {
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final backendPath = ui.ImageFilter.isShaderFilterSupported
            ? 'impeller/'
            : '';
        final file = File('artifacts/glass-preview/$backendPath$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('liquid-home');
    await tester.tap(find.byKey(const ValueKey('dock_tab_1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await capture('dock-sliding');
    await tester.pump(const Duration(milliseconds: 130));
    await capture('dock-arrival-squash');
    await tester.pump(const Duration(milliseconds: 170));
    await capture('dock-arrival-rebound');
    await tester.pumpAndSettle();
    await capture('liquid-discover');
    await tester.tap(find.byKey(const ValueKey('dock_tab_2')));
    await tester.pumpAndSettle();
    await capture('liquid-mine');
    // This is an explicitly invoked widget-test fixture outside test/.
    // ignore: invalid_use_of_visible_for_testing_member
    PackageInfo.setMockInitialValues(
      appName: '表里珞珈',
      packageName: 'com.classmanager.class_manager',
      version: '1.0.4',
      buildNumber: '4',
      buildSignature: '',
    );
    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle();
    await capture('update-dialog-liquid');
    await state.updateSettings(state.settings.copyWith(liquidGlass: false));
    await tester.pumpAndSettle();
    await capture('update-dialog-gaussian');
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    await state.updateSettings(state.settings.copyWith(liquidGlass: true));
    await tester.pumpAndSettle();
    await tester.tap(find.text('个性化设置'));
    await tester.pumpAndSettle();
    await capture('liquid-settings-on');
    final transparency = state.settings.cardTransparency;
    await state.updateSettings(state.settings.copyWith(cardTransparency: 1));
    await tester.pumpAndSettle();
    await capture('settings-transparency-100');
    await tester.drag(find.text('个人姓名'), const Offset(0, -220));
    await tester.pumpAndSettle();
    await capture('settings-scrolled-100');
    await tester.drag(find.byType(ListView).last, const Offset(0, 800));
    await tester.pumpAndSettle();
    await capture('settings-top-100');
    await state.updateSettings(
      state.settings.copyWith(cardTransparency: transparency),
    );
    await tester.pumpAndSettle();
    final gridSwitch = find.descendant(
      of: find.ancestor(
        of: find.text('显示网格'),
        matching: find.byType(GlassSwitchRow),
      ),
      matching: find.byType(Switch),
    );
    await tester.tap(gridSwitch);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pumpAndSettle();
    await capture('liquid-settings-off');
    await tester.tap(gridSwitch);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('dock_tab_0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('高级人工智能'));
    await tester.pumpAndSettle();
    await capture('liquid-course');
    await state.updateSettings(state.settings.copyWith(liquidGlass: false));
    await tester.pumpAndSettle();
    await capture('gaussian-course');
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
    await state.updateSettings(state.settings.copyWith(liquidGlass: true));
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('节假日与调休'));
    await tester.pumpAndSettle();
    await state.updateSettings(
      state.settings.copyWith(
        holidayAdjustmentEnabled: true,
        useNationalHolidays: true,
      ),
    );
    await tester.pumpAndSettle();
    await capture('liquid-adjustment-settings');
    await tester.tap(find.byKey(const ValueKey('add_adjustment')));
    await tester.pumpAndSettle();
    await capture('liquid-adjustment');
    await state.updateSettings(state.settings.copyWith(liquidGlass: false));
    await tester.pumpAndSettle();
    await capture('gaussian-adjustment');
  });
}
