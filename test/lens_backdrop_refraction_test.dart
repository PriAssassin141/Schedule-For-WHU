import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:class_manager/widgets/glass_backdrop.dart';

void main() {
  testWidgets('Skia 透镜移动背景采样且保持中心与外部稳定，零折射可关闭', (tester) async {
    final key = GlobalKey();
    Future<ByteData> capture(double refraction, {double left = 60}) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: 400,
                height: 180,
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.red, Colors.blue],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: left,
                      top: 60,
                      width: 180,
                      height: 56,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(23),
                        child: GlassBackdrop(
                          radius: BorderRadius.circular(23),
                          sigma: 0,
                          refraction: refraction,
                          dispersion: 0,
                          refractFallback: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      late ByteData data;
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        image.dispose();
      });
      return data;
    }

    int red(ByteData bytes, int x, int y) => bytes.getUint8((y * 400 + x) * 4);
    final plain = await capture(0);
    final lens = await capture(1);
    expect(red(lens, 62, 88), lessThan(red(plain, 62, 88)));
    expect(red(lens, 238, 88) - red(plain, 238, 88), greaterThanOrEqualTo(3));
    expect(red(lens, 150, 88), closeTo(red(plain, 150, 88), 2));
    expect(red(lens, 20, 88), red(plain, 20, 88));
    final movedPlain = await capture(0, left: 160);
    final movedLens = await capture(1, left: 160);
    // The magnification center follows the panel, not the screen origin.
    expect(
      red(movedLens, 338, 88) - red(movedPlain, 338, 88),
      greaterThanOrEqualTo(3),
    );
    expect(red(movedLens, 250, 88), closeTo(red(movedPlain, 250, 88), 2));
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });
}
