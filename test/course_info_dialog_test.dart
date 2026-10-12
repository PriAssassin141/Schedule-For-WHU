import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:class_manager/main.dart';
import 'package:class_manager/models/course.dart';
import 'package:class_manager/screens/course_edit_screen.dart';
import 'package:class_manager/state/app_state.dart';
import 'package:class_manager/widgets/course_info_dialog.dart';
import 'package:class_manager/widgets/glass.dart';

void main() {
  Course sample() => Course(
    id: 1,
    name: '高级人工智能',
    location: '新珈楼-B106',
    teacher: '艾浩军',
    note: '携带笔记本电脑',
    day: 1,
    startPeriod: 6,
    endPeriod: 7,
    weeks: '1-16',
    colorValue: 0xFF7894E8,
  );

  Future<AppState> openCard(WidgetTester tester, {Course? course}) async {
    final state = AppState.memory()
      ..browseWeek = 1
      ..courses = [course ?? sample()];
    await tester.pumpWidget(ClassManagerApp(state: state));
    await tester.pumpAndSettle();
    await tester.tap(find.text(state.courses.single.name));
    await tester.pumpAndSettle();
    return state;
  }

  testWidgets('点击卡片先查看信息，点击编辑才打开原课程编辑页', (tester) async {
    final state = await openCard(tester);
    expect(find.byType(CourseInfoDialog), findsOneWidget);
    expect(find.byType(CourseEditScreen), findsNothing);
    expect(find.text('新珈楼-B106'), findsWidgets);
    expect(find.text('艾浩军'), findsOneWidget);
    expect(find.text('1-16周'), findsOneWidget);
    expect(find.text('第6～7节 · 14:05～15:40'), findsOneWidget);
    expect(find.text('2026-09-07 周一'), findsOneWidget);
    expect(find.text('携带笔记本电脑'), findsOneWidget);
    expect(
      tester.widget<Dialog>(find.byType(Dialog)).backgroundColor,
      Colors.transparent,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('course_info_dialog')),
        matching: find.byType(LiquidGlass),
      ),
      findsWidgets,
    );
    await tester.tap(find.byKey(const ValueKey('course_info_edit')));
    await tester.pumpAndSettle();
    expect(find.byType(CourseInfoDialog), findsNothing);
    final editor = tester.widget<CourseEditScreen>(
      find.byType(CourseEditScreen),
    );
    expect(identical(editor.course, state.courses.single), isTrue);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(CourseInfoDialog), findsNothing);
    expect(find.text('高级人工智能'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('关闭和点击遮罩仅关闭卡片，不修改课程或打开编辑页', (tester) async {
    final state = await openCard(tester);
    final before = state.courses.single.toMap();
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
    expect(find.byType(CourseInfoDialog), findsNothing);
    expect(find.byType(CourseEditScreen), findsNothing);
    await tester.tap(find.text('高级人工智能'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byType(CourseInfoDialog), findsNothing);
    expect(state.courses.single.toMap(), before);
    expect(tester.takeException(), isNull);
  });

  testWidgets('删除课程先确认，取消保留卡片，确认后删除并返回课表', (tester) async {
    final state = await openCard(tester);
    await tester.tap(find.byKey(const ValueKey('course_info_delete')));
    await tester.pumpAndSettle();
    expect(find.textContaining('所有周次安排都会删除'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(state.courses.length, 1);
    expect(find.byType(CourseInfoDialog), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('course_info_delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(state.courses, isEmpty);
    expect(find.byType(CourseInfoDialog), findsNothing);
    expect(find.byType(CourseEditScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('窄屏和较大字体下长文本可滚动，编辑按钮始终可见', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final course = sample()
      ..name = '高级人工智能与机器学习研究方法专题课程'
      ..location = '武汉大学新珈楼B106教室，入口位于东侧楼梯附近'
      ..note = List.filled(20, '请携带笔记本电脑和课堂资料。').join('\n');
    final state = AppState.memory()..courses = [course];
    // 单独验证信息卡的小屏大字体布局。
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          theme: ThemeData.dark(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(1.5)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showCourseInfoDialog(
                  context,
                  state.occurrencesOn(state.dateOf(1, 1)).single,
                ),
                child: const Text('查看课程'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('查看课程'));
    await tester.pumpAndSettle();
    final card = find.byKey(const ValueKey('course_info_dialog'));
    final size = tester.getSize(card);
    expect(size.width, lessThanOrEqualTo(320));
    expect(
      find.byKey(const ValueKey('course_info_edit')).hitTestable(),
      findsOneWidget,
    );
    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('空地点与教师显示未填写，空备注不显示额外行', (tester) async {
    await openCard(
      tester,
      course: sample()
        ..location = ''
        ..teacher = ''
        ..note = ''
        ..weeks = '',
    );
    expect(find.text('未填写'), findsNWidgets(2));
    expect(find.text('全周'), findsOneWidget);
    expect(find.text('备注'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
