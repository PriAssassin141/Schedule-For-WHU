import 'package:flutter/material.dart';

import 'package:class_manager/models/course.dart';
import 'package:class_manager/models/periods.dart';
import 'package:class_manager/state/app_state.dart';
import 'package:class_manager/theme/palette.dart';
import 'package:class_manager/utils/weeks.dart';
import 'package:class_manager/widgets/app_background.dart';
import 'package:class_manager/widgets/glass.dart';

/// 课程编辑页：新增/编辑课程（含周数多选、节次范围、颜色自定义）。
class CourseEditScreen extends StatefulWidget {
  /// [course] 为 null 表示新增课程。
  final Course? course;
  final AppState state;

  CourseEditScreen.course(this.course, this.state) : super(key: ValueKey(course?.id ?? 'new'));

  @override
  State<CourseEditScreen> createState() => _CourseEditScreenState();
}

class _CourseEditScreenState extends State<CourseEditScreen> {
  late final TextEditingController _nameCtl;
  late final TextEditingController _teacherCtl;
  late final TextEditingController _locationCtl;
  late final TextEditingController _noteCtl;

  late int _day;
  late int _startPeriod;
  late int _endPeriod;
  late Set<int> _weeks;
  late int _colorValue;

  bool get _isNew => widget.course == null;

