// Run explicitly: flutter test --no-pub tools/glass_preview_test.dart
// This writes visual QA images only inside artifacts/glass-preview/.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:class_manager/main.dart';
import 'package:class_manager/models/course.dart';
import 'package:class_manager/state/app_state.dart';
import 'package:class_manager/widgets/app_background.dart';

void main() {
  testWidgets('导出课程信息卡与调休编辑的玻璃预览', (tester) async {
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
    await state.updateSettings(
      state.settings.copyWith(refraction: 0.7, dispersion: 0.4),
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: ClassManagerApp(state: state),
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
        final file = File('artifacts/glass-preview/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

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
    await tester.tap(find.byKey(const ValueKey('add_adjustment')));
    await tester.pumpAndSettle();
    await capture('liquid-adjustment');
    await state.updateSettings(state.settings.copyWith(liquidGlass: false));
    await tester.pumpAndSettle();
    await capture('gaussian-adjustment');
  });
}
