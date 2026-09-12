import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:class_manager/db/app_database.dart';
import 'package:class_manager/models/app_settings.dart';
import 'package:class_manager/models/course.dart';
import 'package:class_manager/models/exam.dart';
import 'package:class_manager/services/campus_net.dart';
import 'package:class_manager/services/schedule_parser.dart';
import 'package:class_manager/theme/palette.dart';
import 'package:class_manager/utils/weeks.dart';

/// 全局状态（Provider ChangeNotifier）。
class AppState extends ChangeNotifier {
  final AppDatabase? db;

  List<Course> courses = [];
  List<Exam> exams = [];
  AppSettings settings = AppSettings();

  int selectedDay = 1; // 1..7
  int browseWeek = 1; // 当前浏览的周
  bool bannerExpanded = true;

  /// 校园网状态提示（临时状态，不持久化）
  String campusStatus = '';
  bool campusBusy = false;

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
  bool courseActiveInWeek(Course c, int week) =>
      Weeks.contains(c.weeks, week);

  /// 指定星期当周的可见课程（按周次过滤）。
  List<Course> coursesOn(int day, int week) => courses
      .where((c) => c.day == day && courseActiveInWeek(c, week))
      .toList()
    ..sort((a, b) => a.startPeriod.compareTo(b.startPeriod));

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
  Future<void> importCourses(List<ParsedCourse> parsed,
      {bool replace = false}) async {
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
      await addCourse(Course(
        name: pc.name,
        teacher: pc.teacher,
        location: pc.location,
        note: pc.note,
        day: pc.day,
        startPeriod: pc.startPeriod,
        endPeriod: pc.endPeriod,
        weeks: pc.weeks,
        colorValue: colorFor(pc.name),
      ));
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
    settings = s;
    if (db != null) {
      await db!.saveSettings(s);
    }
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
    final ext = p.extension(originalName).isEmpty ? '.jpg' : p.extension(originalName);
    final name = 'wp_${DateTime.now().millisecondsSinceEpoch}$ext';
    final file = File(p.join(wallDir.path, name));
    await file.writeAsBytes(bytes);
    return file.path;
  }

  // ---------- 校园网 ----------

  /// 历史账号（用于账号下拉）。
  List<String> get campusUserHistory {
    try {
      final list = jsonDecode(settings.campusUserHistory) as List;
      return list.map((e) => e.toString()).toList();
    } catch (_) {
      return const [];
    }
  }

  /// 保存校园网账号 / 运营商 / 自动登录开关。
  Future<void> saveCampusAccount({
    String? user,
    String? password,
    CampusService? service,
    bool? autoLogin,
  }) =>
      updateSettings(settings.copyWith(
        campusUser: user,
        campusPassword: password,
        campusService: service?.code,
        campusAutoLogin: autoLogin,
      ));

  /// 登录成功后把账号加入历史列表（最多 5 个）。
  Future<void> _rememberCampusUser(String user) async {
    final u = user.trim();
    if (u.isEmpty) return;
    final list = campusUserHistory..remove(u);
    list.insert(0, u);
    final trimmed = list.take(5).toList();
    await updateSettings(
        settings.copyWith(campusUserHistory: jsonEncode(trimmed)));
  }

  /// 手动登录校园网。
  Future<String> campusLogin({CampusService? service}) async {
    if (campusBusy) return campusStatus;
    campusBusy = true;
    campusStatus = '正在登录校园网…';
    notifyListeners();

    final svc = service ?? CampusService.fromCode(settings.campusService);
    final res = await CampusNet.login(
      username: settings.campusUser,
      password: settings.campusPassword,
      service: svc,
    );
    campusBusy = false;
    campusStatus = res.message;
    if (res.success) {
      await _rememberCampusUser(settings.campusUser);
    } else {
      notifyListeners();
    }
    return res.message;
  }

  /// 注销校园网。
  Future<String> campusLogout() async {
    if (campusBusy) return campusStatus;
    campusBusy = true;
    campusStatus = '正在注销…';
    notifyListeners();
    final res = await CampusNet.logout();
    campusBusy = false;
    campusStatus = res.message;
    notifyListeners();
    return res.message;
  }

  /// 自动登录：连接武大校园 WiFi 且已保存账号时执行。
  ///
  /// 返回登录结果文案；未执行时返回 null。
  Future<String?> tryCampusAutoLogin() async {
    if (campusBusy) return null;
    if (!settings.campusAutoLogin) return null;
    if (settings.campusUser.trim().isEmpty || settings.campusPassword.isEmpty) {
      return null;
    }
    campusBusy = true;
    campusStatus = '正在自动登录校园网…';
    notifyListeners();

    final res = await CampusNet.autoLogin(
      username: settings.campusUser,
      password: settings.campusPassword,
      service: CampusService.fromCode(settings.campusService),
    );
    campusBusy = false;
    campusStatus = res.message;
    notifyListeners();
    return res.message;
  }
}
