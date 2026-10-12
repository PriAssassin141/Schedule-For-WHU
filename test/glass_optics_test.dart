import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:class_manager/state/app_state.dart';
import 'package:class_manager/widgets/glass.dart';

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

  test('折射只弯曲圆角边缘，横向和纵向卡片中心保持清晰', () async {
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
    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
      greaterThan(1),
    );
    await tester.tap(find.text('课程信息'));
    await tester.pumpAndSettle();
    expect(taps, 1);
    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
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
    expect(find.byType(AnimatedScale), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
