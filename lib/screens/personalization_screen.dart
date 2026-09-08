import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:class_manager/state/app_state.dart';
import 'package:class_manager/theme/palette.dart';
import 'package:class_manager/widgets/app_background.dart';
import 'package:class_manager/widgets/glass.dart';

/// 个性化页：完整复刻图二的设置项。
class PersonalizationScreen extends StatelessWidget {
  const PersonalizationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final settings = state.settings;
    final theme = themeColorOf(settings);

    return BackgroundedScaffold(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          // ---- 标题栏 ----
          Row(
            children: [
              GlassIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                size: 34,
                onTap: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 12),
              const Text('个性化',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 18),

          // ---- 主题颜色 ----
          _SectionTitle('主题颜色'),
          const SizedBox(height: 10),
          LiquidGlass(
            radius: BorderRadius.circular(18),
            tintAlphaOverride: 0.18,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < kThemeColors.length; i++)
                  GestureDetector(
                    onTap: () => state.updateSettings(
                        settings.copyWith(themeColorIndex: i)),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: kThemeColors[i],
                        shape: BoxShape.circle,
                        border: settings.themeColorIndex == i
                            ? Border.all(color: Colors.white, width: 2.5)
                            : Border.all(
                                color: Colors.white.withValues(alpha: 0.25)),
                      ),
                      child: settings.themeColorIndex == i
                          ? const Icon(Icons.check_rounded,
                              color: Colors.white, size: 17)
                          : null,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ---- 玻璃效果大卡片：一行一项，细线分隔 ----
          LiquidGlass(
            radius: BorderRadius.circular(22),
            padding: const EdgeInsets.symmetric(vertical: 6),
            tintAlphaOverride: 0.12,
            child: Column(
              children: [
                GlassSliderRow(
                  title: '背景模糊',
                  value: settings.backgroundBlur,
                  min: 0, max: 1,
                  label: (v) => (v * 100).round().toString(),
                  onChanged: (v) =>
                      state.updateSettings(settings.copyWith(backgroundBlur: v)),
                ),
                GlassSliderRow(
                  title: '卡片透明',
                  value: settings.cardTransparency,
                  min: 0, max: 1,
                  label: (v) => (v * 100).round().toString(),
                  onChanged: (v) =>
                      state.updateSettings(settings.copyWith(cardTransparency: v)),
                  showDivider: true,
                ),
                GlassSliderRow(
                  title: '卡片背景模糊',
                  value: settings.cardBlur,
                  min: 0, max: 1,
                  label: (v) => (v * 100).round().toString(),
                  onChanged: (v) =>
                      state.updateSettings(settings.copyWith(cardBlur: v)),
                  showDivider: true,
                ),
                GlassSwitchRow(
                  title: '液态玻璃',
                  subtitle: '性能要求高',
                  value: settings.liquidGlass,
                  onChanged: (v) =>
                      state.updateSettings(settings.copyWith(liquidGlass: v)),
                  showDivider: true,
                ),
                GlassSliderRow(
                  title: '饱和度',
                  value: settings.saturation,
                  min: 0, max: 2,
                  label: (v) => v.toStringAsFixed(1),
                  onChanged: (v) =>
                      state.updateSettings(settings.copyWith(saturation: v)),
                  showDivider: true,
                ),
                GlassSliderRow(
                  title: '折射',
                  value: settings.refraction,
                  min: 0, max: 1,
                  label: (v) => (v * 100).round().toString(),
                  onChanged: (v) =>
                      state.updateSettings(settings.copyWith(refraction: v)),
                  showDivider: true,
                ),
                GlassSliderRow(
                  title: '色散',
                  value: settings.dispersion,
                  min: 0, max: 1,
                  label: (v) => (v * 100).round().toString(),
                  onChanged: (v) =>
                      state.updateSettings(settings.copyWith(dispersion: v)),
                  showDivider: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ---- 背景图片 ----
          _SectionTitle('背景图片'),
          const SizedBox(height: 10),
          LiquidGlass(
            radius: BorderRadius.circular(18),
            tintAlphaOverride: 0.18,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Row(
              children: [
                // 缩略图
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(12),
                    image: settings.wallpaperPath != null &&
                            File(settings.wallpaperPath!).existsSync()
                        ? DecorationImage(
                            image: FileImage(File(settings.wallpaperPath!)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: settings.wallpaperPath == null
                      ? Icon(Icons.image_rounded,
                          color: Colors.white.withValues(alpha: 0.6))
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        settings.wallpaperPath == null
                            ? '使用内置流光渐变'
                            : '已导入壁纸',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text('选择手机相册中的图片作为背景',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 11)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _pickWallpaper(context),
                  child: Text('选择图片',
                      style: TextStyle(
                          color: theme, fontWeight: FontWeight.w800)),
                ),
                if (settings.wallpaperPath != null)
                  IconButton(
                    onPressed: () => state.updateSettings(
                        settings.copyWith(clearWallpaper: true)),
                    icon: Icon(Icons.restart_alt_rounded,
                        color: Colors.white.withValues(alpha: 0.7), size: 20),
                    tooltip: '恢复默认',
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text('所有设置即时生效并保存在本地',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45), fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickWallpaper(BuildContext context) async {
    final state = context.read<AppState>();
    final f = await FilePicker.pickFile(type: FileType.image);
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
    if (bytes == null) return;
    try {
      final path = await state.importWallpaper(bytes, f.name);
      await state.updateSettings(
          state.settings.copyWith(wallpaperPath: path));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('壁纸已导入'), duration: Duration(seconds: 1)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('导入失败：$e')));
      }
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(title,
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
              fontWeight: FontWeight.w800)),
    );
  }
}
