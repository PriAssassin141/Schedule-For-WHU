import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:class_manager/main.dart';
import 'package:class_manager/screens/home_screen.dart';
import 'package:class_manager/state/app_state.dart';

/// 主页周次切换：上下拖动翻页（向上拖动 → 下一周，向下拖动 → 上一周），
/// 翻页时当前页与相邻页同时整页滑动。
void main() {
  testWidgets('上下拖动切换周次', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final state = AppState.memory();
    state.browseWeek = 5;

    await tester.pumpWidget(ClassManagerApp(state: state));
    await tester.pump();

    expect(find.text('5'), findsWidgets);

    // 拖动过程中：新旧两页同时渲染（整页滑动，无淡出）
    final gesture =
        await tester.startGesture(tester.getCenter(find.text('周一')));
    await gesture.moveBy(const Offset(0, -60));
    await tester.pump();
    expect(find.byType(FullWeekSchedule), findsNWidgets(2),
        reason: '翻页过程中应同时渲染当前页与相邻页');
    await gesture.up();
    await tester.pumpAndSettle();
    expect(state.browseWeek, 5, reason: '小幅拖动应回弹，不切周');

    // 向上快速拖动 → 下一周
    await tester.fling(find.text('周一'), const Offset(0, -220), 1200);
    await tester.pumpAndSettle();
    expect(state.browseWeek, 6, reason: '向上拖动应翻到下一周');

    // 向下快速拖动 → 上一周
    await tester.fling(find.text('周一'), const Offset(0, 220), 1200);
    await tester.pumpAndSettle();
    expect(state.browseWeek, 5, reason: '向下拖动应翻回上一周');

    // 首周不能再往上翻
    state.setBrowseWeek(1);
    await tester.pumpAndSettle();
    await tester.fling(find.text('周一'), const Offset(0, 220), 1200);
    await tester.pumpAndSettle();
    expect(state.browseWeek, 1, reason: '第 1 周向下拖动应保持不动');
  });
}
