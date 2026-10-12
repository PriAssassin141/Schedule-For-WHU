import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:class_manager/main.dart';
import 'package:class_manager/state/app_state.dart';
import 'package:class_manager/widgets/glass_dialog.dart';

void main() {
  Future<void> openSettings(WidgetTester tester, AppState state) async {
    await tester.pumpWidget(ClassManagerApp(state: state));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('节假日与调休'));
    await tester.pumpAndSettle();
  }

  testWidgets('年份菜单包含2035，添加安排默认使用所选年份', (tester) async {
    final state = AppState.memory();
    await openSettings(tester, state);
    expect(find.textContaining('国务院通知'), findsNothing);
    expect(find.textContaining('内置'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('adjustment_year')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('2035 年'),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('2035 年'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add_adjustment')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(GlassDialog),
        matching: find.text('2035-01-01 周一'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('save_adjustment')));
    await tester.pumpAndSettle();
    expect(state.settings.scheduleAdjustments.single.date, '2035-01-01');
    expect(tester.takeException(), isNull);
  });

  testWidgets('调休编辑和选项弹窗随液态玻璃开关切换，保留高斯模糊', (tester) async {
    final state = AppState.memory();
    await openSettings(tester, state);
    await tester.tap(find.byKey(const ValueKey('add_adjustment')));
    await tester.pumpAndSettle();
    for (final liquid in [false, true]) {
      await state.updateSettings(state.settings.copyWith(liquidGlass: liquid));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Dialog>(find.byType(Dialog)).backgroundColor,
        Colors.transparent,
      );
      expect(
        find.descendant(
          of: find.byType(GlassDialog),
          matching: find.byType(BackdropFilter),
        ),
        findsWidgets,
      );
      expect(
        find.byKey(const ValueKey('save_adjustment')).hitTestable(),
        findsOneWidget,
      );
    }
    await tester.tap(find.byKey(const ValueKey('adjustment_type')));
    await tester.pumpAndSettle();
    expect(find.byType(GlassDialog), findsNWidgets(2));
    await tester.tap(find.text('按原课表上课'));
    await tester.pumpAndSettle();
    expect(find.byType(GlassDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('开学日期的玻璃日历可选择2035年，主题色立即生效', (tester) async {
    final state = AppState.memory();
    await tester.pumpWidget(ClassManagerApp(state: state));
    await tester.pumpAndSettle();
    final oldPrimary = tester
        .widget<MaterialApp>(find.byType(MaterialApp))
        .theme!
        .colorScheme
        .primary;
    await state.updateSettings(state.settings.copyWith(themeColorIndex: 1));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<MaterialApp>(find.byType(MaterialApp))
          .theme!
          .colorScheme
          .primary,
      isNot(oldPrimary),
    );
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('开学日期'));
    await tester.pumpAndSettle();
    expect(find.byType(GlassDialog), findsOneWidget);
    final localizations = MaterialLocalizations.of(
      tester.element(find.byType(CalendarDatePicker)),
    );
    await tester.tap(
      find.text(localizations.formatMonthYear(DateTime(2026, 9))),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text(localizations.formatYear(DateTime(2035))),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text(localizations.formatYear(DateTime(2035))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(state.settings.startDate, startsWith('2035-'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('玻璃时间选择器保留24小时初值，确认和取消结果正确', (tester) async {
    final state = AppState.memory();
    TimeOfDay? result;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showGlassTimePicker(
                    context: context,
                    initialTime: const TimeOfDay(hour: 14, minute: 30),
                  );
                },
                child: const Text('选择时间'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('选择时间'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoDatePicker), findsOneWidget);
    expect(find.byType(GlassDialog), findsOneWidget);
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(result, const TimeOfDay(hour: 14, minute: 30));
    await tester.tap(find.text('选择时间'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(tester.takeException(), isNull);
  });
}
