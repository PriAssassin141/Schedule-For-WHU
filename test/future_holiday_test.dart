import 'package:flutter_test/flutter_test.dart';

import 'package:class_manager/models/app_settings.dart';
import 'package:class_manager/models/course.dart';
import 'package:class_manager/models/schedule_adjustment.dart';
import 'package:class_manager/services/holiday_calendar.dart';
import 'package:class_manager/state/app_state.dart';
import 'package:class_manager/utils/weeks.dart';

void main() {
  test('年份连续支持2025至2035，未来日期不包含推测的补班', () {
    expect(HolidayCalendar.supportedYears, List.generate(11, (i) => 2025 + i));
    for (var year = 2027; year <= 2035; year++) {
      final rules = HolidayCalendar.forYear(year);
      expect(rules.length, year == 2028 || year == 2031 ? 12 : 13);
      expect(rules.every((r) => r.type == AdjustmentType.rest), isTrue);
      expect(HolidayCalendar.hasPublishedSchedule(year), isFalse);
    }
    expect(HolidayCalendar.hasCalendar(2035), isTrue);
    expect(HolidayCalendar.hasCalendar(2036), isFalse);
  });

  test('法定节日符合公历农历对照表，闰月不重复生成节日', () {
    const festivals = {
      2027: ['02-06', '04-05', '06-09', '09-15'],
      2028: ['01-26', '04-04', '05-28', '10-03'],
      2029: ['02-13', '04-04', '06-16', '09-22'],
      2030: ['02-03', '04-05', '06-05', '09-12'],
      2031: ['01-23', '04-05', '06-24', '10-01'],
      2032: ['02-11', '04-04', '06-12', '09-19'],
      2033: ['01-31', '04-04', '06-01', '09-08'],
      2034: ['02-19', '04-05', '06-20', '09-27'],
      2035: ['02-08', '04-05', '06-10', '09-16'],
    };
    const names = ['春节', '清明节', '端午节', '中秋节'];
    for (final entry in festivals.entries) {
      for (var i = 0; i < names.length; i++) {
        expect(
          HolidayCalendar.on('${entry.key}-${entry.value[i]}')!.label,
          contains(names[i]),
        );
      }
      final first = parseDate('${entry.key}-${entry.value.first}');
      expect(
        HolidayCalendar.on(
          fmtDate(first.subtract(const Duration(days: 1))),
        )!.label,
        '春节',
      );
      expect(
        HolidayCalendar.on(fmtDate(first.add(const Duration(days: 2))))!.label,
        '春节',
      );
    }
    expect(HolidayCalendar.on('2028-06-27'), isNull);
    expect(HolidayCalendar.on('2028-10-03')!.label, contains('国庆节'));
    expect(HolidayCalendar.on('2031-10-01')!.label, contains('国庆节'));
  });

  test('2035年法定假日自动停课，可手动补课和覆盖正常上课', () async {
    final date = parseDate('2035-10-01');
    final state = AppState.memory()
      ..settings = AppSettings(
        startDate: '2035-09-03',
        holidayAdjustmentEnabled: true,
      )
      ..courses = [
        Course(
          id: 1,
          name: '研究方法',
          day: date.weekday,
          startPeriod: 1,
          endPeriod: 2,
        ),
      ];
    expect(state.occurrencesOn(date), isEmpty);
    await state.saveAdjustment(
      ScheduleAdjustment(
        date: '2035-10-06',
        type: AdjustmentType.makeup,
        sourceDate: '2035-10-01',
      ),
    );
    expect(
      state.occurrencesOn(parseDate('2035-10-06')).single.course.name,
      '研究方法',
    );
    await state.saveAdjustment(
      ScheduleAdjustment(date: '2035-10-01', type: AdjustmentType.normal),
    );
    expect(state.occurrencesOn(date).single.course.name, '研究方法');
  });
}
