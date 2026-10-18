import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:class_manager/state/app_state.dart';
import 'package:class_manager/widgets/lens_dock.dart';

const items = [
  LensDockItem(Icons.home_rounded, '主页'),
  LensDockItem(Icons.explore_rounded, '发现'),
  LensDockItem(Icons.person_rounded, '我的'),
];

void main() {
  Future<void> dock(
    WidgetTester tester,
    AppState state, {
    TextDirection direction = TextDirection.ltr,
  }) async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          home: Directionality(
            textDirection: direction,
            child: Scaffold(
              body: Center(child: SizedBox(width: 330, child: _DockHarness())),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Rect indicator(WidgetTester tester) =>
      tester.getRect(find.byKey(const ValueKey('dock_glass_indicator')));

  testWidgets('Dock 选中层连续滑动，快速换向从当前姿态继续', (tester) async {
    await dock(tester, AppState.memory());
    final start = indicator(tester);
    await tester.tap(find.text('我的'));
    await tester.pump();
    expect(indicator(tester).left, closeTo(start.left, 0.01));
    await tester.pump(const Duration(milliseconds: 80));
    final mid = indicator(tester);
    expect(mid.left, greaterThan(start.left + 5));
    expect(mid.center.dx, lessThan(tester.getCenter(find.text('我的')).dx));
    await tester.tap(find.text('主页'));
    await tester.pump();
    expect(indicator(tester).left, closeTo(mid.left, 0.01));
    await tester.pumpAndSettle();
    expect(indicator(tester).left, closeTo(start.left, 0.01));
    expect(find.byKey(const ValueKey('dock_glass_indicator')), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Dock 支持键盘与RTL，尺寸变化后仍对齐所选栏目', (tester) async {
    await dock(tester, AppState.memory(), direction: TextDirection.rtl);
    expect(
      indicator(tester).center.dx,
      closeTo(tester.getCenter(find.text('主页')).dx, 1),
    );
    await tester.tap(find.text('发现'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pumpAndSettle();
    expect(
      indicator(tester).center.dx,
      closeTo(tester.getCenter(find.text('我的')).dx, 1),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(
      indicator(tester).center.dx,
      closeTo(tester.getCenter(find.text('发现')).dx, 1),
    );
    tester.view.physicalSize = const Size(300, 640);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpAndSettle();
    expect(
      indicator(tester).center.dx,
      closeTo(tester.getCenter(find.text('发现')).dx, 1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('关闭液态玻璃移除滑动层，减少动态效果时直接到达', (tester) async {
    final state = AppState.memory();
    await dock(tester, state);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpAndSettle();
    await tester.tap(find.text('我的'));
    await tester.pump();
    expect(
      indicator(tester).center.dx,
      closeTo(tester.getCenter(find.text('我的')).dx, 1),
    );
    await state.updateSettings(state.settings.copyWith(liquidGlass: false));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dock_glass_indicator')), findsNothing);
    await tester.tap(find.text('主页'));
    await tester.pumpAndSettle();
    await state.updateSettings(state.settings.copyWith(liquidGlass: true));
    await tester.pumpAndSettle();
    expect(
      indicator(tester).center.dx,
      closeTo(tester.getCenter(find.text('主页')).dx, 1),
    );
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('到位后先压缩再回弹，最后精确静止', (tester) async {
    await dock(tester, AppState.memory());
    await tester.tap(find.text('发现'));
    await tester.pump();
    final scales = <double>[];
    var arrived = false;
    final target = tester.getCenter(find.text('发现')).dx;
    for (var i = 0; i < 90; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      arrived |= (indicator(tester).center.dx - target).abs() < 8;
      if (arrived) {
        scales.add(
          tester
              .widget<Transform>(
                find.byKey(const ValueKey('dock_lens_deformation')),
              )
              .transform
              .storage[0],
        );
      }
    }
    expect(arrived, isTrue);
    expect(scales.any((scale) => scale < 0.97), isTrue);
    final compressed = scales.indexWhere((scale) => scale < 0.97);
    expect(scales.skip(compressed).any((scale) => scale > 1.008), isTrue);
    await tester.pumpAndSettle();
    expect(indicator(tester).center.dx, closeTo(target, 0.01));
    expect(
      tester
          .widget<Transform>(
            find.byKey(const ValueKey('dock_lens_deformation')),
          )
          .transform
          .storage[0],
      1,
    );
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('关闭果冻仍滑动但不形变；动画中关闭液态可安全停止', (tester) async {
    final state = AppState.memory();
    await state.updateSettings(state.settings.copyWith(jellyEffect: false));
    await dock(tester, state);
    final start = indicator(tester).left;
    await tester.tap(find.text('我的'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(indicator(tester).left, greaterThan(start));
    expect(
      tester
          .widget<Transform>(
            find.byKey(const ValueKey('dock_lens_deformation')),
          )
          .transform
          .storage[0],
      1,
    );
    await state.updateSettings(state.settings.copyWith(liquidGlass: false));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dock_glass_indicator')), findsNothing);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });
}

class _DockHarness extends StatefulWidget {
  @override
  State<_DockHarness> createState() => _DockHarnessState();
}

class _DockHarnessState extends State<_DockHarness> {
  var selected = 0;
  @override
  Widget build(BuildContext context) => LensDock(
    items: items,
    selectedIndex: selected,
    onChanged: (value) => setState(() => selected = value),
  );
}
