import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:class_manager/models/periods.dart';
import 'package:class_manager/models/schedule_adjustment.dart';
import 'package:class_manager/services/holiday_calendar.dart';
import 'package:class_manager/services/schedule_resolver.dart';
import 'package:class_manager/state/app_state.dart';
import 'package:class_manager/utils/weeks.dart';
import 'package:class_manager/widgets/app_background.dart';
import 'package:class_manager/widgets/glass.dart';
import 'package:class_manager/widgets/glass_dialog.dart';

class ScheduleAdjustmentScreen extends StatefulWidget {
  final DateTime? initialDate;
  const ScheduleAdjustmentScreen({super.key, this.initialDate});

  @override
  State<ScheduleAdjustmentScreen> createState() =>
      _ScheduleAdjustmentScreenState();
}

class _ScheduleAdjustmentScreenState extends State<ScheduleAdjustmentScreen> {
  late int _year;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _year =
        (widget.initialDate ??
                parseDate(context.read<AppState>().settings.startDate))
            .year;
    if (widget.initialDate != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final key = fmtDate(widget.initialDate!);
        ScheduleAdjustment? manual;
        for (final r in context.read<AppState>().settings.scheduleAdjustments) {
          if (r.date == key) manual = r;
        }
        _edit(rule: manual ?? HolidayCalendar.on(key), manual: manual != null);
      });
    }
  }

  Future<void> _persist(Future<void> Function() action) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('保存失败，请重试')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _edit({ScheduleAdjustment? rule, bool manual = false}) async {
    final state = context.read<AppState>();
    final currentDate = widget.initialDate ?? state.dateOf(state.browseWeek, 1);
    final result = await showDialog<({ScheduleAdjustment rule, bool suspend})>(
      context: context,
      builder: (_) => _AdjustmentEditor(
        state: state,
        rule: rule,
        initialDate: currentDate.year == _year ? currentDate : DateTime(_year),
      ),
    );
    if (result == null || !mounted) return;
    await _persist(
      () => state.saveAdjustment(
        result.rule,
        replacingDate: manual ? rule?.date : null,
        suspendSource: result.suspend,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final settings = state.settings;
    final national = HolidayCalendar.forYear(_year);
    final manual = settings.scheduleAdjustments
        .where((r) => r.date.startsWith('$_year-'))
        .toList();
    final overridden = manual.map((r) => r.date).toSet();
    final years = <int>{
      ...HolidayCalendar.supportedYears,
      _year,
      parseDate(settings.startDate).year,
      state.dateOf(kMaxWeek, 7).year,
      ...settings.scheduleAdjustments.map((r) => parseDate(r.date).year),
    }.toList()..sort();

    return BackgroundedScaffold(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                GlassIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    '节假日与调休',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  key: const ValueKey('add_adjustment'),
                  tooltip: '添加手动安排',
                  onPressed: _saving ? null : () => _edit(),
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                LiquidGlass(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      SwitchListTile(
                        key: const ValueKey('holiday_adjustment_enabled'),
                        title: const Text('智能重排课表'),
                        subtitle: const Text('开启后，停课与补课安排即时生效'),
                        value: settings.holidayAdjustmentEnabled,
                        onChanged: _saving
                            ? null
                            : (value) => _persist(
                                () => state.updateSettings(
                                  settings.copyWith(
                                    holidayAdjustmentEnabled: value,
                                  ),
                                ),
                              ),
                      ),
                      SwitchListTile(
                        key: const ValueKey('use_national_holidays'),
                        title: const Text('使用国家节假日安排'),
                        subtitle: const Text('手动设置优先'),
                        value: settings.useNationalHolidays,
                        onChanged: _saving
                            ? null
                            : (value) => _persist(
                                () => state.updateSettings(
                                  settings.copyWith(useNationalHolidays: value),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                LiquidGlass(
                  child: const Text(
                    '国家安排规定放假及调休上班日期。补哪天的课为应用建议，请按学校通知修改。'
                    '补课使用原日期的周次，替换补课日整天课表；不顺延整个学期。',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.6,
                      color: Colors.white70,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Expanded(child: Text('查看年份')),
                    GlassSelect<int>(
                      key: const ValueKey('adjustment_year'),
                      title: '选择年份',
                      value: _year,
                      options: {for (final y in years) y: '$y 年'},
                      onChanged: (y) {
                        setState(() => _year = y);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '手动安排',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (manual.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      '暂无手动安排，点击右上角 + 添加',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ),
                for (final r in manual) _ruleTile(r, state, isManual: true),
                const SizedBox(height: 16),
                Text(
                  HolidayCalendar.hasPublishedSchedule(_year)
                      ? '国家安排'
                      : '法定节假日',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (!HolidayCalendar.hasCalendar(_year))
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      '此年份可手动添加停课或补课安排。',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  )
                else ...[
                  if (!HolidayCalendar.hasPublishedSchedule(_year))
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        '具体调休请按学校通知手动设置。',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  for (final r in national)
                    _ruleTile(
                      r,
                      state,
                      overridden: overridden.contains(r.date),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ruleTile(
    ScheduleAdjustment rule,
    AppState state, {
    bool isManual = false,
    bool overridden = false,
  }) {
    final date = parseDate(rule.date);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: LiquidGlass(
        padding: EdgeInsets.zero,
        child: ListTile(
          key: ValueKey('${isManual ? 'manual' : 'national'}_${rule.date}'),
          title: Text(
            '${rule.date} ${weekdayName(date.weekday)}',
            style: const TextStyle(fontSize: 13),
          ),
          subtitle: Text(
            '${rule.label.isEmpty ? '' : '${rule.label} · '}${rule.description}'
            '${overridden ? '（已手动覆盖）' : ''}'
            '${!isManual && rule.type == AdjustmentType.makeup ? '（建议）' : ''}',
            style: const TextStyle(fontSize: 11),
          ),
          onTap: _saving ? null : () => _edit(rule: rule, manual: isManual),
          trailing: isManual
              ? IconButton(
                  tooltip: '删除手动安排，恢复国家或原课表安排',
                  icon: const Icon(Icons.delete_outline_rounded, size: 19),
                  onPressed: _saving
                      ? null
                      : () => _persist(() => state.removeAdjustment(rule.date)),
                )
              : const Icon(Icons.edit_outlined, size: 16),
        ),
      ),
    );
  }
}

class _AdjustmentEditor extends StatefulWidget {
  final AppState state;
  final ScheduleAdjustment? rule;
  final DateTime initialDate;
  const _AdjustmentEditor({
    required this.state,
    this.rule,
    required this.initialDate,
  });

  @override
  State<_AdjustmentEditor> createState() => _AdjustmentEditorState();
}

class _AdjustmentEditorState extends State<_AdjustmentEditor> {
  late DateTime _date;
  late DateTime _source;
  late AdjustmentType _type;
  late final TextEditingController _label;
  bool _suspend = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final rule = widget.rule;
    _date = rule == null ? widget.initialDate : parseDate(rule.date);
    _source = rule?.sourceDate == null
        ? _date.add(const Duration(days: 1))
        : parseDate(rule!.sourceDate!);
    _type = rule?.type ?? AdjustmentType.rest;
    _label = TextEditingController(text: rule?.label ?? '');
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _pick(bool source) async {
    final picked = await showGlassDatePicker(
      context: context,
      initialDate: source ? _source : _date,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked != null && mounted) {
      setState(() {
        if (source) {
          _source = picked;
        } else {
          _date = picked;
        }
        _error = null;
      });
    }
  }

  void _save() {
    if (_type == AdjustmentType.makeup) {
      if (fmtDate(_date) == fmtDate(_source)) {
        setState(() => _error = '补课日期和原课表日期不能相同');
        return;
      }
      final resolver = ScheduleResolver(widget.state.settings);
      if (resolver.teachingWeek(_source) == null ||
          resolver.teachingWeek(_date) == null) {
        setState(() => _error = '补课日期和原课表日期需位于当前学期 1～$kMaxWeek 周内');
        return;
      }
    }
    Navigator.of(context).pop((
      rule: ScheduleAdjustment(
        date: fmtDate(_date),
        type: _type,
        sourceDate: _type == AdjustmentType.makeup ? fmtDate(_source) : null,
        label: _label.text.trim(),
      ),
      suspend: _suspend && _type == AdjustmentType.makeup,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final previews = _type == AdjustmentType.makeup
        ? ScheduleResolver(
            widget.state.settings.copyWith(holidayAdjustmentEnabled: false),
          ).on(_source, widget.state.courses)
        : <CourseOccurrence>[];
    return GlassDialog(
      title: const Text('设置日期安排'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('实际日期'),
                subtitle: Text(
                  '${fmtDate(_date)} ${weekdayName(_date.weekday)}',
                ),
                trailing: const Icon(Icons.calendar_month_rounded),
                onTap: () => _pick(false),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '当天安排',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              GlassSelect<AdjustmentType>(
                key: const ValueKey('adjustment_type'),
                value: _type,
                title: '当天安排',
                options: const {
                  AdjustmentType.rest: '停课 / 放假',
                  AdjustmentType.makeup: '补指定日期的课',
                  AdjustmentType.normal: '按原课表上课',
                },
                onChanged: (type) {
                  setState(() {
                    _type = type;
                    _error = null;
                  });
                },
              ),
              if (_type == AdjustmentType.makeup) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('原课表日期'),
                  subtitle: Text(
                    '${fmtDate(_source)} ${weekdayName(_source.weekday)}',
                  ),
                  trailing: const Icon(Icons.calendar_month_rounded),
                  onTap: () => _pick(true),
                ),
                Text(
                  previews.isEmpty
                      ? '原日期无课程'
                      : '将安排：${previews.map((o) => '${o.course.name}（${o.course.startPeriod}～${o.course.endPeriod}节）').join('、')}',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    '同时将原日期设为停课',
                    style: TextStyle(fontSize: 13),
                  ),
                  subtitle: const Text(
                    '会新增或覆盖该日期的手动停课安排',
                    style: TextStyle(fontSize: 11),
                  ),
                  value: _suspend,
                  onChanged: (value) =>
                      setState(() => _suspend = value ?? false),
                ),
              ],
              TextField(
                controller: _label,
                decoration: const InputDecoration(labelText: '备注（可选）'),
              ),
              const SizedBox(height: 12),
              const Text(
                '手动安排优先于国家安排。开启智能重排后生效。',
                style: TextStyle(color: Colors.white60, fontSize: 11),
              ),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
          ),
        ),
      ),
      actions: [
        GlassDialogButton(
          onPressed: () => Navigator.of(context).pop(),
          label: '取消',
        ),
        GlassDialogButton(
          key: const ValueKey('save_adjustment'),
          onPressed: _save,
          label: '保存',
          primary: true,
        ),
      ],
    );
  }
}
