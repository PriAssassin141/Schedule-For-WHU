import 'dart:io';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:class_manager/db/app_database.dart';
import 'package:class_manager/models/app_settings.dart';
import 'package:class_manager/models/course.dart';
import 'package:class_manager/models/exam.dart';
import 'package:class_manager/models/agenda_event.dart';
import 'package:class_manager/services/agenda_timeline.dart';
import 'package:class_manager/models/schedule_adjustment.dart';
import 'package:class_manager/services/schedule_resolver.dart';
import 'package:class_manager/services/schedule_parser.dart';
import 'package:class_manager/theme/palette.dart';
import 'package:class_manager/utils/weeks.dart';

/// 全局状态（Provider ChangeNotifier）。
class AppState extends ChangeNotifier {
  final AppDatabase? db;

  List<Course> courses = [];
  List<Exam> exams = [];
  List<AgendaEvent> agendaEvents = [];
  DateTime agendaDate = calendarDate(DateTime.now());
  int? _courseWeekOnAgendaExit;
  AppSettings settings = AppSettings();

  int selectedDay = 1; // 1..7
  int browseWeek = 1; // 当前浏览的周
  bool bannerExpanded = true;

  AppState(this.db);

  /// 从数据库初始化。
  static Future<AppState> create() async {
    final db = AppDatabase();
    final state = AppState(db);
    await state.reload();
    return state;
  }

  /// 内存模式（测试用，无数据库）。
  AppState.memory() : db = null;

  Future<void> reload() async {
    if (db == null) return;
    courses = await db!.loadCourses();
    exams = await db!.loadExams();
    agendaEvents = await db!.loadAgendaEvents();
    settings = await db!.loadSettings();
    browseWeek = currentWeek;
    notifyListeners();
  }

  // ---------- 计算辅助 ----------

  int get currentWeek => weekOf(DateTime.now(), settings.startDate);

  /// 第 week 周、第 day 天对应的日期。
  DateTime dateOf(int week, int day) =>
      dateOfWeekDay(week, day, settings.startDate);

  /// 课程在第 week 周是否上课。
  bool courseActiveInWeek(Course c, int week) => Weeks.contains(c.weeks, week);

  /// 指定星期当周的可见课程（按周次过滤）。
  List<Course> coursesOn(int day, int week) =>
      occurrencesOn(dateOf(week, day)).map((o) => o.course).toList();

  List<CourseOccurrence> occurrencesOn(DateTime date) =>
      ScheduleResolver(settings).on(date, courses);

  List<CourseOccurrence> occurrencesInWeek(int week) =>
      [for (var day = 1; day <= 7; day++) ...occurrencesOn(dateOf(week, day))]
        ..sort((a, b) => a.course.startPeriod.compareTo(b.course.startPeriod));

  ScheduleAdjustment? adjustmentOn(DateTime date) =>
      ScheduleResolver(settings).adjustmentOn(date);

  Future<void> saveAdjustment(
    ScheduleAdjustment rule, {
    String? replacingDate,
    bool suspendSource = false,
  }) async {
    final rules = settings.scheduleAdjustments
        .where((r) => r.date != rule.date && r.date != replacingDate)
        .toList();
    if (suspendSource && rule.type == AdjustmentType.makeup) {
      rules.removeWhere((r) => r.date == rule.sourceDate);
      rules.add(
        ScheduleAdjustment(
          date: rule.sourceDate!,
          type: AdjustmentType.rest,
          label: '手动调课停课',
        ),
      );
    }
    rules.add(rule);
    rules.sort((a, b) => a.date.compareTo(b.date));
    await updateSettings(settings.copyWith(scheduleAdjustments: rules));
  }

  Future<void> removeAdjustment(String date) => updateSettings(
    settings.copyWith(
      scheduleAdjustments: settings.scheduleAdjustments
          .where((r) => r.date != date)
          .toList(),
    ),
  );

  Color courseColor(Course c) => Color(c.colorValue);

