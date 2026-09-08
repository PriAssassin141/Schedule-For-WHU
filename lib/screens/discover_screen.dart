import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:class_manager/models/exam.dart';
import 'package:class_manager/screens/exam_edit_screen.dart';
import 'package:class_manager/state/app_state.dart';
import 'package:class_manager/theme/palette.dart';
import 'package:class_manager/utils/links.dart';
import 'package:class_manager/widgets/glass.dart';

/// 发现页：快捷入口 + 考试倒计时（对应图三）。
class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = themeColorOf(state.settings);
    final upcoming = state.exams.where((e) => !e.isOver).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final over = state.exams.where((e) => e.isOver).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final overExams = over;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
        children: [
          Center(
            child: Text('发现',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 14),
          // ---- 校历入口（整行窄条，打开武大本学年校历）----
          LiquidGlass(
            radius: BorderRadius.circular(16),
            tintColor: theme,
            tintAlphaOverride: 0.14,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            onTap: () => _openCampusCalendar(context),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: theme.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(Icons.calendar_month_rounded,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('本学年校历',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ),
                Icon(Icons.open_in_new_rounded,
                    size: 15, color: Colors.white.withValues(alpha: 0.6)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // ---- 考试倒计时 ----
          LiquidGlass(
            radius: BorderRadius.circular(20),
            padding: const EdgeInsets.all(14),
            tintAlphaOverride: 0.22,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('考试倒计时',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) =>
                                ExamEditScreen.exam(null, context.read<AppState>())),
                      ),
                      child: const Icon(Icons.add_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (upcoming.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Center(
                      child: Text('暂无考试安排，点击右上角 + 添加',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 12)),
                    ),
                  )
                else
                  for (final e in upcoming) _ExamCard(exam: e),
                if (overExams.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _CollapsedOverPanel(
                    count: overExams.length,
                    exams: overExams,
                    theme: theme,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 打开武大本学年校历（外链）
  void _openCampusCalendar(BuildContext context) {
    openExternalLink(context, 'https://uc.whu.edu.cn/info/1687/126981.htm');
  }
}

/// 单张考试卡片（点击可修改考试信息）。
class _ExamCard extends StatelessWidget {
  final Exam exam;
  const _ExamCard({required this.exam});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = themeColorOf(state.settings);
    final n = exam.daysFromNow();
    final chipColor = n <= 1 ? theme : Colors.white.withValues(alpha: 0.16);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: LiquidGlass(
        radius: BorderRadius.circular(14),
        tintAlphaOverride: 0.13,
        padding: const EdgeInsets.all(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => ExamEditScreen.exam(exam, context.read<AppState>())),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 34,
              decoration: BoxDecoration(
                color: theme,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(exam.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(
                    '${exam.location}　${exam.date}${exam.timeLabel.isEmpty ? '' : ' ${exam.timeLabel}'}',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                        fontSize: 11),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: chipColor,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(exam.statusLabel,
                  style: TextStyle(
                      color: n <= 1 ? Colors.white : Colors.white.withValues(alpha: 0.85),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}

/// 已结束考试折叠面板。
class _CollapsedOverPanel extends StatefulWidget {
  final int count;
  final List<Exam> exams;
  final Color theme;
  const _CollapsedOverPanel({
    required this.count,
    required this.exams,
    required this.theme,
  });

  @override
  State<_CollapsedOverPanel> createState() => _CollapsedOverPanelState();
}

class _CollapsedOverPanelState extends State<_CollapsedOverPanel> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('已结束考试（${widget.count}）',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
        // 丝滑展开/收起：高度与透明度同步过渡
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 340),
          sizeCurve: Curves.easeOutCubic,
          firstCurve: const Interval(0.35, 1.0, curve: Curves.easeOut),
          secondCurve: const Interval(0.0, 0.65, curve: Curves.easeIn),
          crossFadeState:
              _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Column(
            children: [for (final e in widget.exams) _ExamCard(exam: e)],
          ),
        ),
      ],
    );
  }
}
