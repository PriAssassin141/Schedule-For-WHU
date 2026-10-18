import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:class_manager/main.dart';
import 'package:class_manager/state/app_state.dart';
import 'package:class_manager/widgets/glass.dart';
import 'package:class_manager/widgets/lens_backdrop_refraction.dart';

class _RealShadowBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

void main() {
  _RealShadowBinding();
  testWidgets(
    'Android 列表边界不拉伸玻璃，滑动后保留透镜与设置',
    (tester) async {
      final state = AppState.memory();
      await state.updateSettings(state.settings.copyWith(cardTransparency: 1));
      await tester.pumpWidget(ClassManagerApp(state: state));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('dock_tab_2')));
      await tester.pumpAndSettle();
      expect(find.byType(StretchingOverscrollIndicator), findsNothing);
      expect(find.byType(GlowingOverscrollIndicator), findsNothing);
      expect(find.byType(LensBackdropRefraction), findsWidgets);
      await tester.drag(find.text('个性化设置'), const Offset(0, 300));
      await tester.pumpAndSettle();
      await tester.tap(find.text('个性化设置'));
      await tester.pumpAndSettle();
      await tester.drag(find.text('个人姓名'), const Offset(0, -240));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).last, const Offset(0, 800));
      await tester.pumpAndSettle();
      expect(state.settings.cardTransparency, 1);
      expect(state.settings.liquidGlass, isTrue);
      expect(find.byType(StretchingOverscrollIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  // Runs on both Skia and --enable-impeller. A neutral input must remain neutral
  // even when the panel is larger than, and partially outside, the viewport.
  testWidgets('大玻璃滚动裁剪及按压不变黑、不偏绿，透明度100仍有表面', (tester) async {
    tester.view.physicalSize = const Size(720, 1120);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final state = AppState.memory();
    await state.updateSettings(state.settings.copyWith(cardTransparency: 1));
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final boundary = GlobalKey();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
          scrollBehavior: const MaterialScrollBehavior().copyWith(
            overscroll: false,
          ),
          home: RepaintBoundary(
            key: boundary,
            child: Stack(
              children: [
                const Positioned.fill(
                  child: ColoredBox(color: Color(0xFF707070)),
                ),
                ListView(
                  controller: controller,
                  scrollCacheExtent: const ScrollCacheExtent.pixels(1600),
                  padding: const EdgeInsets.all(16),
                  children: [
                    LiquidGlass(
                      key: const ValueKey('large_panel'),
                      onTap: () {},
                      tintAlphaOverride: 0.12,
                      child: const SizedBox(height: 900),
                    ),
                    const SizedBox(height: 16),
                    const LiquidGlass(child: SizedBox(height: 500)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<ByteData> capture() async {
      late ByteData bytes;
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        image.dispose();
      });
      return bytes;
    }

    List<int> pixel(ByteData bytes, int x, int y) =>
        List.generate(4, (c) => bytes.getUint8((y * 360 + x) * 4 + c));

    Future<void> expectNeutral() async {
      final bytes = await capture();
      for (var y = 30; y < 540; y += 20) {
        final rgba = pixel(bytes, 180, y);
        expect(
          rgba[0],
          inInclusiveRange(95, 190),
          reason: 'black/lost surface at y=$y',
        );
        expect(
          (rgba[1] - rgba[0]).abs(),
          lessThanOrEqualTo(4),
          reason: 'green band at y=$y',
        );
        expect((rgba[2] - rgba[1]).abs(), lessThanOrEqualTo(4));
        expect(rgba[3], 255);
      }
    }

    final initial = await capture();
    expect(pixel(initial, 180, 150)[0], greaterThan(122));
    for (final offset in [0.0, 100.0, 400.0, 50.0, 650.0, 0.0]) {
      controller.jumpTo(offset);
      await tester.pumpAndSettle();
      await expectNeutral();
    }
    final held = await tester.startGesture(const Offset(180, 200));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    await expectNeutral();
    await held.moveBy(const Offset(0, -160));
    await tester.pump(const Duration(milliseconds: 16));
    await expectNeutral();
    await held.up();
    await tester.pumpAndSettle();
    expect(find.byType(LensBackdropRefraction), findsWidgets);
    // Zero optical values are preserved, and Gaussian mode remains independent.
    await state.updateSettings(
      state.settings.copyWith(refraction: 0, cardBlur: 0),
    );
    await tester.pumpAndSettle();
    expect(find.byType(RawMagnifier), findsNothing);
    await expectNeutral();
    await state.updateSettings(state.settings.copyWith(liquidGlass: false));
    await tester.pumpAndSettle();
    expect(find.byType(LensBackdropRefraction), findsNothing);
    expect(state.settings.cardTransparency, 1);
    expect(tester.takeException(), isNull);
  });
}
