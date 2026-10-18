import 'package:flutter_test/flutter_test.dart';
import 'package:class_manager/models/agenda_event.dart';
import 'package:class_manager/models/course.dart';
import 'package:class_manager/models/schedule_adjustment.dart';
import 'package:class_manager/services/agenda_timeline.dart';
import 'package:class_manager/state/app_state.dart';

void main() {
  AgendaEvent event({String name = '科研讨论', DateTime? start, DateTime? end}) =>
      AgendaEvent(
        name: name,
        startAt: start ?? DateTime(2026, 9, 7, 13, 17),
        endAt: end ?? DateTime(2026, 9, 7, 14, 23),
        category: AgendaCategory.meeting,
        location: '实验室',
        description: '讨论研究进度',
      );

  test('任意时分与完整信息可序列化，空名称和无效区间拒绝保存', () {
    final value = event();
    final restored = AgendaEvent.fromMap(value.toMap());
    expect(restored.startAt, DateTime(2026, 9, 7, 13, 17));
    expect(restored.endAt, DateTime(2026, 9, 7, 14, 23));
    expect(restored.category, AgendaCategory.meeting);
    expect(restored.location, '实验室');
    expect(restored.description, '讨论研究进度');
    expect(() => event(name: ' '), throwsArgumentError);
    expect(() => event(end: value.startAt), throwsArgumentError);
    expect(
      () => event(end: value.startAt.subtract(const Duration(minutes: 1))),
      throwsArgumentError,
    );
    expect(AgendaCategory.fromStored('unknown'), AgendaCategory.other);
    expect(HomeViewMode.fromStored('unknown'), HomeViewMode.courses);
  });

  test('跨午夜与跨年按实际日期分段，结束时刻为00:00不多显示一天', () {
    final value = event(
      start: DateTime(2026, 12, 31, 23, 47),
      end: DateTime(2027, 1, 1, 0, 13),
    );
    final first = AgendaTimeline.forDay(DateTime(2026, 12, 31), [value]).single;
    final second = AgendaTimeline.forDay(DateTime(2027, 1, 1), [value]).single;
    expect(first.startLabel, '23:47');
    expect(first.endLabel(DateTime(2026, 12, 31)), '24:00');
    expect(second.startLabel, '00:00');
    expect(second.endLabel(DateTime(2027, 1, 1)), '00:13');
    expect(identical(first.event, second.event), isTrue);
    expect(value.overlapsDay(DateTime(2027, 1, 2)), isFalse);
    final midnight = event(
      start: DateTime(2026, 12, 31, 23, 47),
      end: DateTime(2027),
    );
    expect(midnight.overlapsDay(DateTime(2027)), isFalse);
  });

  test('混合视图按真实时间排序，课程调休保留原引用，日程不随调休移动', () async {
    final state = AppState.memory();
    final source = Course(
      id: 1,
      name: '周二课',
      day: 2,
      startPeriod: 6,
      endPeriod: 7,
      weeks: '5',
    );
    state.courses = [source];
    await state.updateSettings(
      state.settings.copyWith(
        holidayAdjustmentEnabled: true,
        useNationalHolidays: false,
        scheduleAdjustments: [
          ScheduleAdjustment(
            date: '2026-09-20',
            type: AdjustmentType.makeup,
            sourceDate: '2026-10-06',
          ),
        ],
      ),
    );
    await state.saveAgendaEvent(
      event(
        start: DateTime(2026, 9, 20, 13, 17),
        end: DateTime(2026, 9, 20, 14, 23),
      ),
    );
    final items = state.agendaItemsOn(
      DateTime(2026, 9, 20),
      includeCourses: true,
    );
    expect(items.map((e) => e.name).toList(), ['科研讨论', '周二课']);
    expect(items.last.startLabel, '14:05');
    expect(identical(items.last.course!.course, source), isTrue);
    expect(items.first.overlaps(items.last), isTrue);
    expect(
      state.agendaItemsOn(DateTime(2026, 10, 6)).where((e) => e.event != null),
      isEmpty,
    );
    expect(state.agendaItemsOn(DateTime(2026, 9, 20)).length, 1);
  });

  test('学期外只有实际日程；相邻安排不视为时间重叠', () async {
    final state = AppState.memory()
      ..courses = [Course(name: '全周课', day: 1, startPeriod: 1, endPeriod: 2)];
    await state.saveAgendaEvent(
      event(
        start: DateTime(2036, 2, 4, 8, 7),
        end: DateTime(2036, 2, 4, 9, 13),
      ),
    );
    await state.saveAgendaEvent(
      event(
        name: '下一项',
        start: DateTime(2036, 2, 4, 9, 13),
        end: DateTime(2036, 2, 4, 10),
      ),
    );
    final items = state.agendaItemsOn(
      DateTime(2036, 2, 4),
      includeCourses: true,
    );
    expect(items.length, 2);
    expect(items.every((e) => e.course == null), isTrue);
    expect(items.first.overlaps(items.last), isFalse);
  });

  test('日程使用独立ID，编辑和删除仅影响对应记录', () async {
    final state = AppState.memory();
    final first = await state.saveAgendaEvent(event());
    final second = await state.saveAgendaEvent(event(name: '另一项'));
    expect(first.id, isNot(second.id));
    await state.saveAgendaEvent(first.copyWith(name: '修改后的日程'));
    expect(state.agendaEvents.length, 2);
    await state.deleteAgendaEvent(second);
    expect(state.agendaEvents.single.name, '修改后的日程');
    expect(state.agendaEvents.single.id, first.id);
  });

  test('切换视图保留学期外日期，实际更换课程周后才同步日程周', () async {
    final state = AppState.memory()..browseWeek = 1;
    await state.setHomeViewMode(HomeViewMode.agenda);
    state.setAgendaDate(DateTime(2036, 2, 4));
    await state.setHomeViewMode(HomeViewMode.courses);
    await state.setHomeViewMode(HomeViewMode.combined);
    expect(state.agendaDate, DateTime(2036, 2, 4));
    await state.setHomeViewMode(HomeViewMode.courses);
    state.setBrowseWeek(2);
    await state.setHomeViewMode(HomeViewMode.agenda);
    expect(calendarMonday(state.agendaDate), state.dateOf(2, 1));
  });
}
