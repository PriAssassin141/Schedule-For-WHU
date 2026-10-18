import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:class_manager/state/app_state.dart';
import 'package:class_manager/theme/palette.dart';
import 'package:class_manager/widgets/glass.dart';

/// 所有居中弹窗复用页面的玻璃效果和个性化设置。
class GlassDialog extends StatelessWidget {
  final Widget? title;
  final Widget? content;
  final Widget? child;
  final List<Widget> actions;
  final double maxWidth;

  const GlassDialog({
    super.key,
    this.title,
    this.content,
    this.child,
    this.actions = const [],
    this.maxWidth = 520,
  });

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: maxWidth,
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: LiquidGlass(
        radius: BorderRadius.circular(24),
        // Keep background detail from competing with modal text, while the
        // existing blur/refraction and translucent surface remain visible.
        backgroundColor: const Color(0xCC121A22),
        tintAlphaOverride: 0.22,
        padding: const EdgeInsets.all(22),
        child:
            child ??
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  DefaultTextStyle.merge(
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                    child: title!,
                  ),
                  const SizedBox(height: 16),
                ],
                if (content != null)
                  Flexible(child: SingleChildScrollView(child: content!)),
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(spacing: 10, runSpacing: 8, children: actions),
                  ),
                ],
              ],
            ),
      ),
    ),
  );
}

class GlassDialogButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool primary;
  final bool danger;
  final bool expanded;
  final Color? color;
  final IconData? icon;
  final bool nativeBackdrop;

  const GlassDialogButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.danger = false,
    this.expanded = false,
    this.color,
    this.icon,
    this.nativeBackdrop = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = danger
        ? const Color(0xFFFF6B6B)
        : color ?? themeColorOf(context.watch<AppState>().settings);
    final labelText = Text(
      label,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
    return Semantics(
      button: true,
      child: LiquidGlass(
        nativeBackdrop: nativeBackdrop,
        radius: BorderRadius.circular(14),
        tintColor: primary || danger ? accent : Colors.white,
        tintAlphaOverride: primary || danger ? 0.75 : 0.18,
        padding: EdgeInsets.symmetric(
          horizontal: expanded ? 8 : 16,
          vertical: 11,
        ),
        onTap: onPressed,
        child: Row(
          mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 17),
              const SizedBox(width: 6),
            ],
            if (expanded) Flexible(child: labelText) else labelText,
          ],
        ),
      ),
    );
  }
}

/// 玻璃选项菜单，替代自带不透明背景的下拉菜单。
class GlassSelect<T> extends StatelessWidget {
  final T value;
  final String title;
  final Map<T, String> options;
  final ValueChanged<T>? onChanged;
  final String? extraOptionLabel;
  final Key? extraOptionKey;
  final VoidCallback? onExtraOption;
  final bool centerSelectedLabel;

  const GlassSelect({
    super.key,
    required this.value,
    required this.title,
    required this.options,
    required this.onChanged,
    this.extraOptionLabel,
    this.extraOptionKey,
    this.onExtraOption,
    this.centerSelectedLabel = false,
  });

