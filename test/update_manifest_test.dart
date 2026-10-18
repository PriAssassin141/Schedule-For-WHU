import 'package:flutter_test/flutter_test.dart';
import 'package:class_manager/models/update_manifest.dart';
import 'support/update_fakes.dart';

void main() {
  final localTime = parseReleaseTime(202610170013);

  test('读取用户格式，数字和字符串时间均按北京时间解析', () {
    final manifest = sampleUpdate();
    expect(manifest.version.label, '1.0.4');
    expect(manifest.updatedAt, DateTime.utc(2026, 10, 16, 16, 13));
    expect(parseReleaseTime('202610170013'), manifest.updatedAt);
    expect(formatReleaseTime(manifest.updatedAt), '2026-10-17 00:13');
  });

  test('版本按数值比较，不将1.0.10当成低于1.0.9', () {
    expect(
      sampleUpdate(version: 'v1.0.10').isNewerThan('1.0.9', localTime),
      isTrue,
    );
    expect(
      sampleUpdate(version: 'v1.1.0').isNewerThan('1.0.99', localTime),
      isTrue,
    );
  });

  test('同版本仅发布时间严格更新时提示；时间晚也不能推荐降级', () {
    expect(sampleUpdate().isNewerThan('1.0.4', localTime), isFalse);
    expect(
      sampleUpdate(time: 202610170014).isNewerThan('1.0.4', localTime),
      isTrue,
    );
    expect(
      sampleUpdate(time: 202610170012).isNewerThan('1.0.4', localTime),
      isFalse,
    );
    expect(
      sampleUpdate(
        version: 'v1.0.3',
        time: 202701010000,
      ).isNewerThan('1.0.4', localTime),
      isFalse,
    );
    expect(
      sampleUpdate(
        version: 'v1.0.5',
        time: 202601010000,
      ).isNewerThan('1.0.4', localTime),
      isTrue,
    );
  });

  test('正式版高于预发布版；预发布数字、文本及构建后缀比较正确', () {
    final versions = [
      '1.0.4-alpha',
      '1.0.4-alpha.2',
      '1.0.4-alpha.10',
      '1.0.4-beta',
      '1.0.4-rc.1',
      '1.0.4',
    ];
    for (var i = 1; i < versions.length; i++) {
      expect(
        AppVersion.parse(
          versions[i],
        ).compareTo(AppVersion.parse(versions[i - 1])),
        greaterThan(0),
      );
    }
    expect(
      AppVersion.parse('1.0.4+5').compareTo(AppVersion.parse('v1.0.4+4')),
      0,
    );
  });

  test('无效日期、缺少字段、错误字段类型拒绝解析，UTF8 BOM可接受', () {
    for (final value in [
      202602300012,
      202613010000,
      202610172400,
      202610170060,
      1792160000,
      '2026-10-17',
      null,
    ]) {
      expect(() => parseReleaseTime(value), throwsFormatException);
    }
    for (final text in [
      '{}',
      '[]',
      '{bad json',
      '{"latest-version":"v1.0.4","update-time":202610170013,"describe":[]}',
      '{"latest-version":"latest","update-time":202610170013}',
    ]) {
      expect(() => UpdateManifest.parse(text), throwsFormatException);
    }
    expect(
      UpdateManifest.parse(
        '\uFEFF{"latest-version":"v1.0.4","update-time":202610170013}',
      ).version.label,
      '1.0.4',
    );
  });
}
