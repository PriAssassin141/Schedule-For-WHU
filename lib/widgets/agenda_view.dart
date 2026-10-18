import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:provider/provider.dart';

import 'package:class_manager/models/agenda_event.dart';
import 'package:class_manager/models/periods.dart';
import 'package:class_manager/screens/agenda_edit_screen.dart';
import 'package:class_manager/screens/course_edit_screen.dart';
import 'package:class_manager/services/agenda_timeline.dart';
import 'package:class_manager/state/app_state.dart';
import 'package:class_manager/theme/palette.dart';
import 'package:class_manager/utils/weeks.dart';
import 'package:class_manager/widgets/agenda_event_dialog.dart';
import 'package:class_manager/widgets/course_info_dialog.dart';
import 'package:class_manager/widgets/glass.dart';
import 'package:class_manager/widgets/glass_dialog.dart';
import 'package:class_manager/widgets/lens_rail.dart';

class HomeViewSelector extends StatelessWidget {
  const HomeViewSelector({super.key});

  Future<void> _open(BuildContext context) async {
    final state = context.read<AppState>();
    final anchor = context.findRenderObject()! as RenderBox;
    final navigator = Navigator.of(context);
    final overlay = navigator.overlay!.context.findRenderObject()! as RenderBox;
    final origin = anchor.localToGlobal(Offset.zero, ancestor: overlay);
    final route = _HomeViewMenuRoute(
      anchor: origin & anchor.size,
      selected: state.settings.homeViewMode,
      color: themeColorOf(state.settings),
      liquid: state.settings.liquidGlass,
      jelly: state.settings.jellyEffect,
      reduceMotion: MediaQuery.disableAnimationsOf(context),
    );
    final mode = await navigator.push<HomeViewMode>(route);
    // Preserve the scene being sampled until the glass has folded away.
    await route.completed;
    if (mode == null || !context.mounted) return;
    try {
      await state.setHomeViewMode(mode);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('视图切换失败，请重试')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Semantics(
      button: true,
      label: '切换视图，当前${state.settings.homeViewMode.label}',
      child: SizedBox(
        key: const ValueKey('home_view_selector'),
        width: 104,
        height: 34,
        child: LiquidGlass(
          onTap: () => _open(context),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          radius: BorderRadius.circular(12),
          tintAlphaOverride: 0.22,
          child: SizedBox.expand(
            child: Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      state.settings.homeViewMode.shortLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.expand_more_rounded,
                  color: Colors.white70,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Animate the panel's visible height, never an Opacity/Transform layer around
/// its backdrop filters. Opacity's offscreen buffer loses the live scene until
/// opacity reaches 1, producing a transparent menu followed by a material pop.
class _HomeViewMenuRoute extends PopupRoute<HomeViewMode> {
  _HomeViewMenuRoute({
    required this.anchor,
    required this.selected,
    required this.color,
    required this.liquid,
    required this.jelly,
    required this.reduceMotion,
  });

  final Rect anchor;
  final HomeViewMode selected;
  final Color color;
  final bool liquid;
  final bool jelly;
  final bool reduceMotion;
  static const _height = 156.0;
  double? _closingFrom;
  double _closingHeight = 0;

  @override
  Color get barrierColor => Colors.transparent;
  @override
  bool get barrierDismissible => true;
  @override
  String get barrierLabel => '关闭视图菜单';
  @override
  Duration get transitionDuration =>
      reduceMotion ? Duration.zero : Duration(milliseconds: liquid ? 300 : 180);
  @override
  Duration get reverseTransitionDuration =>
      reduceMotion ? Duration.zero : const Duration(milliseconds: 180);

  Curve get _revealCurve => liquid && jelly && !reduceMotion
      ? const Cubic(0.2, 0.85, 0.25, 1.06)
      : Curves.easeOutCubic;

  @override
  bool didPop(HomeViewMode? result) {
    final motion = controller;
    _closingFrom = motion?.value;
    _closingHeight = _revealCurve.transform(motion?.value ?? 0);
    if (!reduceMotion && motion != null && motion.value > 0) {
      // Base an early reversal's duration on visible height, rather than the
      // nonlinear controller time, to avoid an abrupt disappearance on retap.
      final visible = _revealCurve.transform(motion.value).clamp(0.0, 1.0);
      motion.reverseDuration = Duration(
        microseconds:
            (reverseTransitionDuration.inMicroseconds * visible / motion.value)
                .round(),
      );
    }
    return super.didPop(result);
  }

  double _visibleProgress(double value) {
    final start = _closingFrom;
    if (start == null || start <= 0) return _revealCurve.transform(value);
    // Rebase at the current pose before reversing. Closing can use a quicker
    // symmetric curve without jumping or replaying the opening's settle tail.
    return _closingHeight *
        Curves.easeInOutCubic.transform((value / start).clamp(0.0, 1.0));
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 24).clamp(0.0, 200.0);
        final right = (constraints.maxWidth - anchor.right).clamp(
          12.0,
          constraints.maxWidth - width - 12,
        );
        final top = (anchor.bottom + 6).clamp(
          12.0,
          (constraints.maxHeight - _height - 12).clamp(12.0, double.infinity),
        );
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final reveal = _visibleProgress(animation.value);
            return Stack(
              children: [
                Positioned(
                  top: top,
                  right: right,
                  width: width,
                  child: Material(
                    type: MaterialType.transparency,
                    child: LiquidGlass(
                      key: const ValueKey('home_view_menu_glass'),
                      nativeBackdrop: true,
                      showShadow: false,
                      // Native blur and Lens reflection stay stable while the
                      // bounds change; magnifier layers can retain old bounds.
                      backgroundColor: Color(liquid ? 0x66121A22 : 0xCC121A22),
                      tintAlphaOverride: 0.24,
                      radius: BorderRadius.circular(20),
                      padding: EdgeInsets.zero,
                      child: SizedBox(
                        key: const ValueKey('home_view_menu_reveal'),
                        height: _height * reveal,
                        // Keep row geometry and blur strength unchanged as the
                        // rounded glass edge reveals/hides the rows from the top.
                        child: ClipRect(
                          child: OverflowBox(
                            alignment: Alignment.topCenter,
                            minHeight: _height,
                            maxHeight: _height,
                            minWidth: width,
                            maxWidth: width,
                            child: child,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              children: [
                for (final item in HomeViewMode.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: SizedBox(
                      height: 44,
                      child: LiquidGlass(
                        key: ValueKey('home_mode_${item.name}'),
                        nativeBackdrop: true,
                        showShadow: false,
                        radius: BorderRadius.circular(14),
                        tintColor: color,
                        tintAlphaOverride: item == selected ? 0.7 : 0.04,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        onTap: () => Navigator.of(context).pop(item),
                        child: SizedBox.expand(
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.shortLabel,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              if (item == selected)
                                Icon(
                                  Icons.check_rounded,
                                  color: color,
                                  size: 18,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}

Future<void> _createItem(BuildContext context) async {
  final state = context.read<AppState>();
  if (state.settings.homeViewMode == HomeViewMode.agenda) {
    await openAgendaEditor(context, initialDate: state.agendaDate);
    return;
  }
  final kind = await showDialog<String>(
    context: context,
    builder: (ctx) => GlassDialog(
      title: const Text('添加安排'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LiquidGlass(
            onTap: () => Navigator.of(ctx).pop('agenda'),
            tintAlphaOverride: 0.2,
            child: const Row(
              children: [
                Icon(Icons.event_note_rounded, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text('添加日程', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          LiquidGlass(
            onTap: () => Navigator.of(ctx).pop('course'),
            tintAlphaOverride: 0.2,
            child: const Row(
              children: [
                Icon(Icons.school_outlined, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text('添加课程', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        GlassDialogButton(
          label: '取消',
          onPressed: () => Navigator.of(ctx).pop(),
        ),
      ],
    ),
  );
  if (!context.mounted) return;
  if (kind == 'agenda') {
    await openAgendaEditor(context, initialDate: state.agendaDate);
  } else if (kind == 'course') {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CourseEditScreen.course(null, state)),
    );
  }
}

class AgendaHeader extends StatelessWidget {
  final VoidCallback onMenu;
  const AgendaHeader({super.key, required this.onMenu});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final date = state.agendaDate;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              key: const ValueKey('agenda_date_picker'),
              onTap: () async {
                final picked = await showGlassDatePicker(
                  context: context,
                  initialDate: date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100, 12, 31),
                );
                if (picked != null) state.setAgendaDate(picked);
              },
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${date.year}年${date.month}月',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.expand_more_rounded,
                      color: Colors.white60,
                      size: 19,
                    ),
                  ],
                ),
              ),
            ),
          ),
          GlassIconButton(
            icon: Icons.add_rounded,
            size: 32,
            onTap: () => _createItem(context),
          ),
          const SizedBox(width: 6),
          GlassIconButton(icon: Icons.menu_rounded, size: 32, onTap: onMenu),
          const SizedBox(width: 6),
          const HomeViewSelector(),
        ],
      ),
    );
  }
}

class AgendaView extends StatelessWidget {
  const AgendaView({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final date = state.agendaDate;
    final combined = state.settings.homeViewMode == HomeViewMode.combined;
    final items = state.agendaItemsOn(date, includeCourses: combined);
    final theme = themeColorOf(state.settings);
    final count = items.where((item) => item.event != null).length;
    return Column(
      children: [
        AgendaDateStrip(includeCourses: combined),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${fmtDate(date)} ${weekdayName(date.weekday)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                combined
                    ? '${items.length - count}门课 · $count项日程'
                    : '$count项日程',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(width: 8),
              TextButton(
                key: const ValueKey('agenda_today'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(36, 28),
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => state.setAgendaDate(DateTime.now()),
                child: Text(
                  '回到今天',
                  style: TextStyle(
                    color: theme,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? ListView(
                  padding: const EdgeInsets.fromLTRB(16, 28, 16, 110),
                  children: [
                    LiquidGlass(
                      key: const ValueKey('agenda_empty_state'),
                      backgroundColor: const Color(0x55121A22),
                      padding: const EdgeInsets.all(24),
                      child: SizedBox(
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.event_available_outlined,
                              color: theme,
                              size: 34,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              combined ? '这一天没有课程或日程' : '这一天还没有日程',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '安排一次运动、一场会议，或留出专注时间。',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 13,
                                height: 1.7,
                              ),
                            ),
                            const SizedBox(height: 18),
                            GlassDialogButton(
                              label: '添加日程',
                              primary: true,
                              onPressed: () =>
                                  openAgendaEditor(context, initialDate: date),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  key: ValueKey(
                    'agenda_list_${fmtDate(date)}_${state.settings.homeViewMode.name}',
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 110),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, index) => _AgendaCard(
                    item: items[index],
                    day: date,
                    conflict: items.asMap().entries.any(
                      (entry) =>
                          entry.key != index &&
                          items[index].overlaps(entry.value),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

/// Swipe the date row to browse adjacent weeks without a separate toolbar.
/// External date changes (calendar/today/save) keep the pager synchronized.
class AgendaDateStrip extends StatefulWidget {
  final bool includeCourses;
  const AgendaDateStrip({super.key, required this.includeCourses});
  @override
  State<AgendaDateStrip> createState() => _AgendaDateStripState();
}

class _AgendaDateStripState extends State<AgendaDateStrip> {
  static final _first = calendarMonday(DateTime(2000));
  static final _last = calendarMonday(DateTime(2100, 12, 31));
  late final PageController _controller;
  late int _shownPage;

  int _pageFor(DateTime date) {
    final monday = calendarMonday(date);
    return DateTime.utc(monday.year, monday.month, monday.day)
            .difference(DateTime.utc(_first.year, _first.month, _first.day))
            .inDays ~/
        7;
  }

  @override
  void initState() {
    super.initState();
    _shownPage = _pageFor(context.read<AppState>().agendaDate);
    _controller = PageController(initialPage: _shownPage, keepPage: false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final target = _pageFor(state.agendaDate);
    if (target != _shownPage) {
      _shownPage = target;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _shownPage == target && _controller.hasClients) {
          _controller.jumpToPage(target);
        }
      });
    }
    return SizedBox(
      height: 54,
      child: PageView.builder(
        key: const ValueKey('agenda_date_strip'),
        controller: _controller,
        itemCount: _pageFor(_last) + 1,
        onPageChanged: (page) {
          if (page == _shownPage) return;
          _shownPage = page;
          state.setAgendaDate(
            DateTime(
              _first.year,
              _first.month,
              _first.day + page * 7 + state.agendaDate.weekday - 1,
            ),
          );
        },
        itemBuilder: (context, page) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _DateWeek(
            key: ValueKey(page),
            monday: DateTime(_first.year, _first.month, _first.day + page * 7),
            selectedIndex: state.agendaDate.weekday - 1,
            active: target == page,
            includeCourses: widget.includeCourses,
          ),
        ),
      ),
    );
  }
}

class _DateWeek extends StatefulWidget {
  final DateTime monday;
  final int selectedIndex;
  final bool active;
  final bool includeCourses;
  const _DateWeek({
    super.key,
    required this.monday,
    required this.selectedIndex,
    required this.active,
    required this.includeCourses,
  });
  @override
  State<_DateWeek> createState() => _DateWeekState();
}

class _DateWeekState extends State<_DateWeek> with TickerProviderStateMixin {
  late final _rail = LensRailController(
    vsync: this,
    initialValue: widget.selectedIndex.toDouble(),
  );
  late final _impact = AnimationController.unbounded(vsync: this);
  bool _animate = false;
  bool _jelly = false;
  bool _pendingArrival = false;
  double _departure = 0;

  @override
  void initState() {
    super.initState();
    _rail.addListener(_travel);
  }

  void _travel() {
    final target = widget.selectedIndex.toDouble();
    if (!_pendingArrival ||
        ((_rail.value - target).abs() > 0.08 &&
            (target - _departure) * (_rail.value - target) < 0)) {
      return;
    }
    _pendingArrival = false;
    _impact.animateWith(
      SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 420, damping: 13),
        _impact.value,
        0,
        5,
        snapToEnd: true,
        tolerance: const Tolerance(distance: 0.0001, velocity: 0.001),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = context.watch<AppState>().settings;
    _animate = settings.liquidGlass && !MediaQuery.disableAnimationsOf(context);
    _jelly = _animate && settings.jellyEffect;
    if (!_jelly) {
      _pendingArrival = false;
      _impact.stop();
      _impact.value = 0;
    }
    if (!_animate) {
      _rail.settle(widget.selectedIndex.toDouble(), animate: false);
    }
  }

  @override
  void didUpdateWidget(covariant _DateWeek oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _departure = _rail.value;
      _pendingArrival = _jelly;
      _rail.settle(widget.selectedIndex.toDouble(), animate: _animate);
    }
  }

  @override
  void dispose() {
    _rail.dispose();
    _impact.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppState>().settings;
    final theme = themeColorOf(settings);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth / 7;
        return Stack(
          children: [
            if (settings.liquidGlass && widget.active)
              AnimatedBuilder(
                animation: Listenable.merge([_rail, _impact]),
                builder: (context, _) {
                  final stretch = _jelly
                      ? (_rail.velocity.abs() * 0.009).clamp(0.0, 0.08)
                      : 0.0;
                  final impact = _jelly ? _impact.value : 0.0;
                  final position = _rail.value.clamp(0.0, 6.0);
                  final physical =
                      Directionality.of(context) == TextDirection.rtl
                      ? 6 - position
                      : position;
                  return Positioned(
                    left: physical * width + 2,
                    top: 0,
                    bottom: 0,
                    width: width - 4,
                    child: IgnorePointer(
                      child: Transform.scale(
                        key: const ValueKey('agenda_date_deformation'),
                        scaleX: (1 + stretch - impact).clamp(0.84, 1.12),
                        scaleY: (1 / (1 + stretch) + impact * 0.65).clamp(
                          0.90,
                          1.10,
                        ),
                        child: LiquidGlass(
                          key: const ValueKey('agenda_date_indicator'),
                          radius: BorderRadius.circular(14),
                          showShadow: false,
                          refractFallback: true,
                          pressure: stretch * 3 + impact.abs() * 3,
                          tintColor: theme,
                          tintAlphaOverride: 0.60,
                          padding: EdgeInsets.zero,
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  );
                },
              ),
            Row(
              children: [
                for (var day = 0; day < 7; day++)
                  Expanded(
                    child: _DayButton(
                      day: DateTime(
                        widget.monday.year,
                        widget.monday.month,
                        widget.monday.day + day,
                      ),
                      selected: widget.active && day == widget.selectedIndex,
                      includeCourses: widget.includeCourses,
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _DayButton extends StatelessWidget {
  final DateTime day;
  final bool selected;
  final bool includeCourses;
  const _DayButton({
    required this.day,
    required this.selected,
    required this.includeCourses,
  });
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = themeColorOf(state.settings);
    final hasItems = state
        .agendaItemsOn(day, includeCourses: includeCourses)
        .isNotEmpty;
    final today = calendarDate(DateTime.now()) == day;
    final enabled =
        !day.isBefore(DateTime(2000)) && !day.isAfter(DateTime(2100, 12, 31));
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: '${fmtDate(day)} ${weekdayName(day.weekday)}',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: LiquidGlass(
          key: ValueKey('agenda_day_${day.weekday}'),
          radius: BorderRadius.circular(14),
          padding: EdgeInsets.zero,
          showShadow: false,
          tintColor: theme,
          tintAlphaOverride: selected && !state.settings.liquidGlass ? 0.7 : 0,
          onTap: enabled ? () => state.setAgendaDate(day) : null,
          child: SizedBox.expand(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  weekdayName(day.weekday),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: !enabled
                        ? Colors.white24
                        : selected
                        ? Colors.white
                        : Colors.white60,
                    fontSize: 11,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${day.day}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: !enabled
                        ? Colors.white24
                        : today
                        ? theme
                        : Colors.white,
                    fontSize: 17,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  width: 3,
                  height: 3,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasItems ? theme : Colors.transparent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AgendaCard extends StatelessWidget {
  final AgendaDayItem item;
  final DateTime day;
  final bool conflict;
  const _AgendaCard({
    required this.item,
    required this.day,
    required this.conflict,
  });
  @override
  Widget build(BuildContext context) {
    final color = Color(item.colorValue);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 54,
          child: Padding(
            padding: const EdgeInsets.only(top: 13),
            child: Column(
              children: [
                Text(
                  item.startLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 2,
                  height: 32,
                  color: color.withValues(alpha: 0.45),
                ),
                const SizedBox(height: 8),
                Text(
                  item.endLabel(day),
                  style: const TextStyle(
                    color: Colors.white60,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: LiquidGlass(
            key: ValueKey(
              'agenda_${item.event != null ? 'event_${item.event!.id}' : 'course_${item.course!.course.id}'}',
            ),
            backgroundColor: const Color(0x55121A22),
            tintColor: color,
            tintAlphaOverride: 0.28,
            padding: const EdgeInsets.all(14),
            onTap: () => item.event != null
                ? showAgendaEventDialog(context, item.event!)
                : showCourseInfoDialog(context, item.course!),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 5,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        item.categoryLabel,
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (item.crossesDay)
                      const Text(
                        '跨日',
                        style: TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                    if (conflict)
                      const Text(
                        '时间重叠',
                        style: TextStyle(
                          color: Color(0xFFFFC082),
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
                if (item.location.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: Colors.white60,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (item.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    item.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
