import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:class_manager/models/course.dart';
import 'package:class_manager/models/periods.dart';
import 'package:class_manager/services/schedule_importer.dart';
import 'package:class_manager/services/schedule_parser.dart';
import 'package:class_manager/state/app_state.dart';
import 'package:class_manager/theme/palette.dart';
import 'package:class_manager/utils/weeks.dart';
import 'package:class_manager/widgets/app_background.dart';
import 'package:class_manager/widgets/glass.dart';

/// 系统课表文件选择 + 解析 + 预览导入入口。
Future<void> runScheduleImport(BuildContext context) async {
  final f = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: ['doc', 'docx', 'xls', 'xlsx'],
  );
  if (f == null) return;
  Uint8List? bytes;
  try {
    bytes = await f.readAsBytes();
  } catch (_) {
    if (f.path != null) {
      try {
        bytes = await File(f.path!).readAsBytes();
      } catch (_) {}
    }
  }
  if (bytes == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法读取文件'), duration: Duration(seconds: 2)));
    }
    return;
  }
  final import = await importScheduleFile(f.name, bytes);
  if (!context.mounted) return;
  if (import.courses.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('未解析出课程：${import.note.isEmpty ? '文件格式未识别' : import.note}'),
        duration: const Duration(seconds: 3)));
    return;
  }
  await Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => ImportPreviewScreen(
      courses: import.courses,
      sourceName: f.name,
      note: import.note,
    ),
  ));
}

/// 导入预览：解析结果可逐条修改、追加或覆盖导入。
class ImportPreviewScreen extends StatefulWidget {
  final List<ParsedCourse> courses;
  final String sourceName;
  final String note;

  const ImportPreviewScreen({
    super.key,
    required this.courses,
    required this.sourceName,
    required this.note,
  });

  @override
  State<ImportPreviewScreen> createState() => _ImportPreviewScreenState();
}

class _ImportPreviewScreenState extends State<ImportPreviewScreen> {
  late final List<ParsedCourse> _items;

  @override
  void initState() {
    super.initState();
    _items = [...widget.courses];
  }

