/// 武汉大学一天的实际课程安排：一天 13 节课（依据「学生课表.doc」）。
class Period {
  final int index; // 1..13
  final String name; // 第一节 ...
  final String start; // '08:00'
  final String end; // '08:45'

  const Period(this.index, this.name, this.start, this.end);

  String get range => '$start~$end';
}

const List<Period> kPeriods = [
  Period(1, '第一节', '08:00', '08:45'),
  Period(2, '第二节', '08:50', '09:35'),
  Period(3, '第三节', '09:50', '10:35'),
  Period(4, '第四节', '10:40', '11:25'),
  Period(5, '第五节', '11:30', '12:15'),
  Period(6, '第六节', '14:05', '14:50'),
  Period(7, '第七节', '14:55', '15:40'),
  Period(8, '第八节', '15:45', '16:30'),
  Period(9, '第九节', '16:40', '17:25'),
  Period(10, '第十节', '17:30', '18:15'),
  Period(11, '第十一节', '18:30', '19:15'),
  Period(12, '第十二节', '19:20', '20:05'),
  Period(13, '第十三节', '20:10', '20:55'),
];

const int kPeriodCount = 13;

Period periodOf(int index) {
  if (index < 1) return kPeriods.first;
  if (index > kPeriodCount) return kPeriods.last;
  return kPeriods[index - 1];
}

const List<String> kWeekdayNames = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

String weekdayName(int day) => kWeekdayNames[(day - 1).clamp(0, 6)];

/// 中文数字 → 阿拉伯数字（用于解析「第六节」），失败返回 null。
int? chineseNumber(String s) {
  const map = {
    '一': 1, '二': 2, '三': 3, '四': 4, '五': 5, '六': 6, '七': 7,
    '八': 8, '九': 9, '十': 10, '十一': 11, '十二': 12, '十三': 13,
  };
  return map[s];
}

String numberToChinese(int n) {
  const names = [
    '', '一', '二', '三', '四', '五', '六', '七', '八', '九', '十',
    '十一', '十二', '十三',
  ];
  return n >= 1 && n <= 13 ? names[n] : n.toString();
}
