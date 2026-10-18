// Explicit visual QA only: flutter test --enable-impeller tools/agenda_preview_test.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:class_manager/main.dart';
import 'package:class_manager/models/agenda_event.dart';
import 'package:class_manager/models/course.dart';
import 'package:class_manager/state/app_state.dart';
import 'package:class_manager/widgets/app_background.dart';

class _Binding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

void main() {
  _Binding();
  testWidgets('三种视图及日程表单、详情的实际玻璃渲染预览', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      final bytes = ByteData.sublistView(
        await File('C:/Windows/Fonts/msyh.ttc').readAsBytes(),
      );
      for (final name in ['Ahem', 'Roboto', 'Microsoft YaHei']) {
        await (FontLoader(name)..addFont(Future.value(bytes))).load();
      }
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });
    final state = AppState.memory()
      ..browseWeek = 1
      ..courses = [
        Course(
          id: 1,
          name: '数理统计',
          teacher: '张老师',
          location: '新珈楼 B106',
          day: 1,
          startPeriod: 6,
          endPeriod: 7,
          weeks: '1-16',
          colorValue: 0xFF7894E8,
        ),
      ];
    for (final event in [
      AgendaEvent(
        name: '晨间运动',
        startAt: DateTime(2026, 9, 7, 7, 17),
        endAt: DateTime(2026, 9, 7, 7, 53),
        category: AgendaCategory.exercise,
        location: '桂园操场',
        description: '热身、慢跑，开启新的一天',
      ),
      AgendaEvent(
        name: '课题组进度讨论',
        startAt: DateTime(2026, 9, 7, 13, 17),
        endAt: DateTime(2026, 9, 7, 14, 23),
        category: AgendaCategory.meeting,
        location: '实验室 302',
        description: '带上阶段报告，讨论下一步实验计划',
      ),
      AgendaEvent(
        name: '晚间阅读',
        customCategory: '个人成长',
        customColorValue: 0xFFE181AA,
        startAt: DateTime(2026, 9, 7, 20, 7),
        endAt: DateTime(2026, 9, 7, 20, 43),
        category: AgendaCategory.study,
        location: '图书馆',
        description: '留出一段安静的专注时间',
      ),
    ]) {
      await state.saveAgendaEvent(event);
    }
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
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
            key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final picture = await boundary.toImage(pixelRatio: 2);
        final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
        final file = File('artifacts/agenda-preview/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        picture.dispose();
      });
    }

    Future<ByteData> rgbaFrame() async {
      late ByteData bytes;
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final picture = await boundary.toImage(pixelRatio: 1);
        bytes = (await picture.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        picture.dispose();
      });
      return bytes;
    }

    await capture('courses-liquid');
    final beforeMenu = await rgbaFrame();
    await tester.tap(find.byKey(const ValueKey('home_view_selector')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 48));
    await capture('view-menu-opening-48ms');
    final openingMenu = await rgbaFrame();
    final menuRect = tester.getRect(
      find.byKey(const ValueKey('home_view_menu_glass')),
    );
    final pixelWidth =
        (tester.view.physicalSize.width / tester.view.devicePixelRatio).round();
    // Rounded corners must not acquire a dark rectangular magnifier footprint
    // while the popup's height is changing.
    for (final point in [
      menuRect.topLeft + const Offset(1, 1),
      menuRect.topRight + const Offset(-2, 1),
    ]) {
      final offset = (point.dy.floor() * pixelWidth + point.dx.floor()) * 4;
      for (var channel = 0; channel < 3; channel++) {
        expect(
          (openingMenu.getUint8(offset + channel) -
                  beforeMenu.getUint8(offset + channel))
              .abs(),
          lessThanOrEqualTo(6),
          reason: 'menu corner backdrop leaked during opening at $point',
        );
      }
    }
    await tester.pump(const Duration(milliseconds: 72));
    await capture('view-menu-opening-120ms');
    await tester.pumpAndSettle();
    await capture('view-menu-liquid');
    final settledMenu = await rgbaFrame();
    // Sample a clear part of the first row: material should already be present
    // during opening, without a final-frame switch from clear to frosted.
    for (final dx in [55, 75, 95]) {
      final point = menuRect.topRight + Offset(-dx.toDouble(), 28);
      final offset = (point.dy.floor() * pixelWidth + point.dx.floor()) * 4;
      for (var channel = 0; channel < 3; channel++) {
        expect(
          (openingMenu.getUint8(offset + channel) -
                  settledMenu.getUint8(offset + channel))
              .abs(),
          lessThanOrEqualTo(16),
          reason: 'menu material changed at end of opening at $point',
        );
      }
    }
    await tester.tapAt(
      tester.getCenter(find.byKey(const ValueKey('home_view_selector'))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await capture('view-menu-closing-80ms');
    await tester.pumpAndSettle();
    for (final liquid in [true, false]) {
      await state.updateSettings(state.settings.copyWith(liquidGlass: liquid));
      final name = liquid ? 'liquid' : 'gaussian';
      for (final mode in [HomeViewMode.agenda, HomeViewMode.combined]) {
        await state.setHomeViewMode(mode);
        state.setAgendaDate(DateTime(2026, 9, 7));
        await tester.pumpAndSettle();
        await capture('${mode.name}-$name');
      }
    }
    await state.updateSettings(state.settings.copyWith(liquidGlass: true));
    await state.setHomeViewMode(HomeViewMode.agenda);
    state.setAgendaDate(DateTime(2026, 9, 8));
    await tester.pumpAndSettle();
    await capture('empty-liquid');
    await state.updateSettings(state.settings.copyWith(liquidGlass: false));
    await tester.pumpAndSettle();
    await capture('empty-gaussian');
    await state.updateSettings(state.settings.copyWith(liquidGlass: true));
    state.setAgendaDate(DateTime(2026, 9, 7));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('agenda_event_2')));
    await tester.pumpAndSettle();
    await capture('event-info-liquid');
    await tester.tap(find.byKey(const ValueKey('agenda_info_edit')));
    await tester.pumpAndSettle();
    await capture('event-editor-liquid');
    await tester.ensureVisible(
      find.byKey(const ValueKey('agenda_custom_color')),
    );
    await tester.pumpAndSettle();
    await capture('event-colors-liquid');
    await tester.ensureVisible(find.byKey(const ValueKey('agenda_category')));
    await tester.tap(find.byKey(const ValueKey('agenda_category')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('agenda_add_category')),
    );
    await tester.pumpAndSettle();
    await capture('category-options-liquid');
    await tester.tap(find.byKey(const ValueKey('agenda_add_category')));
    await tester.pumpAndSettle();
    await capture('custom-category-liquid');
  });
}