  Future<void> _doImport({required bool replace}) async {
    final state = context.read<AppState>();
    await state.importCourses(_items, replace: replace);
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(replace
              ? '已清空旧课表并导入 ${_items.length} 门课程'
              : '已追加导入 ${_items.length} 门课程'),
          duration: const Duration(seconds: 2)));
    }
  }

  Future<void> _editItem(int index) async {
    final pc = _items[index];
    final course = Course(
      name: pc.name,
      teacher: pc.teacher,
      location: pc.location,
      note: pc.note,
      day: pc.day,
      startPeriod: pc.startPeriod,
      endPeriod: pc.endPeriod,
      weeks: pc.weeks,
      colorValue: context.read<AppState>().pickCourseColor(),
    );
    final edited = await Navigator.of(context).push<ParsedCourse>(
      MaterialPageRoute(
        builder: (_) => _ParsedEditScreen(course: course),
      ),
    );
    if (edited != null) {
      setState(() => _items[index] = edited);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = themeColorOf(state.settings);
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
                const Text('导入课表',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 8),
            // 文件信息
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LiquidGlass(
                radius: BorderRadius.circular(12),
                tintColor: theme,
                tintAlphaOverride: 0.12,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                child: Row(
                  children: [
                    Icon(Icons.description_outlined, size: 17, color: theme),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${widget.sourceName} · 解析出 ${_items.length} 门课程\n${widget.note}',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 11.5,
                            height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            // 操作按钮
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: LiquidGlass(
                      radius: BorderRadius.circular(14),
                      padding: EdgeInsets.zero,
                      tintAlphaOverride: 0.18,
                      onTap: () => _doImport(replace: false),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 11),
                        child: Center(
                          child: Text('追加导入',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LiquidGlass(
                      radius: BorderRadius.circular(14),
                      padding: EdgeInsets.zero,
                      tintColor: theme,
                      tintAlphaOverride: 0.65,
                      onTap: () => _doImport(replace: true),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 11),
                        child: Center(
                          child: Text('清空并导入',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 60),
                itemCount: _items.length,
                itemBuilder: (_, i) {
                  final pc = _items[i];
                  final color = Color(kCourseColors[i % kCourseColors.length]);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: LiquidGlass(
                      radius: BorderRadius.circular(14),
                      tintAlphaOverride: 0.12,
                      padding: const EdgeInsets.all(12),
                      onTap: () => _editItem(i),
                      child: Row(
                        children: [
                          Container(
                            width: 5,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(pc.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w800)),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.4),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${weekdayName(pc.day)} ${pc.periodsLabel}',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${Weeks.describe(pc.weeks)} · ${pc.teacher.isEmpty ? '未填老师' : pc.teacher}'
                                  '${pc.location.isEmpty ? '' : ' · ${pc.location}'}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.6),
                                      fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.edit_rounded,
                              size: 16,
                              color: Colors.white.withValues(alpha: 0.5)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 单条解析结果的快速编辑（导入前修正错误信息）。
class _ParsedEditScreen extends StatefulWidget {
  final Course course;
  const _ParsedEditScreen({required this.course});

  @override
  State<_ParsedEditScreen> createState() => _ParsedEditScreenState();
}

class _ParsedEditScreenState extends State<_ParsedEditScreen> {
  late final TextEditingController _nameCtl;
  late final TextEditingController _teacherCtl;
  late final TextEditingController _locationCtl;
  late Course c;

  @override
  void initState() {
    super.initState();
    c = widget.course;
    _nameCtl = TextEditingController(text: c.name);
    _teacherCtl = TextEditingController(text: c.teacher);
    _locationCtl = TextEditingController(text: c.location);
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _teacherCtl.dispose();
    _locationCtl.dispose();
    super.dispose();
  }

  ParsedCourse _build() {
    final weeks = Weeks.compress([...Weeks.parse(c.weeks)]);
    return ParsedCourse(
      name: _nameCtl.text.trim(),
      teacher: _teacherCtl.text.trim(),
      location: _locationCtl.text.trim(),
      note: c.note,
      day: c.day,
      startPeriod: c.startPeriod,
      endPeriod: c.endPeriod,
      weeks: weeks,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = themeColorOf(context.watch<AppState>().settings);
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
                const Text('修正课程信息',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
                const Spacer(),
                LiquidGlass(
                  radius: BorderRadius.circular(18),
                  padding: EdgeInsets.zero,
                  tintColor: theme,
                  tintAlphaOverride: 0.75,
                  onTap: () => Navigator.of(context).pop(_build()),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    child: Text('完成',
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
                  _field('课程名称 *', _nameCtl),
                  const SizedBox(height: 10),
                  _field('任课老师', _teacherCtl),
                  const SizedBox(height: 10),
                  _field('上课地点', _locationCtl),
                  const SizedBox(height: 16),
                  LiquidGlass(
                    radius: BorderRadius.circular(14),
                    tintAlphaOverride: 0.14,
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => setState(() =>
                                c = c.copyWith(day: c.day % 7 + 1)),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                children: [
                                  Text('星期',
                                      style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.6),
                                          fontSize: 10.5)),
                                  const SizedBox(height: 3),
                                  Text(weekdayName(c.day), // 点击切换
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => setState(() {
                              var s = c.startPeriod + 1;
                              var e = c.endPeriod + 1;
                              if (e > kPeriodCount) {
                                s = 1;
                                e = 2;
                              }
                              c = c.copyWith(startPeriod: s, endPeriod: e);
                            }),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                children: [
                                  Text('节次',
                                      style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.6),
                                          fontSize: 10.5)),
                                  const SizedBox(height: 3),
                                  Text('${c.startPeriod}-${c.endPeriod}节',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('提示：点击上方星期/节次可快速调整，完整编辑请使用「添加课程」。',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 10.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctl) {
    return LiquidGlass(
      radius: BorderRadius.circular(14),
      tintAlphaOverride: 0.14,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: TextField(
        controller: ctl,
        style: const TextStyle(color: Colors.white, fontSize: 14.5),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          labelText: label,
          labelStyle:
              TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}
