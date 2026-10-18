import 'package:class_manager/models/agenda_event.dart';
import 'package:class_manager/models/periods.dart';
import 'package:class_manager/services/schedule_resolver.dart';

class AgendaDayItem {
  final AgendaEvent? event;
  final CourseOccurrence? course;
  final DateTime startAt;
  final DateTime endAt;
  const AgendaDayItem({
    this.event,
    this.course,
    required this.startAt,
    required this.endAt,
  });

  String get name => event?.name ?? course!.course.name;
  String get location => event?.location ?? course!.course.location;
  String get description => event?.description ?? course!.course.note;
  String get categoryLabel => event?.categoryLabel ?? '课程';
  int get colorValue => event?.colorValue ?? course!.course.colorValue;
  bool get crossesDay =>
      event != null &&
      calendarDate(event!.startAt) != calendarDate(event!.endAt);
  String get startLabel => agendaTime(startAt);
  String endLabel(DateTime day) =>
      endAt.isAfter(calendarDate(day)) &&
          endAt == DateTime(day.year, day.month, day.day + 1)
      ? '24:00'
      : agendaTime(endAt);

  bool overlaps(AgendaDayItem other) =>
      startAt.isBefore(other.endAt) && endAt.isAfter(other.startAt);
}

class AgendaTimeline {
  static List<AgendaDayItem> forDay(
    DateTime day,
    Iterable<AgendaEvent> events, {
    Iterable<CourseOccurrence> courses = const [],
  }) {
    final start = calendarDate(day);
    final end = DateTime(day.year, day.month, day.day + 1);
    DateTime atTime(String time) {
      final parts = time.split(':');
      return DateTime(
        day.year,
        day.month,
        day.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
    }

    final items = [
      for (final event in events.where((e) => e.overlapsDay(day)))
        AgendaDayItem(
          event: event,
          startAt: event.startAt.isBefore(start) ? start : event.startAt,
          endAt: event.endAt.isAfter(end) ? end : event.endAt,
        ),
      for (final course in courses)
        AgendaDayItem(
          course: course,
          startAt: atTime(periodOf(course.course.startPeriod).start),
          endAt: atTime(periodOf(course.course.endPeriod).end),
        ),
    ];
    items.sort((a, b) {
      var result = a.startAt.compareTo(b.startAt);
      if (result == 0) result = a.endAt.compareTo(b.endAt);
      if (result == 0) result = a.name.compareTo(b.name);
      return result;
    });
    return items;
  }
}
