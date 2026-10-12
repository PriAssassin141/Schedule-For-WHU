import 'package:flutter_test/flutter_test.dart';

import 'package:class_manager/db/app_database.dart';
import 'package:class_manager/models/app_settings.dart';
import 'package:class_manager/models/course.dart';
import 'package:class_manager/models/schedule_adjustment.dart';
import 'package:class_manager/services/holiday_calendar.dart';
import 'package:class_manager/services/schedule_resolver.dart';
import 'package:class_manager/state/app_state.dart';
import 'package:class_manager/utils/weeks.dart';

void main() {
  AppState autumn() => AppState.memory()
    ..settings = AppSettings(holidayAdjustmentEnabled: true)
    ..courses = [
      Course(
        id: 1,
        name: '第三周周二',
        day: 2,
        startPeriod: 1,
        endPeriod: 2,
        weeks: '3',
      ),
      Course(
        id: 2,
        name: '第五周周二',
        day: 2,
        startPeriod: 3,
        endPeriod: 4,
        weeks: '5',
      ),
      Course(
        id: 3,
        name: '第五周周三',
        day: 3,
        startPeriod: 1,
        endPeriod: 2,
        weeks: '5',
      ),
      Course(id: 4, name: '周六原课', day: 6, startPeriod: 5, endPeriod: 6),
      Course(id: 5, name: '周日原课', day: 7, startPeriod: 1, endPeriod: 2),
      Course(id: 6, name: '周五课', day: 5, startPeriod: 1, endPeriod: 2),
    ];

  test('关闭开关保留原课表，开启后假日连同周末课程停课', () {
    final state = autumn();
    expect(state.occurrencesOn(parseDate('2026-09-25')), isEmpty);
    expect(state.occurrencesOn(parseDate('2026-09-26')), isEmpty);
    expect(state.occurrencesOn(parseDate('2026-09-27')), isEmpty);
    state.settings = state.settings.copyWith(holidayAdjustmentEnabled: false);
    expect(
      state.occurrencesOn(parseDate('2026-09-25')).single.course.name,
      '周五课',
    );
    expect(
      state.occurrencesOn(parseDate('2026-09-26')).single.course.name,
      '周六原课',
    );
  });

  test('跨周补课用原日期第五周，不使用实际日期第二周', () {
    final state = autumn();
    final list = state.occurrencesOn(parseDate('2026-09-20'));
    expect(list.map((o) => o.course.name), ['第五周周二']);
    expect(fmtDate(list.single.sourceDate), '2026-10-06');
    expect(list.single.course.day, 2);
    expect(list.single.date.weekday, 7);
    expect(identical(list.single.course, state.courses[1]), isTrue);
    expect(state.occurrencesOn(parseDate('2026-10-06')), isEmpty);
  });

  test('周六补周三替换周六原课，课程与课程颜色不变', () {
    final state = autumn();
    final before = state.courses.map((c) => c.toMap()).toList();
    expect(state.coursesOn(6, 5).map((c) => c.name), ['第五周周三']);
    expect(state.courses.map((c) => c.toMap()).toList(), before);
  });

  test('手动正常上课可覆盖假日，删除覆盖后恢复国家安排', () async {
    final state = autumn();
    await state.saveAdjustment(
      ScheduleAdjustment(date: '2026-09-25', type: AdjustmentType.normal),
    );
    expect(
      state.occurrencesOn(parseDate('2026-09-25')).single.course.name,
      '周五课',
    );
    await state.removeAdjustment('2026-09-25');
    expect(state.occurrencesOn(parseDate('2026-09-25')), isEmpty);
  });

  test('手动更改国家补课对应日期，支持同时停课原日期', () async {
    final state = autumn();
    await state.saveAdjustment(
      ScheduleAdjustment(
        date: '2026-09-20',
        type: AdjustmentType.makeup,
        sourceDate: '2026-09-22',
      ),
      suspendSource: true,
    );
    expect(state.coursesOn(7, 2).single.name, '第三周周二');
    expect(state.occurrencesOn(parseDate('2026-09-22')), isEmpty);
    expect(state.settings.scheduleAdjustments.length, 2);
  });

  test('同日重复保存只保留一个覆盖，编辑日期会移除旧覆盖', () async {
    final state = autumn();
    await state.saveAdjustment(
      ScheduleAdjustment(date: '2026-09-21', type: AdjustmentType.rest),
    );
    await state.saveAdjustment(
      ScheduleAdjustment(date: '2026-09-21', type: AdjustmentType.normal),
    );
    expect(state.settings.scheduleAdjustments.length, 1);
    await state.saveAdjustment(
      ScheduleAdjustment(date: '2026-09-22', type: AdjustmentType.rest),
      replacingDate: '2026-09-21',
    );
    expect(state.settings.scheduleAdjustments.single.date, '2026-09-22');
  });

  test('不递归追踪补课链或循环，每个日期读取原始课程', () async {
    final state = autumn();
    await state.saveAdjustment(
      ScheduleAdjustment(
        date: '2026-09-22',
        type: AdjustmentType.makeup,
        sourceDate: '2026-09-26',
      ),
    );
    await state.saveAdjustment(
      ScheduleAdjustment(
        date: '2026-09-26',
        type: AdjustmentType.makeup,
        sourceDate: '2026-09-22',
      ),
    );
    expect(
      state.occurrencesOn(parseDate('2026-09-22')).single.course.name,
      '周六原课',
    );
    expect(
      state.occurrencesOn(parseDate('2026-09-26')).single.course.name,
      '第三周周二',
    );
  });

  test('无课程的原日期不会生成额外课程', () async {
    final state = autumn();
    await state.saveAdjustment(
      ScheduleAdjustment(
        date: '2026-09-20',
        type: AdjustmentType.makeup,
        sourceDate: '2026-09-21',
      ),
    );
    expect(state.coursesOn(7, 2), isEmpty);
  });

  test('学期外日期与学期外补课来源不会钳制为首周末周', () async {
    final state = autumn();
    state.courses.add(
      Course(name: '全周周一', day: 1, startPeriod: 1, endPeriod: 2),
    );
    expect(state.occurrencesOn(parseDate('2026-08-31')), isEmpty);
    expect(state.occurrencesOn(parseDate('2027-02-08')), isEmpty);
    await state.saveAdjustment(
      ScheduleAdjustment(
        date: '2026-09-20',
        type: AdjustmentType.makeup,
        sourceDate: '2026-08-31',
      ),
    );
    expect(state.coursesOn(7, 2), isEmpty);
  });

  test('第22周周日仍属于学期，非周一开学按所在周一计算', () {
    final resolver = ScheduleResolver(AppSettings(startDate: '2026-09-09'));
    expect(resolver.teachingWeek(parseDate('2026-09-07')), 1);
    expect(resolver.teachingWeek(parseDate('2027-02-07')), 22);
    expect(resolver.teachingWeek(parseDate('2027-02-08')), isNull);
  });

  test('跨年学期自动应用下一年国家安排', () {
    final state = AppState.memory()
      ..settings = AppSettings(
        startDate: '2025-09-01',
        holidayAdjustmentEnabled: true,
      )
      ..courses = [
        Course(name: '周五课', day: 5, startPeriod: 1, endPeriod: 2, weeks: '18'),
      ];
    expect(state.occurrencesOn(parseDate('2026-01-02')), isEmpty);
    expect(
      state.occurrencesOn(parseDate('2026-01-04')).single.course.name,
      '周五课',
    );
  });

  test('未知年份无国家安排，但手动规则仍有效', () async {
    final state = AppState.memory()
      ..settings = AppSettings(
        startDate: '2036-09-01',
        holidayAdjustmentEnabled: true,
      )
      ..courses = [
        Course(
          name: '原课',
          day: parseDate('2036-10-01').weekday,
          startPeriod: 1,
          endPeriod: 2,
        ),
      ];
    expect(
      state.occurrencesOn(parseDate('2036-10-01')).single.course.name,
      '原课',
    );
    await state.saveAdjustment(
      ScheduleAdjustment(date: '2036-10-01', type: AdjustmentType.rest),
    );
    expect(state.occurrencesOn(parseDate('2036-10-01')), isEmpty);
  });

  test('禁用国家安排仍执行手动安排，关闭总开关执行原课表', () async {
    final state = autumn();
    state.settings = state.settings.copyWith(useNationalHolidays: false);
    expect(
      state.occurrencesOn(parseDate('2026-09-25')).single.course.name,
      '周五课',
    );
    await state.saveAdjustment(
      ScheduleAdjustment(date: '2026-09-25', type: AdjustmentType.rest),
    );
    expect(state.occurrencesOn(parseDate('2026-09-25')), isEmpty);
    state.settings = state.settings.copyWith(holidayAdjustmentEnabled: false);
    expect(
      state.occurrencesOn(parseDate('2026-09-25')).single.course.name,
      '周五课',
    );
  });

  test('重排设置可从SQLite字符串字段完整读回，旧版本默认关闭', () {
    final saved = AppSettings(
      holidayAdjustmentEnabled: true,
      useNationalHolidays: false,
      scheduleAdjustments: [
        ScheduleAdjustment(
          date: '2026-09-20',
          type: AdjustmentType.makeup,
          sourceDate: '2026-10-06',
          label: '学校通知',
        ),
      ],
    );
    final loaded = settingsFromRows(
      saved
          .toMap()
          .entries
          .map(
            (e) => <String, Object?>{
              'key': e.key,
              'value': e.value?.toString() ?? '',
            },
          )
          .toList(),
    );
    expect(loaded.toMap(), saved.toMap());
    expect(
      loaded.copyWith(userName: '同学').scheduleAdjustments.single.sourceDate,
      '2026-10-06',
    );
    expect(settingsFromRows([]).holidayAdjustmentEnabled, isFalse);
  });

  test('拒绝不存在日期和同日补课，坏记录不影响其余设置', () {
    expect(
      () => ScheduleAdjustment(date: '2026-02-30', type: AdjustmentType.rest),
      throwsArgumentError,
    );
    expect(
      () => ScheduleAdjustment(
        date: '2026-09-20',
        type: AdjustmentType.makeup,
        sourceDate: '2026-09-20',
      ),
      throwsArgumentError,
    );
    expect(ScheduleAdjustment.decode('{broken'), isEmpty);
    final rules = ScheduleAdjustment.decode(
      '[{"date":"bad","type":"rest"},'
      '{"date":"2026-09-20","type":"rest"}]',
    );
    expect(rules.single.date, '2026-09-20');
  });

  test('国家日历的放假总日数与调休上班日期符合官方通知', () {
    final year2025 = HolidayCalendar.forYear(2025);
    final year2026 = HolidayCalendar.forYear(2026);
    expect(year2025.where((r) => r.type == AdjustmentType.rest).length, 28);
    expect(year2026.where((r) => r.type == AdjustmentType.rest).length, 33);
    expect(
      year2025.where((r) => r.type == AdjustmentType.makeup).map((r) => r.date),
      ['2025-01-26', '2025-02-08', '2025-04-27', '2025-09-28', '2025-10-11'],
    );
    expect(
      year2026.where((r) => r.type == AdjustmentType.makeup).map((r) => r.date),
      [
        '2026-01-04',
        '2026-02-14',
        '2026-02-28',
        '2026-05-09',
        '2026-09-20',
        '2026-10-10',
      ],
    );
    for (final rule in [
      ...year2025,
      ...year2026,
    ].where((r) => r.type == AdjustmentType.makeup)) {
      expect(HolidayCalendar.on(rule.sourceDate!)?.type, AdjustmentType.rest);
    }
  });
}
