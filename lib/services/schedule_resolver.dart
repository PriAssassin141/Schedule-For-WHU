import 'package:class_manager/models/app_settings.dart';
import 'package:class_manager/models/course.dart';
import 'package:class_manager/models/schedule_adjustment.dart';
import 'package:class_manager/services/holiday_calendar.dart';
import 'package:class_manager/utils/weeks.dart';

/// 一次实际授课，保留原课程引用，编辑时不会误改成补课日的星期。
class CourseOccurrence {
  final Course course;
  final DateTime date;
  final DateTime sourceDate;
  final ScheduleAdjustment? adjustment;

  const CourseOccurrence({
    required this.course,
    required this.date,
    required this.sourceDate,
    this.adjustment,
  });
}

class ScheduleResolver {
  final AppSettings settings;
  late final Map<String, ScheduleAdjustment> _manual = {
    for (final rule in settings.scheduleAdjustments) rule.date: rule,
  };

  ScheduleResolver(this.settings);

  ScheduleAdjustment? adjustmentOn(DateTime date) {
    if (!settings.holidayAdjustmentEnabled) return null;
    final key = fmtDate(date);
    return _manual[key] ??
        (settings.useNationalHolidays ? HolidayCalendar.on(key) : null);
  }

  /// 不使用 weekOf 的边界钳制，避免学期外日期误匹配第 1/22 周。
  int? teachingWeek(DateTime date) {
    final start = parseDate(settings.startDate);
    final monday = DateTime.utc(
      start.year,
      start.month,
      start.day - start.weekday + 1,
    );
    final offset = DateTime.utc(
      date.year,
      date.month,
      date.day,
    ).difference(monday).inDays;
    if (offset < 0 || offset >= kMaxWeek * 7) return null;
    return offset ~/ 7 + 1;
  }

  List<CourseOccurrence> on(DateTime date, List<Course> courses) {
    if (teachingWeek(date) == null) return [];
    final adjustment = adjustmentOn(date);
    if (adjustment?.type == AdjustmentType.rest) return [];
    final source = adjustment?.type == AdjustmentType.makeup
        ? parseDate(adjustment!.sourceDate!)
        : date;
    final sourceWeek = teachingWeek(source);
    if (sourceWeek == null) return [];
    return courses
        .where(
          (c) => c.day == source.weekday && Weeks.contains(c.weeks, sourceWeek),
        )
        .map(
          (c) => CourseOccurrence(
            course: c,
            date: date,
            sourceDate: source,
            adjustment: adjustment,
          ),
        )
        .toList()
      ..sort((a, b) => a.course.startPeriod.compareTo(b.course.startPeriod));
  }
}
