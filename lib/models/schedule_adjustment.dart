import 'dart:convert';

import 'package:class_manager/utils/weeks.dart';

enum AdjustmentType { rest, makeup, normal }

/// 按实际日期覆盖课表。补课始终读取原始课表，避免循环调课。
class ScheduleAdjustment {
  final String date;
  final AdjustmentType type;
  final String? sourceDate;
  final String label;

  ScheduleAdjustment({
    required this.date,
    required this.type,
    this.sourceDate,
    this.label = '',
  }) {
    if (!isValidDate(date) ||
        (type == AdjustmentType.makeup &&
            (!isValidDate(sourceDate) || sourceDate == date))) {
      throw ArgumentError('请设置有效且不同的补课日期与原课表日期');
    }
  }

  String get description => switch (type) {
    AdjustmentType.rest => '停课',
    AdjustmentType.makeup => '补 ${fmtDateShort(parseDate(sourceDate!))} 的课',
    AdjustmentType.normal => '按原课表上课',
  };

  Map<String, Object?> toMap() => {
    'date': date,
    'type': type.name,
    'source_date': sourceDate,
    'label': label,
  };

  static bool isValidDate(String? value) {
    if (value == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      return false;
    }
    final parsed = DateTime.tryParse(value);
    return parsed != null && fmtDate(parsed) == value;
  }

  static String encode(List<ScheduleAdjustment> rules) =>
      jsonEncode(rules.map((r) => r.toMap()).toList());

  /// 旧版本没有此字段；损坏的单条记录不会影响其它记录与课程。
  static List<ScheduleAdjustment> decode(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final data = jsonDecode(raw);
      if (data is! List) return [];
      final rules = <String, ScheduleAdjustment>{};
      for (final item in data) {
        try {
          if (item is! Map) continue;
          final rule = ScheduleAdjustment(
            date: item['date'] as String,
            type: AdjustmentType.values.byName(item['type'] as String),
            sourceDate: item['source_date'] as String?,
            label: (item['label'] as String?) ?? '',
          );
          rules[rule.date] = rule;
        } catch (_) {
          // 忽略无法还原的单条设置。
        }
      }
      return rules.values.toList()..sort((a, b) => a.date.compareTo(b.date));
    } catch (_) {
      return [];
    }
  }
}