  /// 给新课程挑选一个尽量未被使用的颜色。
  int pickCourseColor({Course? exclude}) {
    final used = <int, int>{};
    for (final c in courses) {
      if (exclude != null && c.id != null && c.id == exclude.id) continue;
      used[c.colorValue] = (used[c.colorValue] ?? 0) + 1;
    }
    int best = kCourseColors.first;
    var bestCount = 1 << 30;
    for (final color in kCourseColors) {
      final count = used[color] ?? 0;
      if (count < bestCount) {
        bestCount = count;
        best = color;
      }
    }
    return best;
  }

  // ---------- 界面状态 ----------
  List<AgendaDayItem> agendaItemsOn(
    DateTime date, {
    bool includeCourses = false,
  }) => AgendaTimeline.forDay(
    date,
    agendaEvents,
    courses: includeCourses ? occurrencesOn(date) : const [],
  );

  void setAgendaDate(DateTime date) {
    final first = DateTime(2000);
    final last = DateTime(2100, 12, 31);
    agendaDate = date.isBefore(first)
        ? first
        : date.isAfter(last)
        ? last
        : calendarDate(date);
    selectedDay = agendaDate.weekday;
    notifyListeners();
  }

  Future<void> setHomeViewMode(HomeViewMode mode) async {
    if (settings.homeViewMode == mode) return;
    final previous = settings.homeViewMode;
    final next = settings.copyWith(homeViewMode: mode);
    if (db != null) await db!.saveSettings(next);
    settings = next;
    if (previous == HomeViewMode.courses &&
        mode != HomeViewMode.courses &&
        (_courseWeekOnAgendaExit == null ||
            _courseWeekOnAgendaExit != browseWeek)) {
      agendaDate = browseWeek == currentWeek
          ? calendarDate(DateTime.now())
          : dateOf(browseWeek, selectedDay);
    } else if (mode == HomeViewMode.courses) {
      browseWeek = weekOf(agendaDate, settings.startDate);
      _courseWeekOnAgendaExit = browseWeek;
    }
    notifyListeners();
  }

  Future<AgendaEvent> saveAgendaEvent(AgendaEvent event) async {
    var saved = event;
    if (event.id == null) {
      final id = db != null
          ? await db!.insertAgendaEvent(event)
          : agendaEvents.fold<int>(
                  0,
                  (max, e) => (e.id ?? 0) > max ? e.id! : max,
                ) +
                1;
      saved = event.copyWith(id: id);
      agendaEvents.add(saved);
    } else {
      final index = agendaEvents.indexWhere((e) => e.id == event.id);
      if (index < 0) throw StateError('日程已不存在，请返回后重试');
      if (db != null) await db!.updateAgendaEvent(event);
      agendaEvents[index] = event;
    }
    agendaEvents.sort((a, b) => a.startAt.compareTo(b.startAt));
    notifyListeners();
    return saved;
  }

  Future<String> saveAgendaCategory(String name) async {
    final label = name.trim();
    if (label.isEmpty || label.length > 20) throw ArgumentError('类型名称应为1—20字');
    if (!AgendaCategory.values.any((c) => c.label == label) &&
        !settings.agendaCustomCategories.contains(label)) {
      await updateSettings(
        settings.copyWith(
          agendaCustomCategories: [...settings.agendaCustomCategories, label],
        ),
      );
    }
    return label;
  }

  Future<void> deleteAgendaEvent(AgendaEvent event) async {
    if (db != null && event.id != null) await db!.deleteAgendaEvent(event.id!);
    agendaEvents.removeWhere((e) => e.id == event.id);
    notifyListeners();
  }

  void setBrowseWeek(int w) {
    browseWeek = w.clamp(1, kMaxWeek);
    notifyListeners();
  }

  void setSelectedDay(int d) {
    selectedDay = d.clamp(1, 7);
    notifyListeners();
  }

  void toggleBanner() {
    bannerExpanded = !bannerExpanded;
    notifyListeners();
  }

  // ---------- 课程 CRUD ----------

