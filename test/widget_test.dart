import 'package:flutter_test/flutter_test.dart';

import 'package:class_manager/main.dart';
import 'package:class_manager/models/course.dart';
import 'package:class_manager/models/exam.dart';
import 'package:class_manager/state/app_state.dart';
import 'package:class_manager/utils/weeks.dart';

void main() {
  testWidgets('主页显示周次、日期栏与课程卡片', (WidgetTester tester) async {
    final state = AppState.memory();
    state.courses = [
      Course(
          name: '数理统计(05)',
          teacher: '邓爱姣',
          location: '网安基地, 新珈楼B201',
          day: 1,
          startPeriod: 6,
          endPeriod: 7,
          weeks: '1-16',
          colorValue: 0xFF3FC9A2),
    ];
    state.browseWeek = 1;
    state.selectedDay = 1;

    await tester.pumpWidget(ClassManagerApp(state: state));
    await tester.pump();

    expect(find.text('第'), findsWidgets);
    expect(find.text('周'), findsWidgets);
    expect(find.text('周一'), findsOneWidget);
    expect(find.text('数理统计(05)'), findsOneWidget);
    expect(find.text('网安基地, 新珈楼B201'), findsOneWidget);
    expect(find.text('主页'), findsOneWidget);
    expect(find.text('发现'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
  });

  testWidgets('发现页显示考试倒计时', (WidgetTester tester) async {
    final state = AppState.memory();
    state.courses = [];
    state.exams = [
      Exam(
        name: '期末考试',
        location: '新珈楼B201',
        date: fmtDate(DateTime.now().add(const Duration(days: 3))),
        startTime: '14:00',
        endTime: '15:40',
      ),
    ];
    state.browseWeek = 1;

    await tester.pumpWidget(ClassManagerApp(state: state));
    await tester.pump();

    await tester.tap(find.text('发现'));
    await tester.pumpAndSettle();

    expect(find.text('考试倒计时'), findsOneWidget);
    expect(find.text('期末考试'), findsOneWidget);
    expect(find.text('还有 3 天'), findsOneWidget);
  });
}
