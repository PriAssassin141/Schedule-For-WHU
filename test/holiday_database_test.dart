import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:class_manager/db/app_database.dart';
import 'package:class_manager/models/course.dart';
import 'package:class_manager/models/schedule_adjustment.dart';
import 'package:class_manager/state/app_state.dart';
import 'package:class_manager/utils/weeks.dart';

void main() {
  test('旧版本数据库升级无需迁移，重启后调休与课程完整恢复', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = await Directory.systemTemp.createTemp('holiday_schedule_');
    final path = p.join(dir.path, 'class_manager.db');
    final db = AppDatabase(databasePath: path);
    addTearDown(() async {
      await db.close();
      await dir.delete(recursive: true);
    });
    await db.insertCourse(
      Course(name: '第五周周二', day: 2, startPeriod: 1, endPeriod: 2, weeks: '5'),
    );
    final connection = await db.database;
    // 模拟v1.0.3已有的数据库：去掉新设置，保留原课程和旧设置。
    await connection.delete(
      'settings',
      where: 'key IN (?, ?, ?)',
      whereArgs: [
        'holiday_adjustment_enabled',
        'use_national_holidays',
        'schedule_adjustments',
      ],
    );
    await db.close();
    final state = AppState(db);
    await state.reload();
    expect(state.settings.holidayAdjustmentEnabled, isFalse);
    await state.updateSettings(
      state.settings.copyWith(holidayAdjustmentEnabled: true),
    );
    await state.saveAdjustment(
      ScheduleAdjustment(
        date: '2026-09-20',
        type: AdjustmentType.makeup,
        sourceDate: '2026-10-06',
        label: '校历调课',
      ),
    );
    await db.close();
    final reopened = AppState(db);
    await reopened.reload();
    expect(reopened.settings.scheduleAdjustments.single.label, '校历调课');
    expect(
      reopened.occurrencesOn(parseDate('2026-09-20')).single.course.name,
      '第五周周二',
    );
    expect(reopened.courses.single.day, 2);
    expect(reopened.courses.single.weeks, '5');
  });
}
