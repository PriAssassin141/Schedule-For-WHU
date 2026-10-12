import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:class_manager/main.dart';
import 'package:class_manager/models/app_settings.dart';
import 'package:class_manager/models/course.dart';
import 'package:class_manager/models/schedule_adjustment.dart';
import 'package:class_manager/screens/course_edit_screen.dart';
import 'package:class_manager/screens/schedule_adjustment_screen.dart';
import 'package:class_manager/state/app_state.dart';

void main() {
  testWidgets('点击日期直接编辑国家建议，可保存为手动正常上课', (tester) async {
    final state = AppState.memory()
      ..settings = AppSettings(holidayAdjustmentEnabled: true)
      ..browseWeek = 2
      ..courses = [Course(name: '周日原课', day: 7, startPeriod: 1, endPeriod: 2)];
    await tester.pumpWidget(ClassManagerApp(state: state));
    await tester.pumpAndSettle();
    await tester.tap(find.text('9/20'));
    await tester.pumpAndSettle();
    expect(find.text('设置日期安排'), findsOneWidget);
    expect(find.text('2026-09-20 周日'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('adjustment_type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('按原课表上课').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save_adjustment')));
    await tester.pumpAndSettle();
    expect(
      state.settings.scheduleAdjustments.single.type,
      AdjustmentType.normal,
    );
    expect(state.coursesOn(7, 2).single.name, '周日原课');
    expect(tester.takeException(), isNull);
  });

  Future<void> openSettings(WidgetTester tester, AppState state) async {
    await tester.pumpWidget(ClassManagerApp(state: state));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('节假日与调休'));
    await tester.pumpAndSettle();
  }

  testWidgets('主页入口可开启重排并手动添加、删除停课日期', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = AppState.memory()..browseWeek = 1;
    await openSettings(tester, state);
    expect(find.byType(ScheduleAdjustmentScreen), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('holiday_adjustment_enabled')));
    await tester.pumpAndSettle();
    expect(state.settings.holidayAdjustmentEnabled, isTrue);
    await tester.tap(find.byKey(const ValueKey('add_adjustment')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '院系停课通知');
    await tester.tap(find.byKey(const ValueKey('save_adjustment')));
    await tester.pumpAndSettle();
    expect(state.settings.scheduleAdjustments.single.date, '2026-09-07');
    expect(find.textContaining('院系停课通知'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();
    expect(state.settings.scheduleAdjustments, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('国家补课卡片先显示实际日期，点击编辑仍修改原课程星期', (tester) async {
    final original = Course(
      id: 9,
      name: '第五周周二',
      day: 2,
      startPeriod: 1,
      endPeriod: 3,
      weeks: '5',
    );
    final state = AppState.memory()
      ..settings = AppSettings(holidayAdjustmentEnabled: true)
      ..browseWeek = 2
      ..courses = [original];
    await tester.pumpWidget(ClassManagerApp(state: state));
    await tester.pumpAndSettle();
    expect(find.text('补周二'), findsOneWidget);
    expect(find.text('第五周周二'), findsOneWidget);
    final rect = tester.getRect(find.text('第五周周二'));
    final sunday = tester.getRect(find.text('周日'));
    expect((rect.center.dx - sunday.center.dx).abs(), lessThan(4));
    await tester.tap(find.text('第五周周二'));
    await tester.pumpAndSettle();
    expect(find.byType(CourseEditScreen), findsNothing);
    expect(find.text('2026-09-20 周日'), findsOneWidget);
    expect(find.text('2026-10-06 周二'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('course_info_edit')));
    await tester.pumpAndSettle();
    final editor = tester.widget<CourseEditScreen>(
      find.byType(CourseEditScreen),
    );
    expect(identical(editor.course, original), isTrue);
    expect(editor.course!.day, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('分享文本使用重排后的课程和补课说明', (tester) async {
    final state = AppState.memory()
      ..settings = AppSettings(holidayAdjustmentEnabled: true)
      ..browseWeek = 2
      ..courses = [
        Course(name: '第五周周二', day: 2, startPeriod: 1, endPeriod: 3, weeks: '5'),
      ];
    await tester.pumpWidget(ClassManagerApp(state: state));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.ios_share_rounded));
    await tester.pumpAndSettle();
    expect(find.textContaining('周日 9/20（补 10/6 的课）'), findsOneWidget);
    expect(find.textContaining('第五周周二（5周）'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('假日表头标注停课，关闭重排恢复卡片', (tester) async {
    final state = AppState.memory()
      ..settings = AppSettings(holidayAdjustmentEnabled: true)
      ..browseWeek = 3
      ..courses = [Course(name: '周五课', day: 5, startPeriod: 1, endPeriod: 3)];
    await tester.pumpWidget(ClassManagerApp(state: state));
    await tester.pumpAndSettle();
    expect(find.text('停课'), findsNWidgets(3));
    expect(find.text('周五课'), findsNothing);
    await state.updateSettings(
      state.settings.copyWith(holidayAdjustmentEnabled: false),
    );
    await tester.pumpAndSettle();
    expect(find.text('停课'), findsNothing);
    expect(find.text('周五课'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('未来年份提供法定节日，明确调休需手动补充', (tester) async {
    final state = AppState.memory()
      ..settings = AppSettings(startDate: '2027-09-06')
      ..browseWeek = 1;
    await openSettings(tester, state);
    await tester.scrollUntilVisible(
      find.text('具体调休请按学校通知手动设置。'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('具体调休请按学校通知手动设置。'), findsOneWidget);
    expect(find.textContaining('国务院通知'), findsNothing);
    expect(find.textContaining('内置'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
