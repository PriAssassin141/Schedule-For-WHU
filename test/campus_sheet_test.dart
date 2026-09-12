import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:class_manager/services/campus_net.dart';
import 'package:class_manager/state/app_state.dart';
import 'package:class_manager/widgets/campus_login_card.dart';

/// 运营商与历史账号：使用玻璃弹层（而非不透明的下拉菜单）。
void main() {
  Future<AppState> pumpCard(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final state = AppState.memory();
    await state.updateSettings(state.settings.copyWith(
      campusAutoLogin: true,
      campusUser: '2026282210182',
      campusUserHistory: '["2026282210182","2024001234567"]',
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

  testWidgets('运营商选择为玻璃弹层并可切换', (WidgetTester tester) async {
    final state = await pumpCard(tester);

    // 不再使用 PopupMenuButton（旧实现是不透明深色菜单）
    expect(find.byType(PopupMenuButton), findsNothing);

    await tester.tap(find.text('校园网'));
    await tester.pumpAndSettle();

    expect(find.text('选择运营商'), findsOneWidget);
    expect(find.text('校园网（CERNET），一般选这个'), findsOneWidget);
    expect(find.text('电信'), findsOneWidget);

    await tester.tap(find.text('电信'));
    await tester.pumpAndSettle();
    expect(state.settings.campusService, CampusService.telecom.code);
  });

  testWidgets('历史账号为玻璃弹层，可选中并删除', (WidgetTester tester) async {
    final state = await pumpCard(tester);

    await tester.tap(find.byIcon(Icons.arrow_drop_down_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('历史账号'), findsOneWidget);
    expect(find.text('2026282210182'), findsWidgets);
    expect(find.text('2024001234567'), findsOneWidget);

    // 选中另一个账号 → 填入输入框
    await tester.tap(find.text('2024001234567'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '2024001234567'), findsOneWidget);

    // 再次打开并删除一个历史账号
    await tester.tap(find.byIcon(Icons.arrow_drop_down_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close_rounded).first);
    await tester.pumpAndSettle();
    expect(state.campusUserHistory.contains('2026282210182'), isFalse);
  });
}
