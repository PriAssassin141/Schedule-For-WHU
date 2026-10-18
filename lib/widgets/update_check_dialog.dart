import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import 'package:class_manager/config/release_metadata.dart';
import 'package:class_manager/models/update_manifest.dart';
import 'package:class_manager/services/quark_update_service.dart';
import 'package:class_manager/state/app_state.dart';
import 'package:class_manager/theme/palette.dart';
import 'package:class_manager/widgets/glass.dart';
import 'package:class_manager/widgets/glass_dialog.dart';

class UpdateCheckDialog extends StatefulWidget {
  final VoidCallback onDownload;
  final UpdateCheckerFactory? checkerFactory;
  const UpdateCheckDialog({
    super.key,
    required this.onDownload,
    this.checkerFactory,
  });

  @override
  State<UpdateCheckDialog> createState() => _UpdateCheckDialogState();
}

class _UpdateCheckDialogState extends State<UpdateCheckDialog> {
  UpdateChecker? _checker;
  PackageInfo? _installed;
  UpdateManifest? _latest;
  String? _error;
  bool _checking = true;
  bool _versionUnavailable = false;
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    _loadInstalled();
    _check();
  }

  Future<void> _loadInstalled() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _installed = info;
        _versionUnavailable = info.version.isEmpty;
      });
    } catch (_) {
      if (mounted) setState(() => _versionUnavailable = true);
    }
  }

  Future<void> _check() async {
    final attempt = ++_attempt;
    _checker?.close();
    final factory =
        widget.checkerFactory ??
        context.read<UpdateCheckerFactory?>() ??
        QuarkUpdateService.new;
    final checker = _checker = factory();
    setState(() {
      _checking = true;
      _error = null;
      _latest = null;
    });
    try {
      final latest = await checker.fetchLatest();
      if (mounted && _attempt == attempt) setState(() => _latest = latest);
    } catch (error) {
      if (mounted && _attempt == attempt) {
        setState(() {
          _error = error is UpdateCheckException
              ? error.message
              : '暂时无法检查更新，请稍后重试';
        });
      }
    } finally {
      if (mounted && _attempt == attempt) setState(() => _checking = false);
    }
  }

  @override
  void dispose() {
    _checker?.close();
    super.dispose();
  }

  Widget _versionRow(String label, String value, Color accent) => LiquidGlass(
    tintAlphaOverride: 0.22,
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 15),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: accent,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final accent = themeColorOf(context.watch<AppState>().settings);
    final installed = _installed;
    final latest = _latest;
    DateTime? currentTime;
    bool? needsUpdate;
    try {
      currentTime = parseReleaseTime(appReleaseUpdateTime);
      if (installed != null && installed.version.isNotEmpty && latest != null) {
        needsUpdate = latest.isNewerThan(installed.version, currentTime);
      }
    } on FormatException {
      // Unknown build metadata must never be reported as up to date.
    }
    final status = _checking
        ? '正在扫描网盘更新日志…'
        : _error != null
        ? '检查更新失败'
        : needsUpdate == true
        ? '发现新版本，建议更新'
        : needsUpdate == false
        ? '当前版本无需更新'
        : '无法核对本机版本，请前往下载页面确认';
    return GlassDialog(
      title: Row(
        children: [
          Icon(Icons.save_alt_rounded, color: accent, size: 23),
          const SizedBox(width: 10),
          const Text('检查更新'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _versionRow(
            '当前版本',
            _versionUnavailable
                ? '暂时无法读取'
                : installed == null
                ? '读取中…'
                : 'v${installed.version}',
            accent,
          ),
          if (currentTime != null) ...[
            const SizedBox(height: 8),
            Text(
              '本机发布时间：${formatReleaseTime(currentTime)}',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              if (_checking)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: accent,
                  ),
                )
              else
                Icon(
                  _error != null
                      ? Icons.info_outline_rounded
                      : needsUpdate == true
                      ? Icons.new_releases_outlined
                      : needsUpdate == false
                      ? Icons.check_circle_outline_rounded
                      : Icons.info_outline_rounded,
                  color: _error == null ? accent : Colors.white70,
                  size: 20,
                ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  status,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: Colors.white70, height: 1.6),
            ),
            TextButton.icon(
              onPressed: () {
                if (_installed == null) _loadInstalled();
                _check();
              },
              icon: Icon(Icons.refresh_rounded, color: accent, size: 18),
              label: Text('重新检查', style: TextStyle(color: accent)),
            ),
          ],
          if (latest != null) ...[
            const SizedBox(height: 14),
            _versionRow('网盘最新版本', 'v${latest.version.label}', accent),
            const SizedBox(height: 8),
            Text(
              '更新时间：${formatReleaseTime(latest.updatedAt)}',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            if (latest.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                '更新内容',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                latest.description,
                style: const TextStyle(color: Colors.white70, height: 1.6),
              ),
            ],
          ],
          const SizedBox(height: 12),
          const Text(
            '如需获取最新版本安装包，请点击下方按钮前往下载链接。',
            style: TextStyle(color: Colors.white70, height: 1.6),
          ),
        ],
      ),
      actions: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: GlassDialogButton(
                  label: '跳转到下载链接',
                  primary: true,
                  expanded: true,
                  onPressed: widget.onDownload,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GlassDialogButton(
                  label: '取消',
                  expanded: true,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