  Future<void> _choose(BuildContext context) async {
    final route = DialogRoute<({T? value, bool extra})>(
      context: context,
      builder: (dialogContext) => GlassDialog(
        title: Text(title),
        maxWidth: 380,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in options.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: LiquidGlass(
                  tintColor: option.key == value
                      ? themeColorOf(context.read<AppState>().settings)
                      : Colors.white,
                  tintAlphaOverride: option.key == value ? 0.55 : 0.14,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  onTap: () => Navigator.of(
                    dialogContext,
                  ).pop((value: option.key, extra: false)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          option.value,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (option.key == value)
                        const Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                    ],
                  ),
                ),
              ),
            if (extraOptionLabel != null && onExtraOption != null) ...[
              const Divider(color: Colors.white12, height: 16),
              LiquidGlass(
                key: extraOptionKey,
                tintAlphaOverride: 0.2,
                onTap: () =>
                    Navigator.of(dialogContext).pop((value: null, extra: true)),
                child: Row(
                  children: [
                    const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        extraOptionLabel!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          GlassDialogButton(
            label: '取消',
            nativeBackdrop: true,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
    final selected = await Navigator.of(
      context,
      rootNavigator: true,
    ).push(route);
    if (selected == null || !context.mounted) return;
    if (selected.extra) {
      await route.completed;
      if (context.mounted) onExtraOption?.call();
    } else {
      final value = selected.value;
      if (value != null) onChanged?.call(value);
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$title：${options[value]}',
    child: LiquidGlass(
      tintAlphaOverride: 0.14,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      onTap: onChanged == null ? null : () => _choose(context),
      child: Row(
        mainAxisSize: centerSelectedLabel ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (centerSelectedLabel) const SizedBox(width: 26),
          Flexible(
            fit: centerSelectedLabel ? FlexFit.tight : FlexFit.loose,
            child: Text(
              options[value] ?? '',
              textAlign: centerSelectedLabel
                  ? TextAlign.center
                  : TextAlign.start,
              maxLines: centerSelectedLabel ? 1 : null,
              overflow: centerSelectedLabel ? TextOverflow.ellipsis : null,
              style: const TextStyle(color: Colors.white, fontSize: 13.5),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.expand_more_rounded,
            size: 18,
            color: Colors.white70,
          ),
        ],
      ),
    ),
  );
}

Future<DateTime?> showGlassDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) => showDialog<DateTime>(
  context: context,
  builder: (_) => _GlassDatePicker(
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
  ),
);

class _GlassDatePicker extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  const _GlassDatePicker({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<_GlassDatePicker> createState() => _GlassDatePickerState();
}

class _GlassDatePickerState extends State<_GlassDatePicker> {
  late DateTime _date = widget.initialDate;

  @override
  Widget build(BuildContext context) => GlassDialog(
    maxWidth: 400,
    title: const Text('选择日期'),
    content: SizedBox(
      width: 360,
      height: 340,
      child: CalendarDatePicker(
        initialDate: widget.initialDate,
        firstDate: widget.firstDate,
        lastDate: widget.lastDate,
        onDateChanged: (date) => setState(() => _date = date),
      ),
    ),
    actions: [
      GlassDialogButton(
        label: '取消',
        onPressed: () => Navigator.of(context).pop(),
      ),
      GlassDialogButton(
        label: '确定',
        primary: true,
        onPressed: () => Navigator.of(context).pop(_date),
      ),
    ],
  );
}

Future<TimeOfDay?> showGlassTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
}) => showDialog<TimeOfDay>(
  context: context,
  builder: (_) => _GlassTimePicker(initialTime: initialTime),
);

class _GlassTimePicker extends StatefulWidget {
  final TimeOfDay initialTime;
  const _GlassTimePicker({required this.initialTime});
  @override
  State<_GlassTimePicker> createState() => _GlassTimePickerState();
}

class _GlassTimePickerState extends State<_GlassTimePicker> {
  late TimeOfDay _time = widget.initialTime;
  @override
  Widget build(BuildContext context) => GlassDialog(
    maxWidth: 400,
    title: const Text('选择时间'),
    content: SizedBox(
      height: 180,
      child: CupertinoTheme(
        data: const CupertinoThemeData(brightness: Brightness.dark),
        child: CupertinoDatePicker(
          mode: CupertinoDatePickerMode.time,
          use24hFormat: true,
          initialDateTime: DateTime(
            2026,
            1,
            1,
            widget.initialTime.hour,
            widget.initialTime.minute,
          ),
          onDateTimeChanged: (date) =>
              setState(() => _time = TimeOfDay.fromDateTime(date)),
        ),
      ),
    ),
    actions: [
      GlassDialogButton(
        label: '取消',
        onPressed: () => Navigator.of(context).pop(),
      ),
      GlassDialogButton(
        label: '确定',
        primary: true,
        onPressed: () => Navigator.of(context).pop(_time),
      ),
    ],
  );
}
