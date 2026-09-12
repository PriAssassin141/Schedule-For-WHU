import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:class_manager/main.dart';
import 'package:class_manager/state/app_state.dart';
import 'package:class_manager/utils/greeting.dart';

/// “我的”页：问候语 + 校园网登录 + 个性化入口 +
/// 「获取源码 / 联系作者 / 关于软件 / 检查更新 / 隐私政策」。
void main() {
  /// 页面较长（含校园网卡片），用高视口保证全部内容被构建。
  Future<void> openMine(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 4200);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final state = AppState.memory();
    state.browseWeek = 1;
    await tester.pumpWidget(ClassManagerApp(state: state));
    await tester.pump();
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
  }

  testWidgets('我的页：按时间与姓名问候', (WidgetTester tester) async {
    final state = AppState.memory();
    state.browseWeek = 1;
    await state.updateSettings(state.settings.copyWith(userName: '闫梓萱'));

    await tester.pumpWidget(ClassManagerApp(state: state));
    await tester.pump();
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();

    final greeting = greetingFor(DateTime.now());
    expect(find.text(greeting.withName('闫梓萱')), findsOneWidget);
    expect(find.textContaining(greeting.reminder), findsOneWidget);
  });

  testWidgets('我的页：未填姓名时只显示时段问候', (WidgetTester tester) async {
    await openMine(tester);
    final greeting = greetingFor(DateTime.now());
    expect(find.text(greeting.hello), findsOneWidget);
  });

  testWidgets('我的页：分组卡片内容正确', (WidgetTester tester) async {
    await openMine(tester);

    expect(find.text('个性化设置'), findsOneWidget);
    expect(find.text('联系作者'), findsOneWidget);
    expect(find.text('关于软件'), findsOneWidget);
    expect(find.text('检查更新'), findsOneWidget);
    expect(find.text('隐私政策'), findsOneWidget);

    // 已删除的旧卡片
    expect(find.text('亲爱的同学'), findsNothing);
    expect(find.text('关于'), findsNothing);
    expect(find.text('开学日期'), findsNothing);
    expect(find.text('导入课表'), findsNothing);
    // 网页导入入口已从「我的」页移除（保留在主页菜单）
    expect(find.text('从教务系统导入课表'), findsNothing);

    // 卡片顺序：个性化设置 → 获取源码 → 联系作者/关于软件/检查更新
    final personalization = tester.getTopLeft(find.text('个性化设置')).dy;
    final source = tester.getTopLeft(find.text('获取源码')).dy;
    final contact = tester.getTopLeft(find.text('联系作者')).dy;
    expect(source, greaterThan(personalization),
        reason: '获取源码应在个性化设置下方');
    expect(source, lessThan(contact), reason: '获取源码应在联系作者上方（第二行）');
  });

  testWidgets('联系作者：QQ 与邮箱可复制', (WidgetTester tester) async {
    await openMine(tester);

    await tester.tap(find.text('联系作者'));
    await tester.pumpAndSettle();

    expect(find.text('1224850644'), findsOneWidget);
    expect(find.text('Assassin141_CUMT'), findsOneWidget);
    expect(find.text('1224850644@qq.com'), findsOneWidget);
  });

  testWidgets('关于软件：显示作者自述', (WidgetTester tester) async {
    await openMine(tester);

    await tester.tap(find.text('关于软件'));
    await tester.pumpAndSettle();

    expect(find.textContaining('闫梓萱'), findsOneWidget);
    expect(find.textContaining('矿小助'), findsOneWidget);
  });

  testWidgets('检查更新：先显示版本号，再前往下载链接', (WidgetTester tester) async {
    await openMine(tester);

    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle();

    // 先弹悬浮窗展示当前版本，不直接跳转
    expect(find.text('当前版本'), findsOneWidget);
    expect(find.text('v1.1.0'), findsOneWidget);
    expect(find.text('跳转到下载链接'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);

    // 点「跳转到下载链接」后才走外链（测试环境无法调起浏览器 → 兜底弹层）
    await tester.runAsync(() async {
      await tester.tap(find.text('跳转到下载链接'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    expect(find.textContaining('pan.quark.cn'), findsOneWidget);
  });

  testWidgets('获取源码：展示 GitHub 仓库链接', (WidgetTester tester) async {
    await openMine(tester);

    expect(find.text('获取源码'), findsOneWidget);
    await tester.tap(find.text('获取源码'));
    await tester.pumpAndSettle();

    expect(
        find.textContaining('github.com/PriAssassin141/Schedule-For-WHU'),
        findsOneWidget);
    expect(find.text('打开链接'), findsOneWidget);
    expect(find.text('复制链接'), findsOneWidget);
  });

  testWidgets('隐私政策：悬浮窗展示纯本地说明', (WidgetTester tester) async {
    await openMine(tester);

    expect(find.text('隐私政策'), findsOneWidget);
    await tester.tap(find.text('隐私政策'));
    await tester.pumpAndSettle();

    expect(find.textContaining('纯本地软件'), findsOneWidget);
    expect(find.textContaining('不会被以任何形式收集或上传'), findsOneWidget);
    expect(find.textContaining('2026 年 9 月 8 日'), findsOneWidget);
    expect(find.textContaining('闫梓萱'), findsOneWidget);
  });
}
