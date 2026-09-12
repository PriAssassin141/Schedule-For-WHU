import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:class_manager/screens/personalization_screen.dart';
import 'package:class_manager/screens/web_import_screen.dart';
import 'package:class_manager/state/app_state.dart';
import 'package:class_manager/theme/palette.dart';
import 'package:class_manager/utils/greeting.dart';
import 'package:class_manager/utils/links.dart';
import 'package:class_manager/widgets/campus_login_card.dart';
import 'package:class_manager/widgets/glass.dart';

/// 我的页：个性化入口 + 「联系作者 / 关于软件 / 检查更新」分组卡片。
class MineScreen extends StatelessWidget {
  const MineScreen({super.key});

  static const String _qq = '1224850644';
  static const String _wechat = 'Assassin141_CUMT';
  static const String _email = '1224850644@qq.com';
  static const String _updateUrl = 'https://pan.quark.cn/s/b2adc2472b96';

  /// 当前软件版本号
  static const String _version = '1.1.0';
  static const String _repoUrl =
      'https://github.com/PriAssassin141/Schedule-For-WHU';
  static const String _aboutText =
      '大家好，我是国家网络安全学院2026级研究生闫梓萱。由于智慧珞珈的研究生课表非常鸡肋，'
      '为此我 Vibe 了这款课表软件，以方便大家的使用。大家可以在电脑端的研究生综合服务平台导出课表后，'
      '手动将课表的 doc 文件导入本软件中。\n\n'
      '本软件在设计时借鉴了我本科期间使用的课表软件“矿小助”。“矿小助”是由中国矿业大学翔工作室'
      '开发的一款十分优秀的课表软件，集成了校园网自动登录、成绩查询、班车时间、电费查询等生活常用功能，'
      '我不敢与之相提并论，只敢拾人牙慧，拙劣地模仿一下，希望大家喜欢！';
  static const String _privacyText =
      '希望您仔细阅读此《表里珞珈隐私政策》（以下简称“本政策”），详细了解本 APP 对隐私信息的使用策略，'
      '以帮助您更好地了解本 APP，并决定您的使用方式。\n\n'
      '本 APP 为纯本地软件，不对外提供任何形式的网络服务。用户的所有数据不会被以任何形式收集或上传，'
      '只会被保存在手机本地。本 APP 亦没有注册功能，所有数据均由用户自行输入软件，'
      '且仅仅保存在本地而不会被上传。\n\n'
      '最后更新于 2026 年 9 月 8 日\n'
      '闫梓萱';

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppState>().settings;
    final greeting = greetingFor(DateTime.now());
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
        children: [
          // ---- 按时间问候 ----
          Padding(
            padding: const EdgeInsets.only(left: 2, top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting.withName(settings.userName),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      height: 1.2),
                ),
                const SizedBox(height: 6),
                Text(
                  '✨ ${greeting.reminder}',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          // ---- 校园网自动登录 ----
          const CampusLoginCard(),
          const SizedBox(height: 12),
          // ---- 个性化 ----
          _SettingTile(
            icon: Icons.tune_rounded,
            title: '个性化设置',
            subtitle: '主题颜色 · 液态玻璃 · 背景模糊 · 壁纸',
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PersonalizationScreen())),
          ),
          const SizedBox(height: 12),
          // ---- 网页导入课表（内置浏览器登录教务/研究生系统后一键提取）----
          _SettingTile(
            icon: Icons.travel_explore_rounded,
            title: '从教务系统导入课表',
            subtitle: '内置浏览器登录统一身份认证，一键提取课表',
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WebImportScreen())),
          ),
          const SizedBox(height: 12),
          // ---- 获取源码 ----
          _SettingTile(
            icon: Icons.code_rounded,
            title: '获取源码',
            subtitle: 'GitHub · PriAssassin141/Schedule-For-WHU',
            onTap: () => _showSource(context),
          ),
          const SizedBox(height: 12),
          // ---- 联系作者 / 关于软件 / 检查更新（同一张大卡片，细线分隔）----
          LiquidGlass(
            radius: BorderRadius.circular(18),
            tintAlphaOverride: 0.16,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                _MenuRow(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: '联系作者',
                  onTap: () => _showContact(context),
                ),
                _MenuRow(
                  icon: Icons.info_outline_rounded,
                  title: '关于软件',
                  showDivider: true,
                  onTap: () => _showAbout(context),
                ),
                _MenuRow(
                  icon: Icons.system_update_alt_rounded,
                  title: '检查更新',
                  showDivider: true,
                  onTap: () => _checkUpdate(context),
                ),
                _MenuRow(
                  icon: Icons.privacy_tip_outlined,
                  title: '隐私政策',
                  showDivider: true,
                  onTap: () => _showPrivacy(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- 获取源码 ----------
  void _showSource(BuildContext context) {
    const url = _repoUrl;
    final theme = themeColorOf(context.read<AppState>().settings);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => LiquidGlass(
        radius: BorderRadius.circular(24),
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 16),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        tintAlphaOverride: 0.34,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.code_rounded, size: 19, color: theme),
                const SizedBox(width: 8),
                const Text('获取源码',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 6),
            Text('本项目已在 GitHub 开源，欢迎 Star 与反馈',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 11.5)),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: SelectableText(url,
                  style: TextStyle(color: theme, fontSize: 12.5, height: 1.4)),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: LiquidGlass(
                      radius: BorderRadius.circular(14),
                      padding: EdgeInsets.zero,
                      tintColor: theme,
                      tintAlphaOverride: 0.75,
                      onTap: () {
                        Navigator.of(sheetCtx).pop();
                        openExternalLink(context, url);
                      },
                      child: const Center(
                        child: Text('打开链接',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: LiquidGlass(
                      radius: BorderRadius.circular(14),
                      padding: EdgeInsets.zero,
                      tintAlphaOverride: 0.18,
                      onTap: () async {
                        await Clipboard.setData(
                            const ClipboardData(text: url));
                        if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('链接已复制'),
                                  duration: Duration(seconds: 1)));
                        }
                      },
                      child: const Center(
                        child: Text('复制链接',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------- 联系作者 ----------
  void _showContact(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => LiquidGlass(
        radius: BorderRadius.circular(24),
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 16),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        tintAlphaOverride: 0.34,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('联系作者',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('点击任意一行即可复制',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
            const SizedBox(height: 14),
            _ContactRow(
              icon: Icons.chat_rounded,
              label: 'QQ',
              value: _qq,
            ),
            const SizedBox(height: 10),
            _ContactRow(
              icon: Icons.message_rounded,
              label: '微信',
              value: _wechat,
            ),
            const SizedBox(height: 10),
            _ContactRow(
              icon: Icons.mail_outline_rounded,
              label: '邮箱',
              value: _email,
            ),
          ],
        ),
      ),
    );
  }

  // ---------- 关于软件 ----------
  void _showAbout(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => LiquidGlass(
        radius: BorderRadius.circular(24),
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 16),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        tintAlphaOverride: 0.34,
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetCtx).size.height * 0.62),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('关于软件',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    _aboutText,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 13,
                        height: 1.75),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- 检查更新（先展示当前版本，再由用户决定是否前往下载）----------
  void _checkUpdate(BuildContext context) {
    final theme = themeColorOf(context.read<AppState>().settings);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => LiquidGlass(
        radius: BorderRadius.circular(24),
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 16),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        tintAlphaOverride: 0.34,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.system_update_alt_rounded, size: 18, color: theme),
                const SizedBox(width: 8),
                const Text('检查更新',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text('当前版本',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 12.5)),
                  const Spacer(),
                  Text('v$_version',
                      style: TextStyle(
                          color: theme,
                          fontSize: 15,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text('如需获取最新版本安装包，请点击下方按钮前往下载链接。',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 11.5,
                    height: 1.5)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: LiquidGlass(
                      radius: BorderRadius.circular(14),
                      padding: EdgeInsets.zero,
                      tintColor: theme,
                      tintAlphaOverride: 0.75,
                      onTap: () {
                        Navigator.of(sheetCtx).pop();
                        openExternalLink(context, _updateUrl);
                      },
                      child: const Center(
                        child: Text('跳转到下载链接',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: LiquidGlass(
                      radius: BorderRadius.circular(14),
                      padding: EdgeInsets.zero,
                      tintAlphaOverride: 0.16,
                      onTap: () => Navigator.of(sheetCtx).pop(),
                      child: const Center(
                        child: Text('取消',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------- 隐私政策 ----------
  void _showPrivacy(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => LiquidGlass(
        radius: BorderRadius.circular(24),
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 16),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        tintAlphaOverride: 0.34,
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetCtx).size.height * 0.62),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.privacy_tip_outlined,
                      size: 18,
                      color: themeColorOf(context.read<AppState>().settings)),
                  const SizedBox(width: 8),
                  const Text('隐私政策',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    _privacyText,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 13,
                        height: 1.8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 大卡片内的一行（细线分隔，右侧箭头）。
class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool showDivider;
  final VoidCallback onTap;

  const _MenuRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.showDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: showDivider
          ? BoxDecoration(
              border: Border(
                top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08), width: 0.6),
              ),
            )
          : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.85)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600)),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: Colors.white.withValues(alpha: 0.45)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 联系方式行（点击复制）。
class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = themeColorOf(context.watch<AppState>().settings);
    return LiquidGlass(
      radius: BorderRadius.circular(14),
      tintAlphaOverride: 0.14,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: value));
        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('已复制$label：$value'),
              duration: const Duration(seconds: 2)));
        }
      },
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 11)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Icon(Icons.copy_rounded,
              size: 16, color: Colors.white.withValues(alpha: 0.5)),
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = themeColorOf(context.watch<AppState>().settings);
    return LiquidGlass(
      radius: BorderRadius.circular(18),
      tintAlphaOverride: 0.16,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: theme.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 19, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 11)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.45), size: 20),
        ],
      ),
    );
  }
}
