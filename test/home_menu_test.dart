import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:class_manager/main.dart';
import 'package:class_manager/state/app_state.dart';

/// 主页菜单弹层：仅保留 导入课表 / 添加课程 / 开学日期，
/// 已删除「个性化设置」与「关于」入口（个性化设置仍可从“我的”进入）。
void main() {
  testWidgets('主页菜单不包含个性化设置与关于', (WidgetTester tester) async {
    final state = AppState.memory();
    state.browseWeek = 1;

    await tester.pumpWidget(ClassManagerApp(state: state));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();

    expect(find.textContaining('导入课表'), findsOneWidget);
    expect(find.text('添加课程'), findsOneWidget);
    expect(find.textContaining('开学日期'), findsOneWidget);
    expect(find.text('个性化设置'), findsNothing);
    expect(find.text('关于表里珞珈'), findsNothing);
    expect(find.text('关于课表精灵'), findsNothing);
  });
}
