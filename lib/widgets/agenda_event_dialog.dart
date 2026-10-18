import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:class_manager/models/agenda_event.dart';
import 'package:class_manager/screens/agenda_edit_screen.dart';
import 'package:class_manager/state/app_state.dart';
import 'package:class_manager/utils/weeks.dart';
import 'package:class_manager/widgets/glass_dialog.dart';

Future<void> showAgendaEventDialog(
  BuildContext context,
  AgendaEvent event,
) async {
  final state = context.read<AppState>();
  final edit = await showDialog<bool>(
    context: context,
    builder: (ctx) => GlassDialog(
      key: const ValueKey('agenda_info_dialog'),
      title: Row(
        children: [
          Container(width: 4, height: 24, color: Color(event.colorValue)),
          const SizedBox(width: 12),
          Expanded(child: Text(event.name)),
          IconButton(
            key: const ValueKey('agenda_info_delete'),
            tooltip: '删除日程',
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
            onPressed: () async {
              if (!await confirmAgendaDeletion(ctx, event) || !ctx.mounted) {
                return;
              }
              try {
                await state.deleteAgendaEvent(event);
                if (ctx.mounted) Navigator.of(ctx).pop(false);
              } catch (_) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(
                    ctx,
                  ).showSnackBar(const SnackBar(content: Text('删除失败，请重试')));
                }
              }
            },
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailRow('类型', event.categoryLabel),
          _DetailRow(
            '开始',
            '${fmtDate(event.startAt)} ${agendaTime(event.startAt)}',
          ),
          _DetailRow(
            '结束',
            '${fmtDate(event.endAt)} ${agendaTime(event.endAt)}',
          ),
          _DetailRow('地点', event.location),
          _DetailRow('描述', event.description),
        ],
      ),
      actions: [
        GlassDialogButton(
          label: '关闭',
          onPressed: () => Navigator.of(ctx).pop(false),
        ),
        GlassDialogButton(
          key: const ValueKey('agenda_info_edit'),
          label: '编辑',
          primary: true,
          icon: Icons.edit_outlined,
          onPressed: () => Navigator.of(ctx).pop(true),
        ),
      ],
    ),
  );
  if (edit == true && context.mounted) {
    await openAgendaEditor(context, event: event);
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 48,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value.trim().isEmpty ? '未填写' : value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.6,
            ),
          ),
        ),
      ],
    ),
  );
}
