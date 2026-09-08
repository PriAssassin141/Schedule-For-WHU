import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:class_manager/services/schedule_importer.dart';
import 'package:class_manager/services/schedule_parser.dart';

/// docx（Word 转换版）解析路径。
void main() {
  late List<ParsedCourse> parsed;

  setUpAll(() async {
    final bytes = File('test/fixtures/学生课表.docx').readAsBytesSync();
    final result = await importScheduleFile('学生课表.docx', bytes);
    parsed = result.courses;
  });

  test('解析出 7 门课程且人名/地点/周次正确', () {
    expect(parsed.length, 7);

    final s = parsed.firstWhere((p) => p.name.startsWith('数理统计'));
    expect(s.teacher, '邓爱姣');
    expect(s.location, '网安基地, 新珈楼B201');
    expect(s.day, 1);
    expect(s.weeks, '1-16');

    final ai = parsed.firstWhere((p) => p.name.startsWith('高级人工智能'));
    expect(ai.day, 2);
    expect(ai.weeks, '5-16');
    expect(ai.teacher, '陈刚,林海,艾浩军');

    final eng = parsed.where((p) => p.name.startsWith('工程伦理')).toList();
    expect(eng.length, 3);
    expect(eng.every((p) => p.day == 5), isTrue);
    expect(eng.map((p) => p.weeks).toSet(), {'2', '15'});

    final crypto = parsed.firstWhere((p) => p.name.startsWith('前沿密码'));
    expect(crypto.day, 2);
    expect(crypto.weeks, '9-16');

    final net = parsed.firstWhere((p) => p.name.startsWith('网络与信息系统'));
    expect(net.day, 5);
    expect(net.weeks, '1-8');
  });
}
