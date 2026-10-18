import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:class_manager/models/agenda_event.dart';
import 'package:class_manager/state/app_state.dart';
import 'package:class_manager/theme/palette.dart';
import 'package:class_manager/utils/weeks.dart';
import 'package:class_manager/widgets/app_background.dart';
import 'package:class_manager/widgets/glass.dart';
import 'package:class_manager/widgets/glass_dialog.dart';

Future<void> openAgendaEditor(
  BuildContext context, {
  AgendaEvent? event,
  DateTime? initialDate,
}) async {
  final state = context.read<AppState>();
  final saved = await Navigator.of(context).push<AgendaEvent>(
    MaterialPageRoute(
      builder: (_) => AgendaEditScreen(event: event, initialDate: initialDate),
    ),
  );
  if (saved == null || !context.mounted) return;
  if (state.settings.homeViewMode == HomeViewMode.courses) {
    try {
      await state.setHomeViewMode(HomeViewMode.combined);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('日程已保存，可手动切换到日程模式查看')));
      }
    }
  }
  state.setAgendaDate(saved.startAt);
}

Future<bool> confirmAgendaDeletion(
  BuildContext context,
  AgendaEvent event,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => GlassDialog(
        title: const Text('删除日程'),
        content: Text(
          '确定删除「${event.name}」吗？',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          GlassDialogButton(
            label: '取消',
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          GlassDialogButton(
            label: '删除',
            danger: true,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    ) ??
    false;

class AgendaEditScreen extends StatefulWidget {
  final AgendaEvent? event;
  final DateTime? initialDate;
  const AgendaEditScreen({super.key, this.event, this.initialDate});
  @override
  State<AgendaEditScreen> createState() => _AgendaEditScreenState();
}

class _AgendaEditScreenState extends State<AgendaEditScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _location;
  late final TextEditingController _description;
  late DateTime _start;
  late DateTime _end;
  late AgendaCategory _category;
  String? _customCategory;
  int? _customColor;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    final now = DateTime.now();
    final date = widget.initialDate ?? now;
    _start =
        event?.startAt ??
        DateTime(date.year, date.month, date.day, now.hour, now.minute);
    _end = event?.endAt ?? _start.add(const Duration(hours: 1));
    _category = event?.category ?? AgendaCategory.work;
    _customCategory = event?.customCategory;
    _customColor = event?.customColorValue;
    _name = TextEditingController(text: event?.name ?? '');
    _location = TextEditingController(text: event?.location ?? '');
    _description = TextEditingController(text: event?.description ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    _description.dispose();
    super.dispose();
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    if (!_end.isAfter(_start)) {
      _message('结束时间必须晚于开始时间；跨夜日程请调整结束日期');
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await context.read<AppState>().saveAgendaEvent(
        AgendaEvent(
          id: widget.event?.id,
          name: _name.text,
          startAt: _start,
          endAt: _end,
          category: _category,
          customCategory: _customCategory,
          customColorValue: _customColor,
          location: _location.text.trim(),
          description: _description.text.trim(),
        ),
      );
      if (mounted) Navigator.of(context).pop(saved);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        _message('保存失败，请重试');
      }
    }
  }

  Future<void> _delete() async {
    if (_saving || widget.event == null) return;
    if (!await confirmAgendaDeletion(context, widget.event!) || !mounted) {
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<AppState>().deleteAgendaEvent(widget.event!);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        _message('删除失败，请重试');
      }
    }
  }

  Future<void> _pick(bool start, bool date) async {
    final current = start ? _start : _end;
    DateTime? next;
    if (date) {
      final picked = await showGlassDatePicker(
        context: context,
        initialDate: calendarDate(current),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100, 12, 31),
      );
      if (picked != null) {
        next = DateTime(
          picked.year,
          picked.month,
          picked.day,
          current.hour,
          current.minute,
        );
      }
    } else {
      final picked = await showGlassTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(current),
      );
      if (picked != null) {
        next = DateTime(
          current.year,
          current.month,
          current.day,
          picked.hour,
          picked.minute,
        );
      }
    }
    if (next != null && mounted) {
      setState(() {
        if (start) {
          _start = next!;
        } else {
          _end = next!;
        }
      });
    }
  }

  Widget _field(
    String label,
    TextEditingController controller,
    String key, {
    int lines = 1,
    bool required = false,
  }) => LiquidGlass(
    tintAlphaOverride: 0.22,
    child: TextFormField(
      key: ValueKey(key),
      controller: controller,
      maxLines: lines,
      maxLength: required
          ? 80
          : lines == 1
          ? 200
          : 2000,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        border: InputBorder.none,
        labelStyle: const TextStyle(color: Colors.white70),
      ),
      validator: required
          ? (value) => value == null || value.trim().isEmpty ? '请填写日程名称' : null
          : null,
    ),
  );

  Widget _timeRow(bool start) {
    final value = start ? _start : _end;
    final key = start ? 'start' : 'end';
    Widget valueButton({required bool date}) => Expanded(
      child: TextButton(
        key: ValueKey('agenda_${key}_${date ? 'date' : 'time'}'),
        onPressed: () => _pick(start, date),
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          alignment: Alignment.center,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                date ? Icons.calendar_today_outlined : Icons.schedule_rounded,
                size: 20,
                color: Colors.white70,
              ),
              const SizedBox(width: 8),
              Text(
                date ? fmtDate(value) : agendaTime(value),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return LiquidGlass(
      tintAlphaOverride: 0.22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            start ? '开始时间' : '结束时间',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(children: [valueButton(date: true), valueButton(date: false)]),
        ],
      ),
    );
  }

  Future<void> _addCategory() async {
    var name = '';
    final form = GlobalKey<FormState>();
    final label = await showDialog<String>(
      context: context,
      builder: (ctx) => GlassDialog(
        title: const Text('自定义日程类型'),
        content: Form(
          key: form,
          child: TextFormField(
            key: const ValueKey('agenda_custom_category_name'),
            autofocus: true,
            maxLength: 20,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: '类型名称',
              hintText: '例如：社团、志愿服务',
            ),
            onChanged: (value) => name = value.trim(),
            validator: (_) => name.isEmpty ? '请填写类型名称' : null,
          ),
        ),
        actions: [
          GlassDialogButton(
            label: '取消',
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          GlassDialogButton(
            label: '保存类型',
            primary: true,
            onPressed: () {
              if (form.currentState!.validate()) Navigator.of(ctx).pop(name);
            },
          ),
        ],
      ),
    );
    if (label == null || !mounted) return;
    try {
      await context.read<AppState>().saveAgendaCategory(label);
      if (!mounted) return;
      setState(() {
        final preset = AgendaCategory.values
            .where((c) => c.label == label)
            .firstOrNull;
        _category = preset ?? AgendaCategory.other;
        _customCategory = preset == null ? label : null;
      });
    } catch (_) {
      if (mounted) _message('类型保存失败，请重试');
    }
  }

  Future<void> _customHexColor() async {
    var value = '';
    final form = GlobalKey<FormState>();
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => GlassDialog(
        title: const Text('自定义卡片颜色'),
        content: Form(
          key: form,
          child: TextFormField(
            key: const ValueKey('agenda_hex_color'),
            initialValue: (_customColor ?? _category.colorValue)
                .toRadixString(16)
                .substring(2)
                .toUpperCase(),
            maxLength: 7,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: '颜色值',
              hintText: '#68BFA8',
            ),
            onSaved: (text) => value = text!.trim().replaceFirst('#', ''),
            validator: (text) =>
                RegExp(r'^#?[0-9a-fA-F]{6}$').hasMatch(text?.trim() ?? '')
                ? null
                : '请输入6位十六进制颜色，例如 #68BFA8',
          ),
        ),
        actions: [
          GlassDialogButton(
            label: '取消',
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          GlassDialogButton(
            label: '应用颜色',
            primary: true,
            onPressed: () {
              if (!form.currentState!.validate()) return;
              form.currentState!.save();
              Navigator.of(ctx).pop(0xFF000000 | int.parse(value, radix: 16));
            },
          ),
        ],
      ),
    );
    if (result != null && mounted) setState(() => _customColor = result);
  }

  Widget _colorPicker() {
    final selected = _customColor ?? _category.colorValue;
    final colors = {
      ...AgendaCategory.values.map((c) => c.colorValue),
      ...kCourseColors,
      ?_customColor,
    };
    return LiquidGlass(
      tintAlphaOverride: 0.22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '日程卡片颜色',
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _customColor = null),
                child: const Text('跟随类型'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final color in colors)
                Semantics(
                  button: true,
                  selected: selected == color,
                  label: '颜色 ${color.toRadixString(16).substring(2)}',
                  child: GestureDetector(
                    key: ValueKey('agenda_color_$color'),
                    onTap: () => setState(() => _customColor = color),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Color(color),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected == color
                              ? Colors.white
                              : Colors.white24,
                          width: selected == color ? 2.5 : 1,
                        ),
                      ),
                      child: selected == color
                          ? const Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                ),
            ],
          ),
          TextButton.icon(
            key: const ValueKey('agenda_custom_color'),
            onPressed: _customHexColor,
            icon: const Icon(Icons.palette_outlined, size: 17),
            label: const Text('自定义颜色值'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = themeColorOf(context.watch<AppState>().settings);
    return BackgroundedScaffold(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Row(
                children: [
                  GlassIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    size: 34,
                    onTap: _saving ? null : () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.event == null ? '添加日程' : '编辑日程',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  GlassDialogButton(
                    key: const ValueKey('save_agenda'),
                    label: _saving ? '保存中…' : '保存',
                    primary: true,
                    onPressed: _save,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                  children: [
                    _field('日程名称 *', _name, 'agenda_name', required: true),
                    const SizedBox(height: 12),
                    _timeRow(true),
                    const SizedBox(height: 10),
                    _timeRow(false),
                    const SizedBox(height: 12),
                    LiquidGlass(
                      tintAlphaOverride: 0.22,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '日程类型',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: GlassSelect<String>(
                              key: const ValueKey('agenda_category'),
                              value: _customCategory == null
                                  ? _category.name
                                  : 'custom:$_customCategory',
                              title: '日程类型',
                              centerSelectedLabel: true,
                              extraOptionLabel: '增加自定义类型',
                              extraOptionKey: const ValueKey(
                                'agenda_add_category',
                              ),
                              onExtraOption: _addCategory,
                              options: {
                                for (final category in AgendaCategory.values)
                                  category.name: category.label,
                                for (final label in {
                                  ...context
                                      .watch<AppState>()
                                      .settings
                                      .agendaCustomCategories,
                                  ?_customCategory,
                                })
                                  'custom:$label': label,
                              },
                              onChanged: (value) => setState(() {
                                _customCategory = value.startsWith('custom:')
                                    ? value.substring(7)
                                    : null;
                                _category = AgendaCategory.fromStored(value);
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _colorPicker(),
                    const SizedBox(height: 12),
                    _field('活动地点', _location, 'agenda_location'),
                    const SizedBox(height: 12),
                    _field(
                      '日程描述',
                      _description,
                      'agenda_description',
                      lines: 4,
                    ),
                    if (widget.event != null) ...[
                      const SizedBox(height: 20),
                      LiquidGlass(
                        tintColor: theme,
                        tintAlphaOverride: 0.12,
                        onTap: _saving ? null : _delete,
                        child: const Center(
                          child: Text(
                            '删除日程',
                            style: TextStyle(
                              color: Color(0xFFFF9A9A),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
