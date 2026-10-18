enum HomeViewMode {
  courses('课程模式', '课程'),
  agenda('日程模式', '日程'),
  combined('课程＋日程模式', '课程＋日程');

  final String label;
  final String shortLabel;
  const HomeViewMode(this.label, this.shortLabel);
  static HomeViewMode fromStored(Object? value) =>
      values.firstWhere((mode) => mode.name == value, orElse: () => courses);
}

enum AgendaCategory {
  study('学习', 0xFF7894E8),
  work('工作', 0xFF5ABBA9),
  meeting('会议', 0xFF9C80E8),
  exercise('运动', 0xFFF0A95A),
  life('生活', 0xFFE181AA),
  travel('出行', 0xFF55AED1),
  other('其他', 0xFF99A4B7);

  final String label;
  final int colorValue;
  const AgendaCategory(this.label, this.colorValue);
  static AgendaCategory fromStored(Object? value) => values.firstWhere(
    (category) => category.name == value,
    orElse: () => other,
  );
}

DateTime calendarDate(DateTime value) =>
    DateTime(value.year, value.month, value.day);
DateTime calendarMonday(DateTime value) =>
    DateTime(value.year, value.month, value.day - (value.weekday - 1));
String agendaTime(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

/// Local wall-clock dates, with minute precision. End is exclusive.
class AgendaEvent {
  final int? id;
  final String name;
  final DateTime startAt;
  final DateTime endAt;
  final String description;
  final String location;
  final AgendaCategory category;
  final String? customCategory;
  final int? customColorValue;

  String get categoryLabel => customCategory ?? category.label;
  int get colorValue => customColorValue ?? category.colorValue;

  AgendaEvent({
    this.id,
    required String name,
    required DateTime startAt,
    required DateTime endAt,
    this.description = '',
    this.location = '',
    this.category = AgendaCategory.work,
    String? customCategory,
    this.customColorValue,
  }) : customCategory = customCategory == null || customCategory.trim().isEmpty
           ? null
           : customCategory.trim(),
       name = name.trim(),
       startAt = DateTime(
         startAt.year,
         startAt.month,
         startAt.day,
         startAt.hour,
         startAt.minute,
       ),
       endAt = DateTime(
         endAt.year,
         endAt.month,
         endAt.day,
         endAt.hour,
         endAt.minute,
       ) {
    if (this.name.isEmpty) throw ArgumentError('请填写日程名称');
    if (!this.endAt.isAfter(this.startAt)) throw ArgumentError('结束时间必须晚于开始时间');
  }

  bool overlapsDay(DateTime date) {
    final start = calendarDate(date);
    final end = DateTime(date.year, date.month, date.day + 1);
    return startAt.isBefore(end) && endAt.isAfter(start);
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'start_at': startAt.toIso8601String(),
    'end_at': endAt.toIso8601String(),
    'description': description,
    'location': location,
    'category': category.name,
    'custom_category': customCategory,
    'custom_color': customColorValue,
  };

  factory AgendaEvent.fromMap(Map<String, Object?> map) => AgendaEvent(
    id: map['id'] as int?,
    name: map['name'] as String,
    startAt: DateTime.parse(map['start_at'] as String),
    endAt: DateTime.parse(map['end_at'] as String),
    description: map['description'] as String? ?? '',
    location: map['location'] as String? ?? '',
    category: AgendaCategory.fromStored(map['category']),
    customCategory: map['custom_category'] as String?,
    customColorValue: map['custom_color'] as int?,
  );

  AgendaEvent copyWith({
    int? id,
    String? name,
    DateTime? startAt,
    DateTime? endAt,
    String? description,
    String? location,
    AgendaCategory? category,
    String? customCategory,
    int? customColorValue,
    bool clearCustomCategory = false,
    bool clearCustomColor = false,
  }) => AgendaEvent(
    id: id ?? this.id,
    name: name ?? this.name,
    startAt: startAt ?? this.startAt,
    endAt: endAt ?? this.endAt,
    description: description ?? this.description,
    location: location ?? this.location,
    category: category ?? this.category,
    customCategory: clearCustomCategory
        ? null
        : customCategory ?? this.customCategory,
    customColorValue: clearCustomColor
        ? null
        : customColorValue ?? this.customColorValue,
  );
}
