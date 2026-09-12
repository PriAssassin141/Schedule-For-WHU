import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'package:class_manager/models/app_settings.dart';
import 'package:class_manager/models/course.dart';
import 'package:class_manager/models/exam.dart';

/// SQLite 本地数据库（drift 亦可用，这里选用更轻量的 sqflite）。
class AppDatabase {
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'class_manager.db');
    _db = await openDatabase(path, version: 1, onCreate: _onCreate);
    await _initDefaults(_db!);
    return _db!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE courses(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        teacher TEXT DEFAULT '',
        location TEXT DEFAULT '',
        note TEXT DEFAULT '',
        day INTEGER NOT NULL,
        start_period INTEGER NOT NULL,
        end_period INTEGER NOT NULL,
        weeks TEXT DEFAULT '',
        color INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE exams(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        location TEXT DEFAULT '',
        date TEXT NOT NULL,
        start_time TEXT DEFAULT '',
        end_time TEXT DEFAULT '',
        note TEXT DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE settings(
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
  }

  // ---------- 课程 ----------

  Future<List<Course>> loadCourses() async {
    final db = await database;
    final rows = await db.query('courses', orderBy: 'day, start_period');
    return rows.map(Course.fromMap).toList();
  }

  Future<int> insertCourse(Course c) async {
    final db = await database;
    final map = c.toMap()..remove('id');
    return db.insert('courses', map);
  }

  Future<void> updateCourse(Course c) async {
    final db = await database;
    await db.update('courses', c.toMap(),
        where: 'id = ?', whereArgs: [c.id]);
  }

  Future<void> deleteCourse(int id) async {
    final db = await database;
    await db.delete('courses', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearCourses() async {
    final db = await database;
    await db.delete('courses');
  }

  // ---------- 考试 ----------

  Future<List<Exam>> loadExams() async {
    final db = await database;
    final rows = await db.query('exams', orderBy: 'date');
    return rows.map(Exam.fromMap).toList();
  }

  Future<int> insertExam(Exam e) async {
    final db = await database;
    final map = e.toMap()..remove('id');
    return db.insert('exams', map);
  }

  Future<void> updateExam(Exam e) async {
    final db = await database;
    await db.update('exams', e.toMap(), where: 'id = ?', whereArgs: [e.id]);
  }

  Future<void> deleteExam(int id) async {
    final db = await database;
    await db.delete('exams', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- 设置 ----------

  Future<AppSettings> loadSettings() async {
    final db = await database;
    final rows = await db.query('settings');
    return settingsFromRows(rows);
  }

  Future<void> saveSettings(AppSettings s) async {
    final db = await database;
    final batch = db.batch();
    s.toMap().forEach((k, v) {
      batch.insert(
        'settings',
        {'key': k, 'value': v?.toString() ?? ''},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
    await batch.commit(noResult: true);
  }

  // ---------- 首启初始化 ----------

  /// 仅初始化默认设置；课程 / 考试默认为空，由用户自行添加或导入。
  Future<void> _initDefaults(Database db) async {
    final settingCount = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM settings')) ??
        0;
    if (settingCount == 0) {
      AppSettings().toMap().forEach((k, v) {
        db.insert('settings', {'key': k, 'value': v?.toString() ?? ''});
      });
    }
  }
}

/// 把 `settings` 表的行还原为 [AppSettings]。
///
/// 以「默认设置」为模板按字段类型自动解析，**新增设置项无需再手写解析代码**
/// （此前手写的 key 列表曾导致 show_grid / user_name 重启后失效）。
AppSettings settingsFromRows(List<Map<String, Object?>> rows) {
  final stored = <String, String>{
    for (final r in rows)
      if (r['key'] != null) r['key'] as String: (r['value'] ?? '').toString(),
  };

  final map = <String, Object?>{};
  AppSettings().toMap().forEach((key, def) {
    final raw = stored[key];
    if (raw == null || raw.isEmpty || raw == 'null') {
      map[key] = def; // 未存过 / 已清空 → 用默认值
      return;
    }
    if (def is int) {
      map[key] = int.tryParse(raw) ?? def;
    } else if (def is double) {
      map[key] = double.tryParse(raw) ?? def;
    } else {
      map[key] = raw; // 字符串（如 wallpaper_path 等可空字段）
    }
  });
  return AppSettings.fromMap(map);
}
