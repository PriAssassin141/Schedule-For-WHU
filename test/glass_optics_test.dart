import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:class_manager/state/app_state.dart';
import 'package:class_manager/widgets/glass.dart';
import 'package:class_manager/widgets/glass_backdrop.dart';
import 'package:class_manager/widgets/lens_motion.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ui.Image> backdrop(int width, int height, {double alpha = 1}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final rect = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.red.withValues(alpha: alpha),
            Colors.blue.withValues(alpha: alpha),
          ],
        ).createShader(rect),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    picture.dispose();
    return image;
  }

  Future<ByteData> render(
    ui.FragmentProgram program,
    ui.Image input, {
    double refraction = 0,
    double dispersion = 0,
    double radius = 24,
    double pressure = 0,
    double lighting = 0,
    Alignment pointer = const Alignment(-0.7, -0.8),
  }) async {
    final width = input.width.toDouble();
    final height = input.height.toDouble();
    final shader = program.fragmentShader()
      ..setFloat(0, width)
      ..setFloat(1, height)
      ..setFloat(2, width)
      ..setFloat(3, height)
      ..setFloat(4, radius)
      ..setFloat(5, radius)
      ..setFloat(6, radius)
      ..setFloat(7, radius)
      ..setFloat(8, refraction)
      ..setFloat(9, dispersion)
      ..setFloat(10, pointer.x)
      ..setFloat(11, pointer.y)
      ..setFloat(12, pressure)
      ..setFloat(13, 0)
      ..setFloat(14, lighting)
      ..setImageSampler(0, input);
    final recorder = ui.PictureRecorder();
    Canvas(
      recorder,
    ).drawRect(Rect.fromLTWH(0, 0, width, height), Paint()..shader = shader);
    final picture = recorder.endRecording();
    final image = await picture.toImage(input.width, input.height);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    image.dispose();
    picture.dispose();
    shader.dispose();
    return bytes;
  }

  List<int> pixel(ByteData data, int width, int x, int y) => List.generate(
    4,
    (channel) => data.getUint8((y * width + x) * 4 + channel),
  );

  test('Lens 折射作用于背景，横向和纵向卡片中心保持清晰', () async {
    final program = await ui.FragmentProgram.fromAsset(
      'shaders/liquid_glass.frag',
    );
    for (final size in [const Size(240, 144), const Size(64, 200)]) {
      final input = await backdrop(size.width.toInt(), size.height.toInt());
      final plain = await render(program, input);
      final bent = await render(program, input, refraction: 1);
      final center = pixel(
        plain,
        input.width,
        input.width ~/ 2,
        input.height ~/ 2,
      );
      expect(
        pixel(bent, input.width, input.width ~/ 2, input.height ~/ 2),
        center,
      );
      final edge = pixel(plain, input.width, 2, input.height ~/ 2);
      final refractedEdge = pixel(bent, input.width, 2, input.height ~/ 2);
      expect((edge[0] - refractedEdge[0]).abs(), greaterThan(3));
      input.dispose();
    }
  });

  test('色散分离边缘RGB，零参数不改变背景，透明输入保持合法alpha', () async {
    final program = await ui.FragmentProgram.fromAsset(
      'shaders/liquid_glass.frag',
    );
    final input = await backdrop(240, 144, alpha: 0.5);
    final original = (await input.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!;
    final plain = await render(program, input);
    final split = await render(program, input, dispersion: 1);
    expect(pixel(plain, 240, 120, 72), pixel(original, 240, 120, 72));
    expect(pixel(split, 240, 120, 72), pixel(plain, 240, 120, 72));
    expect(pixel(split, 240, 2, 72), isNot(pixel(plain, 240, 2, 72)));
    for (var index = 0; index < split.lengthInBytes; index += 4) {
      final alpha = split.getUint8(index + 3);
      for (var channel = 0; channel < 3; channel++) {
        expect(split.getUint8(index + channel), lessThanOrEqualTo(alpha));
      }
    }
    input.dispose();
  });

  Future<void> panel(
    WidgetTester tester,
    AppState state, {
    VoidCallback? onTap,
  }) => tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: LiquidGlass(
              key: const ValueKey('test_glass'),
              onTap: onTap,
              child: const SizedBox(
                width: 220,
                height: 90,
                child: Text('课程信息'),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('色散不会挤压课程卡片，模式切换及Skia回退保持可点击', (tester) async {
    final state = AppState.memory();
    var taps = 0;
    await panel(tester, state, onTap: () => taps++);
    await tester.pumpAndSettle();
    final size = tester.getSize(find.byKey(const ValueKey('test_glass')));
    for (final liquid in [true, false, true]) {
      await state.updateSettings(
        state.settings.copyWith(
          liquidGlass: liquid,
          refraction: 1,
          dispersion: 1,
          cardBlur: 0.4,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(const ValueKey('test_glass'))), size);
      expect(find.byType(BackdropFilter), findsOneWidget);
      await tester.tap(find.text('课程信息'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    expect(taps, 3);
  });

  testWidgets('鼠标高光不拦截子控件，离开后弹性缩放恢复', (tester) async {
    final state = AppState.memory();
    var taps = 0;
    await panel(tester, state, onTap: () => taps++);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('课程信息')));
    await tester.pumpAndSettle();
    final pose = find
        .descendant(
          of: find.byType(LensMotion),
          matching: find.byType(Transform),
        )
        .first;
    expect(tester.widget<Transform>(pose).transform.storage[0], 1);
    final held = await tester.startGesture(tester.getCenter(find.text('课程信息')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 140));
    expect(tester.widget<Transform>(pose).transform.storage[0], greaterThan(1));
    await held.up();
    await tester.pumpAndSettle();
    await tester.tap(find.text('课程信息'));
    await tester.pumpAndSettle();
    expect(taps, 2);
    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(tester.widget<Transform>(pose).transform.storage[0], 1);
    await mouse.removePointer();
    expect(tester.takeException(), isNull);
  });

  testWidgets('触摸玻璃内滑杆仍可拖动；减少动态效果时禁用缩放', (tester) async {
    final state = AppState.memory();
    var value = 0.2;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 280,
                child: LiquidGlass(
                  child: StatefulBuilder(
                    builder: (context, setState) {
                      return Slider(
                        value: value,
                        onChanged: (next) => setState(() => value = next),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.drag(find.byType(Slider), const Offset(80, 0));
    await tester.pumpAndSettle();
    expect(value, greaterThan(0.2));
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await panel(tester, state, onTap: () {});
    await tester.pumpAndSettle();
    expect(tester.widget<LensMotion>(find.byType(LensMotion)).enabled, isFalse);
    final pose = find
        .descendant(
          of: find.byType(LensMotion),
          matching: find.byType(Transform),
        )
        .first;
    expect(tester.widget<Transform>(pose).transform.storage[0], 1);
    expect(tester.takeException(), isNull);
  });

  test('Lens 左侧折射与折射率1.45的斯涅尔计算相符', () async {
    final program = await ui.FragmentProgram.fromAsset(
      'shaders/liquid_glass.frag',
    );
    final input = await backdrop(240, 144);
    final bytes = await render(program, input, refraction: 1);
    const x = 2.5, halfWidth = 120.0, bevel = 19.0;
    final edge = 1 - x / bevel;
    final normalX =
        -math.pow(edge, 1.65) * 0.94 +
        (x - halfWidth) / halfWidth * 0.045 * (1 - edge);
    final normalZ = math.sqrt(1 - normalX * normalX);
    const eta = 1 / 1.45;
    final coefficient =
        math.sqrt(1 - eta * eta * (1 - normalZ * normalZ)) - eta * normalZ;
    final rayX = -coefficient * normalX;
    final rayZ = -eta - coefficient * normalZ;
    final offset = rayX / -rayZ * 75 - (x - halfWidth) * 0.016;
    final fraction = (x + offset) / 240;
    final expectedRed =
        (Colors.red.r * (1 - fraction) + Colors.blue.r * fraction) * 255;
    expect(pixel(bytes, 240, 2, 72)[0], closeTo(expectedRed, 2));
    input.dispose();
  });

  test('Lens 定向反光跟随光源，完整材质保持透明输入的alpha', () async {
    final program = await ui.FragmentProgram.fromAsset(
      'shaders/liquid_glass.frag',
    );
    final input = await backdrop(240, 144, alpha: 0.5);
    final left = await render(
      program,
      input,
      lighting: 1,
      pointer: Alignment.topLeft,
    );
    final right = await render(
      program,
      input,
      lighting: 1,
      pointer: Alignment.bottomRight,
    );
    expect(pixel(left, 240, 2, 72), isNot(pixel(right, 240, 2, 72)));
    final material = await render(
      program,
      input,
      lighting: 1,
      refraction: 0.9,
      dispersion: 0.65,
    );
    for (var index = 0; index < material.lengthInBytes; index += 4) {
      final alpha = material.getUint8(index + 3);
      expect(alpha, 128);
      for (var channel = 0; channel < 3; channel++) {
        expect(material.getUint8(index + channel), lessThanOrEqualTo(alpha));
      }
    }
    input.dispose();
  });

  testWidgets('回弹途中重按保持姿态连续，取消和卸载后停止动画', (tester) async {
    final state = AppState.memory();
    await panel(tester, state, onTap: () {});
    double pressure() =>
        tester.widget<GlassBackdrop>(find.byType(GlassBackdrop)).pressure;
    final first = await tester.startGesture(
      tester.getCenter(find.text('课程信息')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 140));
    expect(pressure(), greaterThan(0.5));
    await first.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final before = pressure();
    final second = await tester.startGesture(
      tester.getCenter(find.text('课程信息')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(pressure(), closeTo(before, 0.08));
    await second.cancel();
    await tester.pumpAndSettle();
    expect(pressure(), 0);
    expect(tester.binding.hasScheduledFrame, isFalse);
    final third = await tester.startGesture(
      tester.getCenter(find.text('课程信息')),
    );
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pumpWidget(const SizedBox.shrink());
    await third.cancel();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