  @override
  void initState() {
    super.initState();
    final c = widget.course;
    _nameCtl = TextEditingController(text: c?.name ?? '');
    _teacherCtl = TextEditingController(text: c?.teacher ?? '');
    _locationCtl = TextEditingController(text: c?.location ?? '');
    _noteCtl = TextEditingController(text: c?.note ?? '');
    _day = c?.day ?? 1;
    _startPeriod = c?.startPeriod ?? 1;
    _endPeriod = c?.endPeriod ?? 2;
    _weeks = {...Weeks.parse(c?.weeks ?? '')}.toSet();
    _colorValue = c?.colorValue ?? widget.state.pickCourseColor();
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _teacherCtl.dispose();
    _locationCtl.dispose();
    _noteCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtl.text.trim();
    if (name.isEmpty) {
      _toast('请填写课程名称');
      return;
    }
    var start = _startPeriod;
    var end = _endPeriod;
    if (start > end) {
      final t = start;
      start = end;
      end = t;
    }
    final weeks = Weeks.compress(_weeks.toList());
    if (_isNew) {
      await widget.state.addCourse(Course(
        name: name,
        teacher: _teacherCtl.text.trim(),
        location: _locationCtl.text.trim(),
        note: _noteCtl.text.trim(),
        day: _day,
        startPeriod: start,
        endPeriod: end,
        weeks: weeks,
        colorValue: _colorValue,
      ));
    } else {
      await widget.state.updateCourse(widget.course!.copyWith(
        name: name,
        teacher: _teacherCtl.text.trim(),
        location: _locationCtl.text.trim(),
        note: _noteCtl.text.trim(),
        day: _day,
        startPeriod: start,
        endPeriod: end,
        weeks: weeks,
        colorValue: _colorValue,
      ));
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final c = widget.course;
    if (c == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF14302E),
        title: const Text('删除课程', style: TextStyle(color: Colors.white)),
        content: Text('确定删除「${c.name}」吗？',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消', style: TextStyle(color: Colors.white70))),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('删除',
                  style: TextStyle(color: Color(0xFFFF6B6B)))),
        ],
      ),
    );
    if (ok == true) {
      await widget.state.deleteCourse(c);
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 1)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = themeColorOf(widget.state.settings);
    return BackgroundedScaffold(
      child: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                GlassIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  size: 34,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 12),
                Text(_isNew ? '添加课程' : '编辑课程',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
                const Spacer(),
                LiquidGlass(
                  radius: BorderRadius.circular(18),
                  padding: EdgeInsets.zero,
                  tintColor: theme,
                  tintAlphaOverride: 0.75,
                  onTap: _save,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    child: Text('保存',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 60),
                children: [
                  _field('课程名称 *', _nameCtl, hint: '如：数理统计(05)'),
                  const SizedBox(height: 10),
                  _field('任课老师', _teacherCtl, hint: '如：邓爱姣'),
                  const SizedBox(height: 10),
                  _field('上课地点', _locationCtl, hint: '如：网安基地, 新珈楼B201'),
                  const SizedBox(height: 10),
                  _field('备注', _noteCtl, hint: '选填', maxLines: 2),
                  const SizedBox(height: 16),
                  // ---- 星期 ----
                  _Card(title: '星期', child: _dayPicker(theme)),
                  const SizedBox(height: 10),
                  // ---- 节次 ----
                  _Card(title: '节次', child: _periodPicker(theme)),
                  const SizedBox(height: 10),
                  // ---- 周数 ----
                  _Card(title: '上课周数', child: _weekPicker(theme)),
                  const SizedBox(height: 10),
                  // ---- 颜色 ----
                  _Card(title: '课程卡片颜色', child: _colorPicker(theme)),
                  if (!_isNew) ...[
                    const SizedBox(height: 16),
                    LiquidGlass(
                      radius: BorderRadius.circular(14),
                      padding: EdgeInsets.zero,
                      tintColor: const Color(0xFFFF6B6B),
                      tintAlphaOverride: 0.28,
                      onTap: _delete,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: Text('删除课程',
                              style: TextStyle(
                                  color: Color(0xFFFF9A9A),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctl,
      {String? hint, int maxLines = 1}) {
    return LiquidGlass(
      radius: BorderRadius.circular(14),
      tintAlphaOverride: 0.14,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: TextField(
        controller: ctl,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white, fontSize: 14.5),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 13),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 12),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  // 星期选择
  Widget _dayPicker(Color theme) {
    return Row(
      children: [
        for (var d = 1; d <= 7; d++) ...[
          if (d > 1) const SizedBox(width: 5),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _day = d),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _day == d ? theme : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(weekdayName(d).substring(1),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: _day == d ? FontWeight.w800 : FontWeight.w600,
                      color: _day == d ? Colors.white : Colors.white70,
                    )),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // 节次选择（开始~结束）
  Widget _periodPicker(Color theme) {
    final startP = periodOf(_startPeriod);
    final endP = periodOf(_endPeriod);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _startPeriod,
                  dropdownColor: const Color(0xFF16322F),
                  borderRadius: BorderRadius.circular(12),
                  iconEnabledColor: Colors.white70,
                  style: const TextStyle(color: Colors.white, fontSize: 13.5),
                  items: [
                    for (var i = 1; i <= kPeriodCount; i++)
                      DropdownMenuItem(
                          value: i,
                          child: Text('第${numberToChinese(i)}节  ${periodOf(i).start}')),
                  ],
                  onChanged: (v) => setState(() {
                    _startPeriod = v ?? 1;
                    if (_startPeriod > _endPeriod) _endPeriod = _startPeriod + 1 > kPeriodCount ? _startPeriod : _startPeriod + 1;
                  }),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 1, height: 26,
              color: Colors.white.withValues(alpha: 0.15),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _endPeriod,
                  dropdownColor: const Color(0xFF16322F),
                  borderRadius: BorderRadius.circular(12),
                  iconEnabledColor: Colors.white70,
                  style: const TextStyle(color: Colors.white, fontSize: 13.5),
                  items: [
                    for (var i = 1; i <= kPeriodCount; i++)
                      DropdownMenuItem(
                          value: i,
                          child: Text('第${numberToChinese(i)}节  ${periodOf(i).start}')),
                  ],
                  onChanged: (v) => setState(() => _endPeriod = v ?? 1),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('第${numberToChinese(_startPeriod)}节 ${startP.range} ~ 第${numberToChinese(_endPeriod)}节 ${endP.range}',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 11.5)),
      ],
    );
  }

  // 周数多选
  Widget _weekPicker(Color theme) {
    final all = _weeks.length == kMaxWeek;
    // 单周 / 双周选中判断（22 周时两者数量相同，需按奇偶区分）
    final oddWeeks = {for (var w = 1; w <= kMaxWeek; w += 2) w};
    final evenWeeks = {for (var w = 2; w <= kMaxWeek; w += 2) w};
    final isOdd = _weeks.isNotEmpty &&
        _weeks.length == oddWeeks.length &&
        _weeks.every(oddWeeks.contains);
    final isEven = _weeks.isNotEmpty &&
        _weeks.length == evenWeeks.length &&
        _weeks.every(evenWeeks.contains);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _quickChip('全部', all, () => setState(() => _weeks = {...List.generate(kMaxWeek, (i) => i + 1)}), theme),
            const SizedBox(width: 6),
            _quickChip('单周', isOdd, () => setState(() => _weeks = {...oddWeeks}), theme),
            const SizedBox(width: 6),
            _quickChip('双周', isEven, () => setState(() => _weeks = {...evenWeeks}), theme),
            const SizedBox(width: 6),
            _quickChip('1-16周', _weeks.length == 16 && _weeks.contains(1) && _weeks.contains(16), () => setState(() => _weeks = {for (var w = 1; w <= 16; w++) w}), theme),
            const SizedBox(width: 6),
            _quickChip('清空', _weeks.isEmpty, () => setState(() => _weeks = {}), theme),
          ],
        ),
        const SizedBox(height: 10),
        Text('可选择任意周数组合，如 1、3、6 周上课',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (var w = 1; w <= kMaxWeek; w++)
              GestureDetector(
                onTap: () => setState(() {
                  if (_weeks.contains(w)) {
                    _weeks.remove(w);
                  } else {
                    _weeks.add(w);
                  }
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 44,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _weeks.contains(w)
                        ? theme
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Center(
                    child: Text('$w',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: _weeks.contains(w) ? FontWeight.w800 : FontWeight.w600,
                          color: _weeks.contains(w) ? Colors.white : Colors.white70,
                        )),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _quickChip(String label, bool selected, VoidCallback onTap, Color theme) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? theme.withValues(alpha: 0.55) : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: Colors.white.withValues(alpha: selected ? 1 : 0.7),
            )),
      ),
    );
  }

  // 颜色选择
  Widget _colorPicker(Color theme) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final color in kCourseColors)
          GestureDetector(
            onTap: () => setState(() => _colorValue = color),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Color(color),
                shape: BoxShape.circle,
                border: _colorValue == color
                    ? Border.all(color: Colors.white, width: 2.5)
                    : Border.all(color: Colors.white.withValues(alpha: 0.25)),
              ),
              child: _colorValue == color
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 19)
                  : null,
            ),
          ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  const _Card({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      radius: BorderRadius.circular(16),
      tintAlphaOverride: 0.14,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
