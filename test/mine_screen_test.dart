import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import 'package:class_manager/main.dart';
import 'package:class_manager/state/app_state.dart';
import 'package:class_manager/services/quark_update_service.dart';
import 'package:class_manager/utils/greeting.dart';
import 'package:class_manager/widgets/glass_dialog.dart';
import 'support/update_fakes.dart';

/// “我的”页：问候语 + 个性化入口 + 「获取源码 / 联系作者 / 关于软件 / 检查更新 / 隐私政策」。
void main() {
  Future<void> openMine(WidgetTester tester, {bool liquidGlass = true}) async {
    final state = AppState.memory();
    await state.updateSettings(
      state.settings.copyWith(liquidGlass: liquidGlass),
    );
    state.browseWeek = 1;
    await tester.pumpWidget(
      Provider<UpdateCheckerFactory>.value(
        value: () => StubUpdateChecker(() async => sampleUpdate()),
        child: ClassManagerApp(state: state),
      ),
    );
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

    // 卡片顺序：个性化设置 → 获取源码 → 联系作者/关于软件/检查更新
    final personalization = tester.getTopLeft(find.text('个性化设置')).dy;
    final source = tester.getTopLeft(find.text('获取源码')).dy;
    final contact = tester.getTopLeft(find.text('联系作者')).dy;
    expect(source, greaterThan(personalization), reason: '获取源码应在个性化设置下方');
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

  testWidgets('检查更新：两种玻璃模式先展示本机版本，关闭不打开链接', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: '表里珞珈',
      packageName: 'com.classmanager.class_manager',
      version: '9.8.7',
      buildNumber: '42',
      buildSignature: '',
    );
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    final launches = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      if (call.method == 'launch') {
        launches.add((call.arguments as Map)['url'] as String);
      }
      return true;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    for (final liquid in [true, false]) {
      await openMine(tester, liquidGlass: liquid);
      await tester.tap(find.text('检查更新'));
      await tester.pumpAndSettle();
      expect(find.byType(GlassDialog), findsOneWidget);
      expect(find.text('当前版本'), findsOneWidget);
      expect(find.text('v9.8.7'), findsOneWidget);
      expect(find.text('跳转到下载链接'), findsOneWidget);
      expect(launches, isEmpty);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.byType(GlassDialog), findsNothing);
      expect(launches, isEmpty);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('检查更新：只有下载按钮打开原链接，失败仍可复制链接', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: '表里珞珈',
      packageName: 'com.classmanager.class_manager',
      version: '1.0.4',
      buildNumber: '4',
      buildSignature: '',
    );
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    final launches = <String>[];
    var success = true;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      if (call.method == 'launch') {
        launches.add((call.arguments as Map)['url'] as String);
      }
      return success;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await openMine(tester);
    for (final result in [true, false]) {
      success = result;
      await tester.tap(find.text('检查更新'));
      await tester.pumpAndSettle();
      final before = launches.length;
      await tester.tap(find.text('跳转到下载链接'));
      await tester.pumpAndSettle();
      expect(launches.length, before + 1);
      expect(launches.last, 'https://pan.quark.cn/s/b57d9dfe897a');
      expect(find.byType(GlassDialog), findsNothing);
      expect(
        find.textContaining('pan.quark.cn'),
        result ? findsNothing : findsOneWidget,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('获取源码：展示 GitHub 仓库链接', (WidgetTester tester) async {
    await openMine(tester);

    expect(find.text('获取源码'), findsOneWidget);
    await tester.tap(find.text('获取源码'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('github.com/PriAssassin141/Schedule-For-WHU'),
      findsOneWidget,
    );
    expect(find.text('打开链接'), findsOneWidget);
    expect(find.text('复制链接'), findsOneWidget);
  });

  testWidgets('隐私政策：说明本地数据与主动检查更新的联网行为', (WidgetTester tester) async {
    await openMine(tester);

    expect(find.text('隐私政策'), findsOneWidget);
    await tester.tap(find.text('隐私政策'));
    await tester.pumpAndSettle();

    expect(find.textContaining('不收集或上传这些数据'), findsOneWidget);
    expect(find.textContaining('读取夸克分享目录中的更新日志'), findsOneWidget);
    expect(find.textContaining('2026 年 10 月 17 日'), findsOneWidget);
    expect(find.textContaining('闫梓萱'), findsOneWidget);
  });
}
