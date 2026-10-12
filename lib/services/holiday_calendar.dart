import 'package:class_manager/models/schedule_adjustment.dart';
import 'package:class_manager/utils/weeks.dart';

/// 国家已公布的放假/上班安排，以及至2035年的法定节日日期（离线使用）。
/// 上班日对应的补课原日期是本应用建议，不是学校教学安排。
class HolidayCalendar {
  static const firstYear = 2025;
  static const lastYear = 2035;
  static List<int> get supportedYears =>
      List.generate(lastYear - firstYear + 1, (i) => firstYear + i);
  static bool hasCalendar(int year) => year >= firstYear && year <= lastYear;
  static bool hasPublishedSchedule(int year) => sourceUrls.containsKey(year);
  static const sourceUrls = {
    2025: 'https://www.gov.cn/zhengce/zhengceku/202411/content_6986383.htm',
    2026: 'https://www.gov.cn/zhengce/zhengceku/202511/content_7047091.htm',
  };

  static final Map<String, ScheduleAdjustment> _rules = _build();

  static ScheduleAdjustment? on(String date) => _rules[date];

  static List<ScheduleAdjustment> forYear(int year) =>
      _rules.values.where((r) => r.date.startsWith('$year-')).toList()
        ..sort((a, b) => a.date.compareTo(b.date));

  static Map<String, ScheduleAdjustment> _build() {
    final rules = <String, ScheduleAdjustment>{};
    void holiday(String name, String from, String to) {
      final end = parseDate(to);
      for (
        var date = parseDate(from);
        !date.isAfter(end);
        date = DateTime(date.year, date.month, date.day + 1)
      ) {
        final key = fmtDate(date);
        rules[key] = ScheduleAdjustment(
          date: key,
          type: AdjustmentType.rest,
          label: rules[key] == null ? name : '${rules[key]!.label} / $name',
        );
      }
    }

    void makeup(String name, String date, String source) {
      rules[date] = ScheduleAdjustment(
        date: date,
        type: AdjustmentType.makeup,
        sourceDate: source,
        label: '$name调休',
      );
    }

    holiday('元旦', '2025-01-01', '2025-01-01');
    holiday('春节', '2025-01-28', '2025-02-04');
    holiday('清明节', '2025-04-04', '2025-04-06');
    holiday('劳动节', '2025-05-01', '2025-05-05');
    holiday('端午节', '2025-05-31', '2025-06-02');
    holiday('国庆节 / 中秋节', '2025-10-01', '2025-10-08');
    makeup('春节', '2025-01-26', '2025-02-03');
    makeup('春节', '2025-02-08', '2025-02-04');
    makeup('劳动节', '2025-04-27', '2025-05-05');
    makeup('国庆节', '2025-09-28', '2025-10-07');
    makeup('国庆节', '2025-10-11', '2025-10-08');

    holiday('元旦', '2026-01-01', '2026-01-03');
    holiday('春节', '2026-02-15', '2026-02-23');
    holiday('清明节', '2026-04-04', '2026-04-06');
    holiday('劳动节', '2026-05-01', '2026-05-05');
    holiday('端午节', '2026-06-19', '2026-06-21');
    holiday('中秋节', '2026-09-25', '2026-09-27');
    holiday('国庆节', '2026-10-01', '2026-10-07');
    makeup('元旦', '2026-01-04', '2026-01-02');
    makeup('春节', '2026-02-14', '2026-02-20');
    makeup('春节', '2026-02-28', '2026-02-23');
    makeup('劳动节', '2026-05-09', '2026-05-05');
    makeup('国庆节', '2026-09-20', '2026-10-06');
    makeup('国庆节', '2026-10-10', '2026-10-07');

    // 尚未公布年度调休方案的年份只提供法定节日日期，不推测连休与补班。
    // 春节初一、清明、五月初一和八月初一依据香港天文台公历农历对照表。
    // https://www.hko.gov.hk/en/gts/time/calendar/text/files/T{year}e.txt
    const anchors = {
      2027: ['02-06', '04-05', '06-05', '09-01'],
      2028: ['01-26', '04-04', '05-24', '09-19'],
      2029: ['02-13', '04-04', '06-12', '09-08'],
      2030: ['02-03', '04-05', '06-01', '08-29'],
      2031: ['01-23', '04-05', '06-20', '09-17'],
      2032: ['02-11', '04-04', '06-08', '09-05'],
      2033: ['01-31', '04-04', '05-28', '08-25'],
      2034: ['02-19', '04-05', '06-16', '09-13'],
      2035: ['02-08', '04-05', '06-06', '09-02'],
    };
    for (final entry in anchors.entries) {
      final year = entry.key;
      final dates = entry.value.map((s) => parseDate('$year-$s')).toList();
      holiday('元旦', '$year-01-01', '$year-01-01');
      holiday(
        '春节',
        fmtDate(dates[0].subtract(const Duration(days: 1))),
        fmtDate(dates[0].add(const Duration(days: 2))),
      );
      holiday('清明节', fmtDate(dates[1]), fmtDate(dates[1]));
      holiday('劳动节', '$year-05-01', '$year-05-02');
      final dragonBoat = fmtDate(dates[2].add(const Duration(days: 4)));
      holiday('端午节', dragonBoat, dragonBoat);
      final midAutumn = fmtDate(dates[3].add(const Duration(days: 14)));
      holiday('中秋节', midAutumn, midAutumn);
      holiday('国庆节', '$year-10-01', '$year-10-03');
    }
    return rules;
  }
}
