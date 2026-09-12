import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:class_manager/state/app_state.dart';
import 'package:class_manager/widgets/campus_login_card.dart';

/// 校园网卡片：问号位于标题右侧；关闭自动登录后折叠为一行。
void main() {
  Future<AppState> pumpCard(WidgetTester tester, {bool autoLogin = true}) async {
    tester.view.physicalSize = const Size(1170, 2600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final state = AppState.memory();
    await state.updateSettings(state.settings.copyWith(
      campusAutoLogin: autoLogin,
      campusUser: '2026282210182',
      campusUserHistory: '["2026282210182"]',
    ));
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: CampusLoginCard()),
          ),
        ),
      ),
    );
    await tester.pump();
    return state;
  }

  testWidgets('说明问号在标题右侧', (WidgetTester tester) async {
    await pumpCard(tester);

    final title = tester.getRect(find.text('校园网自动登录'));
    final help = tester.getRect(find.byIcon(Icons.help_outline_rounded));
    // 同一行，且位于标题右侧
    expect((help.center.dy - title.center.dy).abs(), lessThan(8));
    expect(help.left, greaterThan(title.right - 4));
  });

  testWidgets('关闭自动登录后卡片折叠为一行', (WidgetTester tester) async {
    final state = await pumpCard(tester);

    final expandedHeight =
        tester.getSize(find.byType(CampusLoginCard)).height;
    // 展开时可见：账号输入框 / 自助服务系统
    expect(find.text('用户自助服务系统（下线终端 / 查看用量）'), findsOneWidget);
    expect(expandedHeight, greaterThan(150));

    // 关闭开关 → 折叠（动画结束后测量）
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(state.settings.campusAutoLogin, isFalse);

    final collapsedHeight =
        tester.getSize(find.byType(CampusLoginCard)).height;
    expect(collapsedHeight, lessThan(80), reason: '折叠后只剩标题一行');
    expect(collapsedHeight, lessThan(expandedHeight));

    // 再打开 → 恢复展开
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(state.settings.campusAutoLogin, isTrue);
    expect(tester.getSize(find.byType(CampusLoginCard)).height,
        greaterThan(150));
  });

  testWidgets('默认折叠时不显示表单', (WidgetTester tester) async {
    await pumpCard(tester, autoLogin: false);

    expect(find.text('校园网自动登录'), findsOneWidget);
    final height = tester.getSize(find.byType(CampusLoginCard)).height;
    expect(height, lessThan(80));
  });
}
