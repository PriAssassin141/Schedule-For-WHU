import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:class_manager/services/schedule_importer.dart';
import 'package:class_manager/services/schedule_parser.dart';
import 'package:class_manager/utils/weeks.dart';

void main() {
  group('周数工具', () {
    test('解析区间/单点/混合', () {
      expect(Weeks.parse('1-16'), List.generate(16, (i) => i + 1));
      expect(Weeks.parse('2,15'), [2, 15]);
      expect(Weeks.parse('1-4,6,9-12'), [1, 2, 3, 4, 6, 9, 10, 11, 12]);
      expect(Weeks.parse('1，3、6周').length, greaterThanOrEqualTo(1));
    });

    test('空串 = 全周', () {
      expect(Weeks.parse(''), List.generate(kMaxWeek, (i) => i + 1));
      expect(Weeks.isAll(''), isTrue);
    });

    test('压缩与规范化', () {
      expect(Weeks.compress([for (var w = 1; w <= 16; w++) w]), '1-16');
      expect(Weeks.compress([2, 15]), '2,15');
      expect(Weeks.canonical('1-3,4-5'), '1-5');
      expect(Weeks.contains('1-16', 8), isTrue);
      expect(Weeks.contains('2,15', 3), isFalse);
      expect(Weeks.describe(''), '全周');
    });
  });

  group('开学日期换算', () {
    const start = '2026-09-07'; // 第 1 周周一（与示例文件一致）
    test('第 1 周', () {
      expect(weekOf(DateTime(2026, 9, 7), start), 1);
      expect(weekOf(DateTime(2026, 9, 13), start), 1);
    });
    test('第 2 周', () {
      expect(weekOf(DateTime(2026, 9, 14), start), 2);
    });
    test('第 16 周', () {
      expect(weekOf(DateTime(2026, 12, 21), start), 16);
    });
    test('dateOfWeekDay 往返', () {
      expect(fmtDateShort(dateOfWeekDay(1, 1, start)), '9/7');
      expect(fmtDate(dateOfWeekDay(1, 7, start)), '2026-09-13');
      expect(fmtDate(dateOfWeekDay(2, 1, start)), '2026-09-14');
    });
  });

  group('课表文件导入（学生课表.doc / MHTML）', () {
    late List<ParsedCourse> parsed;

    setUpAll(() async {
      final bytes = File('test/fixtures/学生课表.doc').readAsBytesSync();
      final result = await importScheduleFile('学生课表.doc', bytes);
      parsed = result.courses;
    });

    test('解析出 7 门课程', () {
      expect(parsed.length, 7);
    });

    test('数理统计：周一 第6-8节 1-16周', () {
      final c = parsed.firstWhere((p) => p.name.startsWith('数理统计'));
      expect(c.teacher, '邓爱姣');
      expect(c.location, '网安基地, 新珈楼B201');
      expect(c.day, 1);
      expect(c.startPeriod, 6);
      expect(c.endPeriod, 8);
      expect(c.weeks, '1-16');
    });

    test('高级人工智能：周二 第6-9节 5-16周', () {
      final c = parsed.firstWhere((p) => p.name.startsWith('高级人工智能'));
      expect(c.teacher, '陈刚,林海,艾浩军');
      expect(c.location, '网安基地, 新珈楼B106');
      expect(c.day, 2);
      expect(c.startPeriod, 6);
      expect(c.endPeriod, 9);
      expect(c.weeks, '5-16');
    });

    test('工程伦理：周五批 2 周与 15 周（合并单元格内含两门课）', () {
      final eng = parsed.where((p) => p.name.startsWith('工程伦理')).toList();
      expect(eng.length, 3);
      expect(eng.every((p) => p.day == 5), isTrue);
      expect(eng[0].weeks, '2');
      expect(eng[1].weeks, '15');
      expect(eng[0].startPeriod, 6);
      expect(eng[0].endPeriod, 7);
      expect(eng[2].startPeriod, 8);
      expect(eng[2].endPeriod, 8);
    });

    test('前沿密码协议及应用：周二 第11-13节 9-16周', () {
      final c = parsed.firstWhere((p) => p.name.startsWith('前沿密码'));
      expect(c.day, 2);
      expect(c.startPeriod, 11);
      expect(c.endPeriod, 13);
      expect(c.weeks, '9-16');
    });

    test('网络与信息系统安全：周五 第11-13节 1-8周', () {
      final c = parsed.firstWhere((p) => p.name.startsWith('网络与信息系统'));
      expect(c.day, 5);
      expect(c.startPeriod, 11);
      expect(c.endPeriod, 13);
      expect(c.weeks, '1-8');
    });
  });

  group('虚拟网格解析（通用路径）', () {
    test('星期列映射 + 竖排合并跨度', () {
      final grid = [
        [
          const RawCell(lines: ['节次']),
          const RawCell(lines: ['时间']),
          const RawCell(lines: ['星期一']),
          const RawCell(lines: ['星期二']),
        ],
        [
          const RawCell(lines: ['第一节']),
          const RawCell(lines: ['08:00~08:45']),
          const RawCell(lines: ['1-16周', '高等数学', '张三', '一教101'], rowspan: 2),
          const RawCell(lines: []),
        ],
        [
          const RawCell(lines: ['第二节']),
          const RawCell(lines: ['08:50~09:35']),
          const RawCell(lines: []),
          const RawCell(lines: []),
        ],
      ];
      final result = parseScheduleGrid(grid);
      expect(result.length, 1);
      expect(result.first.day, 1);
      expect(result.first.startPeriod, 1);
      expect(result.first.endPeriod, 2);
      expect(result.first.name, '高等数学');
      expect(result.first.teacher, '张三');
      expect(result.first.location, '一教101');
      expect(result.first.weeks, '1-16');
    });
  });
}
