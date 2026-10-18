import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:class_manager/config/release_metadata.dart';
import 'package:class_manager/models/update_manifest.dart';
import 'package:class_manager/services/quark_update_service.dart';
import 'package:class_manager/state/app_state.dart';
import 'package:class_manager/widgets/update_check_dialog.dart';
import 'support/update_fakes.dart';

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: '表里珞珈',
      packageName: 'test.app',
      version: '1.0.4',
      buildNumber: '4',
      buildSignature: '',
    );
  });

  Future<void> open(
    WidgetTester tester,
    UpdateCheckerFactory checker, {
    bool liquid = true,
    VoidCallback? onDownload,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final state = AppState.memory();
    await state.updateSettings(state.settings.copyWith(liquidGlass: liquid));
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => UpdateCheckDialog(
                    checkerFactory: checker,
                    onDownload: onDownload ?? () {},
                  ),
                ),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pump();
  }

  testWidgets('两种玻璃模式显示当前版、最新版、时间及说明，同版本新发布时间也提示更新', (tester) async {
    final nextTime = formatReleaseTime(
      parseReleaseTime(appReleaseUpdateTime).add(const Duration(minutes: 1)),
    );
    final nextStamp = nextTime.replaceAll(RegExp(r'[-: ]'), '');
    for (final liquid in [true, false]) {
      await open(
        tester,
        () => StubUpdateChecker(() async => sampleUpdate(time: nextStamp)),
        liquid: liquid,
      );
      await tester.pumpAndSettle();
      expect(find.text('发现新版本，建议更新'), findsOneWidget);
      expect(find.text('v1.0.4'), findsNWidgets(2));
      expect(find.text('更新时间：$nextTime'), findsOneWidget);
      expect(find.text('修复已知问题，优化课表体验。'), findsOneWidget);
      expect(find.text('跳转到下载链接').hitTestable(), findsOneWidget);
      expect(find.text('取消').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('无需更新时只显示独立提示栏，隐藏网盘版本、更新时间与说明', (tester) async {
    for (final liquid in [true, false]) {
      for (final version in ['v1.0.4', 'v1.0.3']) {
        await open(
          tester,
          () => StubUpdateChecker(
            () async =>
                sampleUpdate(version: version, time: appReleaseUpdateTime),
          ),
          liquid: liquid,
        );
        await tester.pumpAndSettle();
        expect(find.text('当前为最新版本，无需更新'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('update_up_to_date')),
            matching: find.text('当前为最新版本，无需更新'),
          ),
          findsOneWidget,
        );
        expect(find.text('当前版本'), findsOneWidget);
        expect(find.text('v1.0.4'), findsOneWidget);
        expect(find.text('网盘最新版本'), findsNothing);
        expect(find.textContaining('更新时间：'), findsNothing);
        expect(find.text('更新内容'), findsNothing);
        expect(find.textContaining('如需获取最新版本安装包'), findsNothing);
        expect(find.text('修复已知问题，优化课表体验。'), findsNothing);
        expect(find.text('发现新版本，建议更新'), findsNothing);
        expect(find.text('跳转到下载链接').hitTestable(), findsOneWidget);
        expect(find.text('取消').hitTestable(), findsOneWidget);
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
      }
    }
  });

  testWidgets('检查失败可重新检查；下载按钮始终可用，不自动跳转', (tester) async {
    var checks = 0;
    var downloads = 0;
    await open(
      tester,
      () => StubUpdateChecker(() async {
        if (++checks == 1) throw const UpdateCheckException('检查更新超时，请检查网络后重试');
        return sampleUpdate(version: 'v1.0.5');
      }),
      onDownload: () => downloads++,
    );
    await tester.pumpAndSettle();
    expect(find.text('检查更新失败'), findsOneWidget);
    expect(find.textContaining('超时'), findsOneWidget);
    expect(find.text('当前为最新版本，无需更新'), findsNothing);
    expect(downloads, 0);
    await tester.tap(find.text('重新检查'));
    await tester.pumpAndSettle();
    expect(find.text('发现新版本，建议更新'), findsOneWidget);
    expect(checks, 2);
    expect(downloads, 0);
    await tester.tap(find.text('跳转到下载链接'));
    expect(downloads, 1);
  });

  testWidgets('检查中取消会关闭连接；异步结果晚到不触发已销毁弹窗', (tester) async {
    final pending = Completer<UpdateManifest>();
    final checker = StubUpdateChecker(() => pending.future);
    await open(tester, () => checker);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('正在扫描网盘更新日志…'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(checker.closeCount, 1);
    pending.complete(sampleUpdate(version: 'v1.0.5'));
    await tester.pumpAndSettle();
    expect(find.byType(UpdateCheckDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
