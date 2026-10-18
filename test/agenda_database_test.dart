import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:class_manager/db/app_database.dart';
import 'package:class_manager/models/agenda_event.dart';
import 'package:class_manager/models/course.dart';
import 'package:class_manager/models/exam.dart';
import 'package:class_manager/state/app_state.dart';

void main() {
  test('v1数据库升级保留课程考试和零值设置，日程与视图重启恢复', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final root = await Directory('.packaging').createTemp('agenda-migration-');
    final path = '${root.absolute.path}/agenda.db';
    final old = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE courses(id INTEGER PRIMARY KEY, name TEXT, teacher TEXT, location TEXT, note TEXT, day INTEGER, start_period INTEGER, end_period INTEGER, weeks TEXT, color INTEGER)',
        );
        await db.execute(
          'CREATE TABLE exams(id INTEGER PRIMARY KEY, name TEXT, location TEXT, date TEXT, start_time TEXT, end_time TEXT, note TEXT)',
        );
        await db.execute(
          'CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT)',
        );
        await db.insert(
          'courses',
          Course(
            id: 1,
            name: '保留的课程',
            day: 2,
            startPeriod: 1,
            endPeriod: 2,
          ).toMap(),
        );
        await db.insert(
          'exams',
          Exam(id: 1, name: '保留的考试', date: '2026-12-01').toMap(),
        );
        for (final entry in {
          'card_blur': '0.0',
          'card_transparency': '1.0',
          'user_name': '测试用户',
        }.entries) {
          await db.insert('settings', {'key': entry.key, 'value': entry.value});
        }
      },
    );
    await old.close();
    final db = AppDatabase(databasePath: path);
    addTearDown(() async {
      await db.close();
      await root.delete(recursive: true);
    });
    final state = AppState(db);
    await state.reload();
    expect(
      (await (await db.database).rawQuery(
        'PRAGMA user_version',
      )).single.values.single,
      3,
    );
    expect(state.settings.homeViewMode, HomeViewMode.courses);
    expect(state.settings.cardBlur, 0);
    expect(state.settings.cardTransparency, 1);
    expect(state.settings.userName, '测试用户');
    final saved = await state.saveAgendaEvent(
      AgendaEvent(
        name: '晨跑',
        startAt: DateTime(2026, 10, 18, 6, 17),
        endAt: DateTime(2026, 10, 18, 7, 3),
        category: AgendaCategory.exercise,
        location: '操场',
        description: '轻松跑',
      ),
    );
    await state.setHomeViewMode(HomeViewMode.combined);
    await db.close();
    final reopened = AppState(db);
    await reopened.reload();
    expect(reopened.settings.homeViewMode, HomeViewMode.combined);
    expect(reopened.agendaEvents.single.id, saved.id);
    expect(reopened.agendaEvents.single.startAt.minute, 17);
    expect(reopened.agendaEvents.single.location, '操场');
    expect(reopened.courses.single.name, '保留的课程');
    expect(reopened.exams.single.name, '保留的考试');
    await reopened.saveAgendaEvent(saved.copyWith(name: '晚间运动'));
    await db.close();
    await reopened.reload();
    expect(reopened.agendaEvents.single.name, '晚间运动');
    await reopened.deleteAgendaEvent(reopened.agendaEvents.single);
    await db.close();
    await reopened.reload();
    expect(reopened.agendaEvents, isEmpty);
    expect(reopened.courses.length, 1);
    expect(reopened.exams.length, 1);
  });

  test('v2升级保留日程，颜色与自定义类型可重启恢复且去重', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final root = await Directory(
      '.packaging',
    ).createTemp('agenda-custom-migration-');
    final path = '${root.absolute.path}/agenda.db';
    final initial = AppDatabase(databasePath: path);
    final original = AgendaEvent(
      name: '旧日程',
      startAt: DateTime(2026, 10, 18, 8),
      endAt: DateTime(2026, 10, 18, 9),
      category: AgendaCategory.study,
    );
    await initial.insertAgendaEvent(original);
    final raw = await initial.database;
    await raw.execute('ALTER TABLE agenda_events DROP COLUMN custom_category');
    await raw.execute('ALTER TABLE agenda_events DROP COLUMN custom_color');
    await raw.execute('PRAGMA user_version = 2');
    await initial.close();
    final db = AppDatabase(databasePath: path);
    addTearDown(() async {
      await db.close();
      await root.delete(recursive: true);
    });
    final state = AppState(db);
    await state.reload();
    expect(state.agendaEvents.single.name, '旧日程');
    expect(
      state.agendaEvents.single.colorValue,
      AgendaCategory.study.colorValue,
    );
    await state.saveAgendaCategory(' 社团 ');
    await state.saveAgendaCategory('社团');
    await state.saveAgendaCategory('学习');
    final event = state.agendaEvents.single.copyWith(
      customCategory: '社团',
      customColorValue: 0xFF123456,
    );
    await state.saveAgendaEvent(event);
    await db.close();
    await state.reload();
    expect(state.settings.agendaCustomCategories, ['社团']);
    expect(state.agendaEvents.single.categoryLabel, '社团');
    expect(state.agendaEvents.single.colorValue, 0xFF123456);
    expect(
      state.agendaItemsOn(DateTime(2026, 10, 18)).single.colorValue,
      0xFF123456,
    );
    await state.saveAgendaEvent(
      event.copyWith(clearCustomCategory: true, clearCustomColor: true),
    );
    await db.close();
    await state.reload();
    expect(state.agendaEvents.single.categoryLabel, '学习');
    expect(
      state.agendaEvents.single.colorValue,
      AgendaCategory.study.colorValue,
    );
    expect(state.settings.agendaCustomCategories, ['社团']);
  });
}
