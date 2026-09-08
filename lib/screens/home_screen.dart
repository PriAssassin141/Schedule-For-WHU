import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:class_manager/models/course.dart';
import 'package:class_manager/models/periods.dart';
import 'package:class_manager/screens/course_edit_screen.dart';
import 'package:class_manager/screens/import_preview_screen.dart';
import 'package:class_manager/state/app_state.dart';
import 'package:class_manager/theme/palette.dart';
import 'package:class_manager/utils/weeks.dart';
import 'package:class_manager/widgets/glass.dart';

/// 主页：第 N 周 + 周一~周日 7 天全周课表（同页显示，参考图）。
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = themeColorOf(state.settings);

    return SafeArea(
      child: Column(
        children: [
          // ---- 顶部：第 N 周 + 图标按钮 ----
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Row(
              children: [
                _WeekTitle(theme: theme),
                const Spacer(),
                GlassIconButton(
                  icon: Icons.add_rounded,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) =>
                            CourseEditScreen.course(null, context.read<AppState>())),
                  ),
                ),
                const SizedBox(width: 8),
                GlassIconButton(
                  icon: Icons.ios_share_rounded,
                  onTap: () => _showShareSheet(context),
                ),
                const SizedBox(width: 8),
                GlassIconButton(
                  icon: Icons.menu_rounded,
                  onTap: () => _showMenuSheet(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // ---- 全周 7 天课表（SafeArea 已预留导航高度，这里只留参考图的紧凑间距）----
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 26),
              child: Stack(
                children: [
                  Positioned.fill(child: const _WeekPager()),
                  // 回到本周悬浮钮（非本周时显示）
                  if (state.browseWeek != state.currentWeek)
                    Align(
                      alignment: const Alignment(0.92, -0.05),
                      child: _BackToThisWeek(theme: theme),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- 周标题 ----------------

class _WeekTitle extends StatelessWidget {
  final Color theme;
  const _WeekTitle({required this.theme});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final week = state.browseWeek;
    return Row(
      children: [
        GestureDetector(
          onTap: () => _showWeekPicker(context),
          child: Row(
            children: [
              Text('第', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
              Text('$week', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: theme)),
              Text('周', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Icon(Icons.swap_vert_rounded,
            size: 16, color: Colors.white.withValues(alpha: 0.45)),
        const SizedBox(width: 2),
        Text('上下拖动切换周',
            style: TextStyle(
                fontSize: 10.5, color: Colors.white.withValues(alpha: 0.45))),
      ],
    );
  }
}

void _showWeekPicker(BuildContext context) {
  final state = context.read<AppState>();
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => LiquidGlass(
      radius: BorderRadius.circular(24),
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 16),
      tintAlphaOverride: 0.34,
      child: SizedBox(
        height: 380,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('选择周次', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5, mainAxisSpacing: 8, crossAxisSpacing: 8),
                itemCount: kMaxWeek,
                itemBuilder: (_, i) {
                  final w = i + 1;
                  final sel = w == state.browseWeek;
                  final d1 = state.dateOf(w, 1);
                  return GestureDetector(
                    onTap: () {
                      state.setBrowseWeek(w);
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: sel ? themeColorOf(state.settings) : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('$w', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                          Text('${d1.month}/${d1.day}', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 9)),
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
    ),
  );
}

// ---------------- 全周课表 ----------------

const double _gutterW = 44;
const double _headerH = 46;

// ---------------- 上下拖动翻页 ----------------

/// 上下拖动翻页切换周次：拖动时页面跟手滑动，松手后翻页或回弹。
class _WeekPager extends StatefulWidget {
  const _WeekPager();

  @override
  State<_WeekPager> createState() => _WeekPagerState();
}

class _WeekPagerState extends State<_WeekPager>
    with SingleTickerProviderStateMixin {
  /// 拖拽进度：>0 向「下一周」翻，<0 向「上一周」翻，范围 -1..1。
  double _progress = 0;
  late final AnimationController _settle;
  double _from = 0;
  double _to = 0;
  bool _commitOnEnd = false;

  @override
  void initState() {
    super.initState();
    _settle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )
      ..addListener(() {
        // 松手后的滑动用 easeOutCubic，收尾丝滑
        setState(() => _progress = _from +
            (_to - _from) * Curves.easeOutCubic.transform(_settle.value));
      })
      ..addStatusListener((status) {
        if (status != AnimationStatus.completed) return;
        if (!_commitOnEnd) return;
        _commitOnEnd = false;
        if (!mounted) return;
        final state = context.read<AppState>();
        final delta = _progress > 0 ? 1 : -1;
        state.setBrowseWeek(state.browseWeek + delta);
        setState(() => _progress = 0);
      });
  }

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  void _animateTo(double target, {bool commit = false}) {
    _from = _progress;
    _to = target;
    _commitOnEnd = commit;
    _settle.forward(from: 0);
  }

  void _onDragUpdate(DragUpdateDetails d, double height) {
    if (_settle.isAnimating) return;
    final week = context.read<AppState>().browseWeek;
    var next = _progress - (d.primaryDelta ?? 0) / (height * 0.75);
    // 首周不能再往上翻、末周不能再往下翻
    if (week <= 1 && next < 0) next = 0;
    if (week >= kMaxWeek && next > 0) next = 0;
    setState(() => _progress = next.clamp(-1.0, 1.0));
  }

  void _onDragEnd(DragEndDetails d, double height) {
    final week = context.read<AppState>().browseWeek;
    final fling = -(d.primaryVelocity ?? 0) / 900; // 向上拖动 → 正
    final target = _progress + fling;
    if (target > 0.22 && week < kMaxWeek) {
      _animateTo(1, commit: true);
    } else if (target < -0.22 && week > 1) {
      _animateTo(-1, commit: true);
    } else {
      _animateTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final week = state.browseWeek;
    final dir = _progress >= 0 ? 1 : -1;
    final neighbor = (week + dir).clamp(1, kMaxWeek);
    final p = _progress.abs();

    return LayoutBuilder(builder: (context, cons) {
      final h = cons.maxHeight;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (d) => _onDragUpdate(d, h),
        onVerticalDragEnd: (d) => _onDragEnd(d, h),
        child: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 当前页：整页滑出视口（无淡出，纯丝滑滑动）
              FractionalTranslation(
                translation: Offset(0, -dir * p),
                child: FullWeekSchedule(week: week),
              ),
              // 相邻页：从另一侧整页滑入
              if (p > 0.0001)
                FractionalTranslation(
                  translation: Offset(0, dir * (1 - p)),
                  child: FullWeekSchedule(week: neighbor),
                ),
            ],
          ),
        ),
      );
    });
  }
}

/// 周一~周日同时显示的 7 列全周课表（13 节 × 7 天）。
class FullWeekSchedule extends StatelessWidget {
  /// 要展示的周次（由 _WeekPager 传入，翻页时可同时渲染新旧两页）。
  final int week;
  const FullWeekSchedule({super.key, required this.week});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final settings = state.settings;
    final theme = themeColorOf(settings);

    final all = state.courses
        .where((c) => state.courseActiveInWeek(c, week))
        .toList()
      ..sort((a, b) => a.startPeriod.compareTo(b.startPeriod));

    // 同日重叠课程分栏（区间着色）
    final lanes = <int, List<int>>{};
    final laneOf = <int, int>{};
    for (final c in all) {
      final l = lanes.putIfAbsent(c.day, () => []);
      var placed = false;
      for (var i = 0; i < l.length; i++) {
        if (l[i] < c.startPeriod) {
          l[i] = c.endPeriod;
          laneOf[c.id ?? -1] = i;
          placed = true;
          break;
        }
      }
      if (!placed) {
        laneOf[c.id ?? -1] = l.length;
        l.add(c.endPeriod);
      }
    }

    // 每天的分栏数
    final laneCountOf = <int, int>{};
    for (final c in all) {
      final lc = laneCountOf[c.day] ?? 1;
      laneCountOf[c.day] = lc;
    }
    for (final e in lanes.entries) {
      laneCountOf[e.key] = e.value.length;
    }

    final now = DateTime.now();
    final isTodayWeek = weekOf(now, settings.startDate) == week;
    final todayCol = isTodayWeek ? now.weekday : -1;

    return LayoutBuilder(builder: (context, cons) {
      final width = cons.maxWidth;
      final colW = (width - _gutterW) / 7;
      // 行高按可用高度自适应：13 节铺满一屏，底部紧贴导航栏（仅极窄屏才滚动）
      final slotH =
          ((cons.maxHeight - _headerH) / kPeriodCount).clamp(16.0, 64.0);
      final totalH = _headerH + kPeriodCount * slotH;

      return SingleChildScrollView(
        // 内容能一屏放下时禁用滚动，把上下拖动让给「翻页切换周次」
        physics: totalH <= cons.maxHeight + 0.5
            ? const NeverScrollableScrollPhysics()
            : const ClampingScrollPhysics(),
        child: SizedBox(
          width: width,
          height: totalH,
          child: Stack(
            children: [
              // ---- 星期表头（周一~周日 + 日期）----
              Positioned(
                left: _gutterW,
                top: 0,
                right: 0,
                height: _headerH,
                child: Row(
                  children: [
                    for (var d = 1; d <= 7; d++)
                      Expanded(
                        child: _DayHeader(
                          day: d,
                          date: state.dateOf(week, d),
                          isToday: d == todayCol,
                          theme: theme,
                        ),
                      ),
                  ],
                ),
              ),
              // ---- 节次时间轴 + 网格背景 ----
              for (var i = 0; i < kPeriodCount; i++)
                Positioned(
                  left: 0,
                  top: _headerH + i * slotH,
                  width: width,
                  height: slotH,
                  child: Row(
                    children: [
                      SizedBox(
                        width: _gutterW,
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text('${i + 1}',
                                    style: TextStyle(
                                      fontSize: 15.5,
                                      height: 1.0,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white.withValues(alpha: 0.95),
                                    )),
                                const SizedBox(height: 3),
                                Text(
                                  '${kPeriods[i].start}\n${kPeriods[i].end}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    height: 1.15,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withValues(alpha: 0.62),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      for (var d = 1; d <= 7; d++)
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1.2, vertical: 1.4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.028),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.045),
                                width: 0.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              // ---- 今日列高亮 ----
              if (todayCol >= 1)
                Positioned(
                  left: _gutterW + (todayCol - 1) * colW + 1.2,
                  top: _headerH,
                  width: colW - 2.4,
                  height: kPeriodCount * slotH,
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              // ---- 课程卡片 ----
              for (final c in all)
                _buildCourseCard(
                    context, c, colW, slotH, laneOf, laneCountOf, theme),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildCourseCard(BuildContext context, Course c, double colW,
      double slotH, Map<int, int> laneOf, Map<int, int> laneCountOf,
      Color theme) {
    final lane = laneOf[c.id ?? -1] ?? 0;
    final laneCount = laneCountOf[c.day] ?? 1;
    final subW = colW / laneCount;
    return Positioned(
      left: _gutterW + (c.day - 1) * colW + lane * subW + 1.8,
      top: _headerH + (c.startPeriod - 1) * slotH + 2,
      width: subW - 3.2,
      height: c.span * slotH - 3.5,
      child: _MiniCourseCard(
        course: c,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CourseEditScreen.course(c, context.read<AppState>()),
          ),
        ),
        onLongPress: () => showCourseActions(context, c),
      ),
    );
  }
}

/// 7 列课表中的单门课程小卡片。
class _MiniCourseCard extends StatelessWidget {
  final Course course;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _MiniCourseCard({required this.course, this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final c = course;
    final color = Color(c.colorValue);
    final partial = !Weeks.isAll(c.weeks);
    return LiquidGlass(
      radius: BorderRadius.circular(10),
      tintColor: color,
      tintAlphaOverride: 1.2,
      padding: const EdgeInsets.fromLTRB(5, 5, 5, 4),
      glowColor: color,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        children: [
          // 课程名：整块居中，垂直居中于地点上方区域
          Expanded(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: Text(
                      c.name,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        shadows: [Shadow(color: Colors.black45, blurRadius: 3)],
                      ),
                    ),
                  ),
                  if (partial)
                    Padding(
                      padding: const EdgeInsets.only(left: 1.5, top: 1.5),
                      child: Icon(Icons.circle,
                          size: 5, color: Colors.white.withValues(alpha: 0.9)),
                    ),
                ],
              ),
            ),
          ),
          if (c.location.isNotEmpty)
            Text(
              c.location,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: 8.5,
                height: 1.15,
              ),
            ),
        ],
      ),
    );
  }
}

/// 星期表头（周X + 日期，今天高亮）。
class _DayHeader extends StatelessWidget {
  final int day;
  final DateTime date;
  final bool isToday;
  final Color theme;

  const _DayHeader({
    required this.day,
    required this.date,
    required this.isToday,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1.2),
      decoration: BoxDecoration(
        color: isToday ? theme.withValues(alpha: 0.32) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                weekdayName(day),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: isToday ? Colors.white : Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                fmtDateShort(date),
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                  color: isToday
                      ? Colors.white.withValues(alpha: 0.95)
                      : Colors.white.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 回到本周悬浮按钮。
class _BackToThisWeek extends StatelessWidget {
  final Color theme;
  const _BackToThisWeek({required this.theme});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return LiquidGlass(
      radius: BorderRadius.circular(22),
      tintColor: theme,
      tintAlphaOverride: 0.45,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      onTap: () => state.setBrowseWeek(state.currentWeek),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.arrow_back_rounded, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text('回到本周',
              style: const TextStyle(
                  color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

// ---------------- 面板 ----------------

void showCourseActions(BuildContext context, Course c) {
  final state = context.read<AppState>();
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => LiquidGlass(
      radius: BorderRadius.circular(24),
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 16),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      tintAlphaOverride: 0.34,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(c.name,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('${weekdayName(c.day)} · ${periodOf(c.startPeriod).range} ~ ${periodOf(c.endPeriod).range} · ${Weeks.describe(c.weeks)}',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12)),
          const SizedBox(height: 14),
          _ActionRow(
            icon: Icons.edit_rounded,
            label: '编辑课程',
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => CourseEditScreen.course(c, context.read<AppState>())));
            },
          ),
          _ActionRow(
            icon: Icons.palette_rounded,
            label: '更换颜色',
            onTap: () {
              Navigator.of(context).pop();
              showColorPickModal(context, c);
            },
          ),
          const Divider(color: Colors.white12, height: 18),
          _ActionRow(
            icon: Icons.delete_outline_rounded,
            label: '删除课程',
            danger: true,
            onTap: () async {
              Navigator.of(context).pop();
              await state.deleteCourse(c);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已删除课程'), duration: Duration(seconds: 1)),
                );
              }
            },
          ),
        ],
      ),
    ),
  );
}

/// 更换课程颜色弹窗（自定义颜色）。
Future<void> showColorPickModal(BuildContext context, Course c) {
  final state = context.read<AppState>();
  var selected = c.colorValue;
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) => LiquidGlass(
        radius: BorderRadius.circular(24),
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 16),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        tintAlphaOverride: 0.34,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('课程卡片颜色',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final color in kCourseColors)
                  GestureDetector(
                    onTap: () => setModalState(() => selected = color),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color(color),
                        shape: BoxShape.circle,
                        border: selected == color
                            ? Border.all(color: Colors.white, width: 2.5)
                            : Border.all(color: Colors.white.withValues(alpha: 0.25)),
                      ),
                      child: selected == color
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                          : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: LiquidGlass(
                radius: BorderRadius.circular(14),
                padding: EdgeInsets.zero,
                tintColor: Color(selected),
                tintAlphaOverride: 0.8,
                onTap: () async {
                  await state.updateCourse(c.copyWith(colorValue: selected));
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
                child: const Center(
                  child: Text('确定',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool danger;
  final VoidCallback onTap;
  const _ActionRow({required this.icon, required this.label, this.danger = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFFF6B6B) : Colors.white;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color.withValues(alpha: 0.9)),
            const SizedBox(width: 12),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 14.5, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ---------------- 分享 / 菜单 ----------------

void _showShareSheet(BuildContext context) {
  final state = context.read<AppState>();
  final week = state.browseWeek;
  final sb = StringBuffer()..writeln('【第$week 周课表】');
  for (var d = 1; d <= 7; d++) {
    final list = state.coursesOn(d, week);
    if (list.isEmpty) continue;
    sb.writeln('${weekdayName(d)} ${fmtDateShort(state.dateOf(week, d))}：');
    for (final c in list) {
      sb.writeln('  ${periodOf(c.startPeriod).range}~${periodOf(c.endPeriod).range} ${c.name}'
          '${c.location.isNotEmpty ? " @${c.location}" : ""}（${Weeks.describe(c.weeks)}）');
    }
  }
  final text = sb.toString();
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => LiquidGlass(
      radius: BorderRadius.circular(24),
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 16),
      padding: const EdgeInsets.all(18),
      tintAlphaOverride: 0.34,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('分享本周课表',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Container(
            height: 150,
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SingleChildScrollView(
              child: Text(text,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11.5, height: 1.5)),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: LiquidGlass(
              radius: BorderRadius.circular(14),
              padding: EdgeInsets.zero,
              tintColor: themeColorOf(state.settings),
              tintAlphaOverride: 0.8,
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: text));
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已复制到剪贴板'), duration: Duration(seconds: 1)),
                  );
                }
              },
              child: const Center(
                child: Text('复制到剪贴板',
                    style: TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

void _showMenuSheet(BuildContext context) {
  final state = context.read<AppState>();
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => LiquidGlass(
      radius: BorderRadius.circular(24),
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 16),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      tintAlphaOverride: 0.34,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ActionRow(
            icon: Icons.upload_file_rounded,
            label: '导入课表（doc / docx / xls / xlsx）',
            onTap: () {
              Navigator.of(context).pop();
              runScheduleImport(context);
            },
          ),
          _ActionRow(
            icon: Icons.add_circle_outline_rounded,
            label: '添加课程',
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => CourseEditScreen.course(null, context.read<AppState>())));
            },
          ),
          _ActionRow(
            icon: Icons.event_rounded,
            label: '开学日期（当前 ${state.settings.startDate}）',
            onTap: () {
              Navigator.of(context).pop();
              pickStartDate(context);
            },
          ),
        ],
      ),
    ),
  );
}

/// 开学日期选择（自定义开学日期）。
Future<void> pickStartDate(BuildContext context) async {
  final state = context.read<AppState>();
  final initial = parseDate(state.settings.startDate);
  final picked = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2020),
    lastDate: DateTime(2030),
    builder: (ctx, child) => Theme(
      data: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(
            seedColor: themeColorOf(state.settings), brightness: Brightness.dark),
      ),
      child: child!,
    ),
  );
  if (picked != null) {
    await state.setStartDate(fmtDate(picked));
  }
}
