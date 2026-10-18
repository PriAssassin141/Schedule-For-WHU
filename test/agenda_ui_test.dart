import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:class_manager/main.dart';
import 'package:class_manager/models/agenda_event.dart';
import 'package:class_manager/models/course.dart';
import 'package:class_manager/screens/agenda_edit_screen.dart';
import 'package:class_manager/state/app_state.dart';
import 'package:class_manager/widgets/course_info_dialog.dart';
import 'package:class_manager/widgets/glass.dart';

void main() {
  final day = DateTime(2026, 9, 7);
  Future<AppState> pump(
    WidgetTester tester, {
    bool liquid = true,
    bool seeded = true,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final state = AppState.memory()
      ..browseWeek = 1
      ..courses = [
        Course(
          id: 1,
          name: '数理统计',
          location: '教学楼',
          day: 1,
          startPeriod: 6,
          endPeriod: 7,
          weeks: '1',
        ),
      ];
    await state.updateSettings(state.settings.copyWith(liquidGlass: liquid));
    if (seeded) {
      await state.saveAgendaEvent(
        AgendaEvent(
          name: '课题讨论',
          startAt: DateTime(2026, 9, 7, 13, 17),
          endAt: DateTime(2026, 9, 7, 14, 23),
          category: AgendaCategory.meeting,
          location: '实验室',
          description: '准备汇报材料',
        ),
      );
    }
    await tester.pumpWidget(ClassManagerApp(state: state));
    await tester.pumpAndSettle();
    return state;
  }

  Future<void> mode(WidgetTester tester, AppState state, String value) async {
    await tester.tap(find.byKey(const ValueKey('home_view_selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('home_mode_$value')));
    await tester.pumpAndSettle();
    state.setAgendaDate(day);
    await tester.pumpAndSettle();
  }

  Future<void> pickTime(
    WidgetTester tester,
    String which,
    int hour,
    int minute,
  ) async {
    await tester.tap(find.byKey(ValueKey('agenda_${which}_time')));
    await tester.pumpAndSettle();
    tester
        .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
        .onDateTimeChanged(DateTime(2026, 9, 7, hour, minute));
    await tester.pump();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
  }

  Future<void> pickDate(
    WidgetTester tester,
    String which,
    DateTime value,
  ) async {
    await tester.tap(find.byKey(ValueKey('agenda_${which}_date')));
    await tester.pumpAndSettle();
    tester
        .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
        .onDateChanged(value);
    await tester.pump();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
  }

  testWidgets('窄屏视图下拉位于三个按钮右侧，展开后可切换且不占独立行', (tester) async {
    final state = await pump(tester);
    tester.view.physicalSize = const Size(960, 1920);
    state.setBrowseWeek(22);
    await tester.pumpAndSettle();
    final selector = tester.getRect(
      find.byKey(const ValueKey('home_view_selector')),
    );
    final menu = tester.getRect(find.byIcon(Icons.menu_rounded));
    expect(selector.left, greaterThan(menu.right));
    expect(selector.center.dy, closeTo(menu.center.dy, 2));
    expect(
      tester
          .getCenter(
            find.descendant(
              of: find.byKey(const ValueKey('home_view_selector')),
              matching: find.text('课程'),
            ),
          )
          .dy,
      closeTo(selector.center.dy, 1),
    );
    expect(find.byKey(const ValueKey('home_mode_agenda')), findsNothing);
    await mode(tester, state, 'agenda');
    expect(state.settings.homeViewMode, HomeViewMode.agenda);
    expect(find.byKey(const ValueKey('agenda_previous_week')), findsNothing);
    expect(find.byKey(const ValueKey('agenda_next_week')), findsNothing);
    expect(find.textContaining(' — '), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('两种玻璃模式下空日程图标、提示、按钮及日期文字居中，日期块更紧凑', (tester) async {
    for (final liquid in [true, false]) {
      final state = await pump(tester, liquid: liquid, seeded: false);
      await mode(tester, state, 'agenda');
      final panel = tester.getRect(
        find.byKey(const ValueKey('agenda_empty_state')),
      );
      for (final finder in [
        find.text('这一天还没有日程'),
        find.text('添加日程'),
        find.byIcon(Icons.event_available_outlined),
      ]) {
        expect(tester.getCenter(finder).dx, closeTo(panel.center.dx, 1));
      }
      final tile = find.byKey(const ValueKey('agenda_day_1'));
      final rect = tester.getRect(tile);
      expect(rect.height, lessThanOrEqualTo(54));
      for (final label in ['周一', '7']) {
        final text = find.descendant(of: tile, matching: find.text(label));
        expect(tester.getCenter(text).dx, closeTo(rect.center.dx, 1));
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('三视图过滤正确，混合视图保留全部安排并提示重叠，课程仍先打开信息卡', (tester) async {
    final state = await pump(tester);
    expect(find.text('数理统计'), findsOneWidget);
    expect(find.text('课题讨论'), findsNothing);
    await mode(tester, state, 'agenda');
    expect(find.text('课题讨论'), findsOneWidget);
    expect(find.text('数理统计'), findsNothing);
    await mode(tester, state, 'combined');
    expect(find.text('数理统计'), findsOneWidget);
    expect(find.text('课题讨论'), findsOneWidget);
    expect(find.text('时间重叠'), findsNWidgets(2));
    await tester.tap(find.byKey(const ValueKey('agenda_course_1')));
    await tester.pumpAndSettle();
    expect(find.byType(CourseInfoDialog), findsOneWidget);
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
    await mode(tester, state, 'courses');
    expect(find.text('课题讨论'), findsNothing);
    expect(state.courses.single.startPeriod, 6);
    expect(state.agendaEvents.length, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('两种玻璃模式均能新增任意时分日程，名称校验、类型、地点及描述完整保存', (tester) async {
    for (final liquid in [true, false]) {
      final state = await pump(tester, liquid: liquid, seeded: false);
      await mode(tester, state, 'agenda');
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save_agenda')));
      await tester.pumpAndSettle();
      expect(find.text('请填写日程名称'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('agenda_name')), '午间运动');
      await pickTime(tester, 'start', 13, 17);
      await pickDate(tester, 'end', day);
      await pickTime(tester, 'end', 14, 23);
      await tester.ensureVisible(find.byKey(const ValueKey('agenda_category')));
      await tester.tap(find.byKey(const ValueKey('agenda_category')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('运动'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('agenda_location')));
      await tester.enterText(
        find.byKey(const ValueKey('agenda_location')),
        '体育场',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('agenda_description')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('agenda_description')),
        '热身后跑步',
      );
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save_agenda')));
      await tester.pumpAndSettle();
      final event = state.agendaEvents.single;
      expect(event.name, '午间运动');
      expect(event.startAt, DateTime(2026, 9, 7, 13, 17));
      expect(event.endAt, DateTime(2026, 9, 7, 14, 23));
      expect(event.category, AgendaCategory.exercise);
      expect(event.location, '体育场');
      expect(event.description, '热身后跑步');
      expect(find.byType(AgendaEditScreen), findsNothing);
      expect(find.text('午间运动'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('保存自定义类型与任意颜色，编辑恢复且新日程可复用类型', (tester) async {
    final state = await pump(tester, seeded: false);
    await mode(tester, state, 'agenda');
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('agenda_name')), '社团排练');
    expect(find.textContaining('可精确设置到分钟'), findsNothing);
    expect(find.byKey(const ValueKey('agenda_add_category')), findsNothing);
    await tester.ensureVisible(find.byKey(const ValueKey('agenda_category')));
    await tester.tap(find.byKey(const ValueKey('agenda_category')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('agenda_add_category')),
    );
    expect(
      tester.getTopLeft(find.text('增加自定义类型')).dy,
      greaterThan(tester.getBottomLeft(find.text('其他')).dy),
    );
    await tester.tap(find.byKey(const ValueKey('agenda_add_category')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('agenda_custom_category_name')),
      '  社团  ',
    );
    await tester.tap(find.text('保存类型'));
    await tester.pumpAndSettle();
    expect(state.settings.agendaCustomCategories, ['社团']);
    await tester.ensureVisible(
      find.byKey(const ValueKey('agenda_custom_color')),
    );
    await tester.tap(find.byKey(const ValueKey('agenda_custom_color')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('agenda_hex_color')),
      '#12ABEF',
    );
    await tester.tap(find.text('应用颜色'));
    await tester.pumpAndSettle();
    tester.testTextInput.hide();
    await tester.tap(find.byKey(const ValueKey('save_agenda')));
    await tester.pumpAndSettle();
    expect(state.agendaEvents.single.categoryLabel, '社团');
    expect(state.agendaEvents.single.colorValue, 0xFF12ABEF);
    await tester.tap(find.byKey(const ValueKey('agenda_event_1')));
    await tester.pumpAndSettle();
    expect(find.text('社团'), findsNWidgets(2));
    await tester.tap(find.byKey(const ValueKey('agenda_info_edit')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('agenda_category')));
    expect(find.text('社团'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('save_agenda')));
    await tester.pumpAndSettle();
    expect(state.agendaEvents.single.colorValue, 0xFF12ABEF);
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('agenda_category')));
    await tester.tap(find.byKey(const ValueKey('agenda_category')));
    await tester.pumpAndSettle();
    expect(find.text('社团'), findsOneWidget);
    await tester.tap(find.text('社团'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('日期玻璃连续滑动并到位回弹，关闭液态立即取消且无卡片阴影', (tester) async {
    final state = await pump(tester, seeded: false);
    await mode(tester, state, 'agenda');
    expect(find.text('回到今天'), findsOneWidget);
    final indicator = find.byKey(const ValueKey('agenda_date_indicator'));
    final initial = tester.getCenter(indicator).dx;
    await tester.tap(find.byKey(const ValueKey('agenda_day_5')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.getCenter(indicator).dx, greaterThan(initial));
    expect(
      tester.getCenter(indicator).dx,
      lessThan(tester.getCenter(find.byKey(const ValueKey('agenda_day_5'))).dx),
    );
    final scales = <double>[];
    for (var i = 0; i < 65; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      scales.add(
        tester
            .widget<Transform>(
              find.byKey(const ValueKey('agenda_date_deformation')),
            )
            .transform
            .storage[0],
      );
    }
    expect(scales.any((s) => s < 0.97), isTrue);
    expect(scales.any((s) => s > 1.008), isTrue);
    await tester.tap(find.byKey(const ValueKey('agenda_day_2')));
    await tester.pump(const Duration(milliseconds: 48));
    await state.updateSettings(state.settings.copyWith(liquidGlass: false));
    await tester.pumpAndSettle();
    expect(indicator, findsNothing);
    for (var i = 1; i <= 7; i++) {
      expect(
        tester
            .widget<LiquidGlass>(find.byKey(ValueKey('agenda_day_$i')))
            .showShadow,
        isFalse,
      );
    }
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('菜单玻璃始终可见，固定锚点展开并折叠关闭，无透明度跳变', (tester) async {
    final state = await pump(tester);
    final selector = find.byKey(const ValueKey('home_view_selector'));
    final menu = find.byKey(const ValueKey('home_view_menu_glass'));
    final reveal = find.byKey(const ValueKey('home_view_menu_reveal'));
    await tester.tapAt(tester.getCenter(selector));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 48));
    final early = tester.getRect(reveal);
    expect(early.height, inExclusiveRange(0, 156));
    expect(early.top, closeTo(tester.getRect(selector).bottom + 6, 0.01));
    expect(
      find.ancestor(of: menu, matching: find.byType(FadeTransition)),
      findsNothing,
    );
    expect(
      find.ancestor(of: menu, matching: find.byType(Opacity)),
      findsNothing,
    );
    final heights = <double>[];
    for (var i = 0; i < 24; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      final rect = tester.getRect(reveal);
      heights.add(rect.height);
      expect(rect.topLeft, early.topLeft);
      expect(rect.width, early.width);
    }
    expect(heights.any((h) => h > 156.01), isTrue);
    expect(heights.last, closeTo(156, 0.001));
    // Clicking the same button hits the transparent dismiss barrier.
    await tester.tapAt(tester.getCenter(selector));
    await tester.pump();
    expect(tester.getSize(reveal).height, closeTo(156, 0.01));
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.getSize(reveal).height, inExclusiveRange(40, 120));
    await tester.pump(const Duration(milliseconds: 120));
    expect(menu, findsNothing);
    expect(state.settings.homeViewMode, HomeViewMode.courses);
    expect(tester.takeException(), isNull);
  });

  testWidgets('展开途中关闭保持姿态连续，选中后折叠完再切换页面', (tester) async {
    final state = await pump(tester);
    final selector = find.byKey(const ValueKey('home_view_selector'));
    final reveal = find.byKey(const ValueKey('home_view_menu_reveal'));
    final menu = find.byKey(const ValueKey('home_view_menu_glass'));
    await tester.tapAt(tester.getCenter(selector));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 48));
    final before = tester.getSize(reveal).height;
    await tester.tapAt(tester.getCenter(selector));
    await tester.pump();
    expect(tester.getSize(reveal).height, closeTo(before, 0.01));
    await tester.pump(const Duration(milliseconds: 32));
    expect(tester.getSize(reveal).height, lessThan(before));
    await tester.pumpAndSettle();
    expect(menu, findsNothing);
    await state.updateSettings(state.settings.copyWith(jellyEffect: false));
    await tester.pump();
    await tester.tapAt(tester.getCenter(selector));
    await tester.pump();
    for (var i = 0; i < 22; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.getSize(reveal).height, lessThanOrEqualTo(156));
    }
    await tester.tap(find.byKey(const ValueKey('home_mode_agenda')));
    await tester.pump();
    expect(state.settings.homeViewMode, HomeViewMode.courses);
    await tester.pumpAndSettle();
    expect(state.settings.homeViewMode, HomeViewMode.agenda);
    expect(menu, findsNothing);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('高斯菜单正常折叠，减少动态效果时菜单立即开合', (tester) async {
    final state = await pump(tester, liquid: false);
    final selector = find.byKey(const ValueKey('home_view_selector'));
    final menu = find.byKey(const ValueKey('home_view_menu_glass'));
    final reveal = find.byKey(const ValueKey('home_view_menu_reveal'));
    await tester.tapAt(tester.getCenter(selector));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 48));
    expect(tester.getSize(reveal).height, inExclusiveRange(0, 156));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(8, 400));
    await tester.pumpAndSettle();
    expect(menu, findsNothing);
    await state.updateSettings(state.settings.copyWith(liquidGlass: true));
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(selector));
    await tester.pumpAndSettle();
    expect(tester.getSize(reveal).height, 156);
    await tester.tapAt(tester.getCenter(selector));
    await tester.pumpAndSettle();
    expect(menu, findsNothing);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });
  testWidgets('日程详情先查看再编辑，删除需要确认，取消保留记录', (tester) async {
    final state = await pump(tester);
    await mode(tester, state, 'agenda');
    await tester.tap(find.byKey(const ValueKey('agenda_event_1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('agenda_info_dialog')), findsOneWidget);
    expect(find.text('2026-09-07 13:17'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('agenda_info_edit')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('agenda_name')), '修改后的讨论');
    await tester.tap(find.byKey(const ValueKey('save_agenda')));
    await tester.pumpAndSettle();
    expect(state.agendaEvents.single.name, '修改后的讨论');
    await tester.tap(find.byKey(const ValueKey('agenda_event_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('agenda_info_delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(state.agendaEvents.length, 1);
    await tester.tap(find.byKey(const ValueKey('agenda_info_delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(state.agendaEvents, isEmpty);
    expect(state.courses.length, 1);
    expect(find.byKey(const ValueKey('agenda_info_dialog')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('结束早于开始会阻止保存，跨夜日期明确设置后正确保存', (tester) async {
    final state = await pump(tester, seeded: false);
    await mode(tester, state, 'agenda');
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('agenda_name')), '夜间工作');
    await pickTime(tester, 'start', 23, 47);
    await pickDate(tester, 'end', day);
    await pickTime(tester, 'end', 0, 13);
    await tester.tap(find.byKey(const ValueKey('save_agenda')));
    await tester.pumpAndSettle();
    expect(find.textContaining('结束时间必须晚于开始时间'), findsOneWidget);
    expect(state.agendaEvents, isEmpty);
    await pickDate(tester, 'end', DateTime(2026, 9, 8));
    await tester.tap(find.byKey(const ValueKey('save_agenda')));
    await tester.pumpAndSettle();
    expect(state.agendaEvents.single.endAt, DateTime(2026, 9, 8, 0, 13));
    await tester.tap(find.byKey(const ValueKey('agenda_day_2')));
    await tester.pumpAndSettle();
    expect(find.text('夜间工作'), findsOneWidget);
    expect(find.text('跨日'), findsOneWidget);
    expect(find.text('00:13'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('左右滑动日期并回到今天；学期外日程仍可见', (tester) async {
    final state = await pump(tester);
    await mode(tester, state, 'combined');
    await tester.drag(
      find.byKey(const ValueKey('agenda_date_strip')),
      const Offset(-300, 0),
    );
    await tester.pumpAndSettle();
    expect(state.agendaDate, DateTime(2026, 9, 14));
    expect(find.text('课题讨论'), findsNothing);
    await tester.drag(
      find.byKey(const ValueKey('agenda_date_strip')),
      const Offset(300, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('课题讨论'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('agenda_today')));
    await tester.pumpAndSettle();
    expect(state.agendaDate, calendarDate(DateTime.now()));
    await state.saveAgendaEvent(
      AgendaEvent(
        name: '未来出行',
        startAt: DateTime(2036, 2, 4, 9, 7),
        endAt: DateTime(2036, 2, 4, 10, 13),
      ),
    );
    state.setAgendaDate(DateTime(2036, 2, 4));
    await tester.pumpAndSettle();
    expect(find.text('未来出行'), findsOneWidget);
    expect(find.text('数理统计'), findsNothing);
    for (final date in [
      DateTime(2000),
      DateTime(2100, 12, 31),
      DateTime(2026, 9, 7),
    ]) {
      state.setAgendaDate(date);
      await tester.pumpAndSettle();
      final tile = find
          .byKey(ValueKey('agenda_day_${date.weekday}'))
          .hitTestable();
      expect(
        find.descendant(of: tile, matching: find.text('${date.day}')),
        findsOneWidget,
      );
    }
    expect(tester.takeException(), isNull);
  });
}