  Future<void> addCourse(Course c) async {
    if (db != null) {
      c.id = await db!.insertCourse(c);
    }
    courses.add(c);
    notifyListeners();
  }

  Future<void> updateCourse(Course c) async {
    if (db != null && c.id != null) {
      await db!.updateCourse(c);
    }
    final i = courses.indexWhere((x) => x.id == c.id);
    if (i >= 0) {
      courses[i] = c;
    }
    notifyListeners();
  }

  Future<void> deleteCourse(Course c) async {
    if (db != null && c.id != null) {
      await db!.deleteCourse(c.id!);
    }
    courses.removeWhere((x) => x.id == c.id);
    notifyListeners();
  }

  /// 批量导入（[replace] 为 true 时先清空）。
  ///
  /// 自动为不同课程分配不同颜色：**同名课程复用同一颜色**，
  /// 新课程取当前使用次数最少的颜色（逐条累加统计，避免整批同色）。
  Future<void> importCourses(
    List<ParsedCourse> parsed, {
    bool replace = false,
  }) async {
    if (replace && db != null) {
      await db!.clearCourses();
      courses.clear();
    }

    // 现有课程的用色统计 + 课程名 → 颜色
    final used = <int, int>{};
    final nameColor = <String, int>{};
    for (final c in courses) {
      used[c.colorValue] = (used[c.colorValue] ?? 0) + 1;
      nameColor.putIfAbsent(c.name.trim(), () => c.colorValue);
    }

    int colorFor(String name) {
      final key = name.trim();
      final existing = nameColor[key];
      if (existing != null) return existing;
      var best = kCourseColors.first;
      var bestCount = 1 << 30;
      for (final color in kCourseColors) {
        final count = used[color] ?? 0;
        if (count < bestCount) {
          bestCount = count;
          best = color;
        }
      }
      used[best] = (used[best] ?? 0) + 1;
      nameColor[key] = best;
      return best;
    }

    for (final pc in parsed) {
      await addCourse(
        Course(
          name: pc.name,
          teacher: pc.teacher,
          location: pc.location,
          note: pc.note,
          day: pc.day,
          startPeriod: pc.startPeriod,
          endPeriod: pc.endPeriod,
          weeks: pc.weeks,
          colorValue: colorFor(pc.name),
        ),
      );
    }
    notifyListeners();
  }

  // ---------- 考试 CRUD ----------

  Future<void> addExam(Exam e) async {
    if (db != null) {
      e.id = await db!.insertExam(e);
    }
    exams.add(e);
    notifyListeners();
  }

  Future<void> updateExam(Exam e) async {
    if (db != null && e.id != null) {
      await db!.updateExam(e);
    }
    final i = exams.indexWhere((x) => x.id == e.id);
    if (i >= 0) {
      exams[i] = e;
    }
    notifyListeners();
  }

  Future<void> deleteExam(Exam e) async {
    if (db != null && e.id != null) {
      await db!.deleteExam(e.id!);
    }
    exams.removeWhere((x) => x.id == e.id);
    notifyListeners();
  }

  // ---------- 设置 ----------

  Future<void> updateSettings(AppSettings s) async {
    if (db != null) {
      await db!.saveSettings(s);
    }
    settings = s;
    notifyListeners();
  }

  Future<void> setStartDate(String date) async {
    await updateSettings(settings.copyWith(startDate: date));
    browseWeek = currentWeek;
  }

  /// 把壁纸文件复制进应用目录，返回新路径。
  Future<String> importWallpaper(Uint8List bytes, String originalName) async {
    final dir = await getApplicationDocumentsDirectory();
    final wallDir = Directory(p.join(dir.path, 'wallpapers'));
    if (!await wallDir.exists()) {
      await wallDir.create(recursive: true);
    }
    final ext = p.extension(originalName).isEmpty
        ? '.jpg'
        : p.extension(originalName);
    final name = 'wp_${DateTime.now().millisecondsSinceEpoch}$ext';
    final file = File(p.join(wallDir.path, name));
    await file.writeAsBytes(bytes);
    return file.path;
  }
}
