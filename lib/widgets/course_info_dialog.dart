import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:class_manager/models/periods.dart';
import 'package:class_manager/screens/course_edit_screen.dart';
import 'package:class_manager/services/schedule_resolver.dart';
import 'package:class_manager/state/app_state.dart';
import 'package:class_manager/utils/weeks.dart';
import 'package:class_manager/widgets/glass_dialog.dart';

/// 先查看本次授课信息，明确选择编辑后再进入原课程的编辑页。
Future<void> showCourseInfoDialog(
  BuildContext context,
  CourseOccurrence occurrence,
) async {
  final state = context.read<AppState>();
  final edit = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => CourseInfoDialog(occurrence: occurrence),
  );
  if (edit == true && context.mounted) {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CourseEditScreen.course(occurrence.course, state),
      ),
    );
  }
}

class CourseInfoDialog extends StatelessWidget {
  final CourseOccurrence occurrence;
  const CourseInfoDialog({super.key, required this.occurrence});

  Future<void> _delete(BuildContext context) async {
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final course = occurrence.course;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => GlassDialog(
        title: const Text('删除课程'),
        content: Text('确定删除「${course.name}」吗？该课程的所有周次安排都会删除。'),
        actions: [
          GlassDialogButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            label: '取消',
          ),
          GlassDialogButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            label: '删除',
            danger: true,
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await state.deleteCourse(course);
      if (context.mounted) {
        Navigator.of(context).pop(false);
        messenger.showSnackBar(const SnackBar(content: Text('已删除课程')));
      }
    } catch (_) {
      if (context.mounted) {
        messenger.showSnackBar(const SnackBar(content: Text('删除失败，请重试')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final course = occurrence.course;
    final color = Color(course.colorValue);
    final makeup = fmtDate(occurrence.date) != fmtDate(occurrence.sourceDate);
    return GlassDialog(
      key: const ValueKey('course_info_dialog'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 4,
                        height: 24,
                        margin: const EdgeInsets.only(top: 7, right: 12),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          course.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            height: 1.5,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('course_info_delete'),
                        tooltip: '删除课程',
                        onPressed: () => _delete(context),
                        color: Colors.white,
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _InfoRow(label: '地点', value: course.location),
                  _InfoRow(label: '老师', value: course.teacher),
                  _InfoRow(label: '周次', value: Weeks.describe(course.weeks)),
                  _InfoRow(
                    label: '时间',
                    value:
                        '第${course.startPeriod}～${course.endPeriod}节 · '
                        '${periodOf(course.startPeriod).start}～${periodOf(course.endPeriod).end}',
                  ),
                  _InfoRow(
                    label: makeup ? '补课日' : '日期',
                    value:
                        '${fmtDate(occurrence.date)} '
                        '${weekdayName(occurrence.date.weekday)}',
                  ),
                  if (makeup)
                    _InfoRow(
                      label: '原课表',
                      value:
                          '${fmtDate(occurrence.sourceDate)} '
                          '${weekdayName(occurrence.sourceDate.weekday)}',
                    ),
                  if (course.note.trim().isNotEmpty)
                    _InfoRow(label: '备注', value: course.note),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GlassDialogButton(
                onPressed: () => Navigator.of(context).pop(false),
                label: '关闭',
              ),
              const SizedBox(width: 12),
              GlassDialogButton(
                key: const ValueKey('course_info_edit'),
                onPressed: () => Navigator.of(context).pop(true),
                primary: true,
                color: color,
                icon: Icons.edit_outlined,
                label: '编辑',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value.trim().isEmpty ? '未填写' : value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ),
      ],
    ),
  );
}
