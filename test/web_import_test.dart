import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:class_manager/screens/web_import_screen.dart';
import 'package:class_manager/services/schedule_importer.dart';
import 'package:class_manager/state/app_state.dart';

/// 网页导入课表：桌面端降级提示 + 网页表格 HTML 的解析链路。
void main() {
  testWidgets('桌面端提示改用文件导入', (WidgetTester tester) async {
    final state = AppState.memory();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: WebImportScreen()),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('网页导入课表'), findsOneWidget);
    expect(find.textContaining('需要在手机上使用'), findsOneWidget);
  });

  test('网页课表 HTML 可直接解析为课程', () async {
    // 模拟教务/研究生系统课表页提取出的表格（<br> 分行、含周数与地点）
    const html = '''
<html><body>
<table>
  <tr><td>节次/星期</td><td>时间</td><td>星期一</td><td>星期二</td></tr>
  <tr><td>第一节</td><td>08:00~08:45</td>
      <td>1-16周<br/>数理统计<br/>邓爱姣<br/>新珈楼B201</td><td></td></tr>
  <tr><td>第二节</td><td>08:50~09:35</td>
      <td></td>
      <td>5-8周<br/>高级人工智能<br/>陈刚<br/>新珈楼B106</td></tr>
  <tr><td>第三节</td><td>09:50~10:35</td><td></td><td></td></tr>
</table>
</body></html>
''';

    final res = await importScheduleFile(
        'web_import.html', Uint8List.fromList(utf8.encode(html)));

    expect(res.courses.length, 2, reason: res.note);
    final c1 = res.courses.firstWhere((c) => c.name.contains('数理统计'));
    expect(c1.day, 1);
    expect(c1.startPeriod, 1);
    expect(c1.weeks, '1-16');
    expect(c1.teacher, '邓爱姣');
    expect(c1.location, '新珈楼B201');

    final c2 = res.courses.firstWhere((c) => c.name.contains('人工智能'));
    expect(c2.day, 2);
    expect(c2.startPeriod, 2);
    expect(c2.weeks, '5-8');
    expect(c2.location, '新珈楼B106');
  });
}
