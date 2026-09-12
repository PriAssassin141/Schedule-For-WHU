import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'package:class_manager/services/campus_net.dart';
import 'package:class_manager/state/app_state.dart';
import 'package:class_manager/theme/palette.dart';
import 'package:class_manager/utils/links.dart';
import 'package:class_manager/widgets/glass.dart';

/// 校园网自动登录卡片（对应「我的」页）。
///
/// 逻辑：连接 WHU-STUDENT-WiFi 后自动用保存的账号登录校园网（锐捷 ePortal）。
/// 关闭「自动登录」开关后，卡片折叠为仅剩标题一行。
class CampusLoginCard extends StatefulWidget {
  const CampusLoginCard({super.key});

  @override
  State<CampusLoginCard> createState() => _CampusLoginCardState();
}

class _CampusLoginCardState extends State<CampusLoginCard> {
  late final TextEditingController _userCtl;
  late final TextEditingController _pwdCtl;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>().settings;
    _userCtl = TextEditingController(text: s.campusUser);
    _pwdCtl = TextEditingController(text: s.campusPassword);
  }

  @override
  void dispose() {
    _userCtl.dispose();
    _pwdCtl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final state = context.read<AppState>();
    if (_userCtl.text.trim().isEmpty || _pwdCtl.text.isEmpty) {
      _toast('请先填写账号与密码');
      return;
    }
    await state.saveCampusAccount(
      user: _userCtl.text.trim(),
      password: _pwdCtl.text,
    );
    final msg = await state.campusLogin();
    if (mounted) _toast(msg);
  }

  Future<void> _logout() async {
    final msg = await context.read<AppState>().campusLogout();
    if (mounted) _toast(msg);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  /// 读取 WiFi 名称需要定位权限（Android 12 及以下）/
  /// 附近的 WiFi 设备权限（Android 13+）。
  Future<bool> _ensureWifiPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      for (final p in [
        Permission.locationWhenInUse,
        Permission.nearbyWifiDevices
      ]) {
        var status = await p.status;
        if (status.isGranted) return true;
        status = await p.request();
        if (status.isGranted) return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _toggleAutoLogin(bool v) async {
    final state = context.read<AppState>();
    await state.saveCampusAccount(autoLogin: v);
    if (!v) return;
    // 自动登录依赖 WiFi 名称判断，先申请权限
    final ok = await _ensureWifiPermission();
    if (!ok) {
      if (mounted) {
        _toast('未授予定位/附近设备权限，无法读取 WiFi 名称，自动登录将不可用');
      }
      return;
    }
    final msg = await state.tryCampusAutoLogin();
    if (msg != null && mounted) _toast(msg);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final settings = state.settings;
    final theme = themeColorOf(settings);
    final service = CampusService.fromCode(settings.campusService);
    final history = state.campusUserHistory;
    final expanded = settings.campusAutoLogin;

    return LiquidGlass(
      radius: BorderRadius.circular(18),
      tintAlphaOverride: 0.16,
      padding: EdgeInsets.fromLTRB(16, 12, 16, expanded ? 14 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- 标题 + 说明 + 自动登录开关 ----
          Row(
            children: [
              Icon(Icons.wifi_rounded, size: 18, color: theme),
              const SizedBox(width: 10),
              const Text('校园网自动登录',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700)),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _showHelp(context),
                child: Icon(Icons.help_outline_rounded,
                    size: 16, color: Colors.white.withValues(alpha: 0.6)),
              ),
              const Spacer(),
              SwitchTheme(
                data: SwitchThemeData(
                  thumbColor:
                      WidgetStateProperty.resolveWith((s) => Colors.white),
                  trackColor: WidgetStateProperty.resolveWith((s) =>
                      s.contains(WidgetState.selected)
                          ? theme
                          : Colors.white.withValues(alpha: 0.18)),
                  trackOutlineColor:
                      const WidgetStatePropertyAll(Colors.transparent),
                ),
                child: Switch(
                  value: expanded,
                  onChanged: _toggleAutoLogin,
                ),
              ),
            ],
          ),
          // ---- 关闭自动登录后折叠为一行 ----
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: expanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _body(context, state, service, history, theme),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  /// 卡片展开时的内容（自助服务系统 / 账号 / 密码 / 登录注销 / 状态）。
  List<Widget> _body(
    BuildContext context,
    AppState state,
    CampusService service,
    List<String> history,
    Color theme,
  ) {
    return [
      const SizedBox(height: 8),
      // 用户自助服务系统
      GestureDetector(
        onTap: () => openExternalLink(context, CampusNet.selfServiceUrl),
        child: Text('用户自助服务系统（下线终端 / 查看用量）',
            style: TextStyle(
                color: theme,
                fontSize: 11.5,
                decoration: TextDecoration.underline,
                decorationColor: theme)),
      ),
      const SizedBox(height: 12),
      // ---- 账号 ----
      Row(
        children: [
          Expanded(
            child: _field(
              controller: _userCtl,
              hint: '学号（13 位）',
              icon: Icons.person_outline_rounded,
              theme: theme,
            ),
          ),
          if (history.isNotEmpty) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => _showHistorySheet(context, state, history, theme),
              child: Icon(Icons.arrow_drop_down_rounded,
                  color: Colors.white.withValues(alpha: 0.7)),
            ),
          ],
        ],
      ),
      const SizedBox(height: 8),
      // ---- 密码 ----
      _field(
        controller: _pwdCtl,
        hint: '校园网密码',
        icon: Icons.lock_outline_rounded,
        theme: theme,
        obscure: _obscure,
        trailing: GestureDetector(
          onTap: () => setState(() => _obscure = !_obscure),
          child: Icon(
              _obscure
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 16,
              color: Colors.white.withValues(alpha: 0.55)),
        ),
      ),
      const SizedBox(height: 12),
      // ---- 运营商 + 登录 / 注销 ----
      Row(
        children: [
          GestureDetector(
            onTap: () => _showServiceSheet(context, state, service, theme),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(service.label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600)),
                  Icon(Icons.arrow_drop_down_rounded,
                      size: 18, color: Colors.white.withValues(alpha: 0.7)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _button(
              label: state.campusBusy ? '请稍候…' : '登录',
              color: theme,
              alpha: 0.75,
              onTap: state.campusBusy ? null : _login,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _button(
              label: '注销',
              color: Colors.white,
              alpha: 0.14,
              onTap: state.campusBusy ? null : _logout,
            ),
          ),
        ],
      ),
      // ---- 状态 ----
      const SizedBox(height: 10),
      Row(
        children: [
          Icon(
              state.campusBusy
                  ? Icons.sync_rounded
                  : Icons.info_outline_rounded,
              size: 13,
              color: Colors.white.withValues(alpha: 0.55)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              state.campusStatus.isEmpty
                  ? '连接 WHU-STUDENT-WiFi 后自动登录；密码仅保存在本机'
                  : state.campusStatus,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 11,
                  height: 1.35),
            ),
          ),
        ],
      ),
    ];
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color theme,
    bool obscure = false,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.withValues(alpha: 0.9)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              style: const TextStyle(color: Colors.white, fontSize: 13.5),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35), fontSize: 12.5),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  Widget _button({
    required String label,
    required Color color,
    required double alpha,
    VoidCallback? onTap,
  }) {
    return SizedBox(
      height: 38,
      child: LiquidGlass(
        radius: BorderRadius.circular(11),
        padding: EdgeInsets.zero,
        tintColor: color,
        tintAlphaOverride: alpha,
        onTap: onTap,
        child: Center(
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }

  void _showHelp(BuildContext context) {    showModalBottomSheet(
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
              const Text('校园网自动登录说明',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    '1. 先在手机「设置 → WLAN」里连接校园无线网 WHU-STUDENT-WiFi；\n\n'
                    '2. 在本卡片填写学号与校园网密码，选择运营商（一般为「校园网」），点击「登录」；\n\n'
                    '3. 打开上方「自动登录」开关后，之后只要连上 WHU-STUDENT-WiFi，'
                    '打开或回到本应用就会自动完成认证；关闭开关则卡片折叠为一行；\n\n'
                    '4. 上网设备数超限时，可点「用户自助服务系统」下线其他终端；\n\n'
                    '5. 密码只保存在本机数据库，不会上传到任何服务器；'
                    '校园网本身不支持时（例如只有流量），自动登录会自动跳过。',
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

  // ---------- 玻璃弹层：运营商 / 历史账号 ----------

  void _showServiceSheet(
      BuildContext context, AppState state, CampusService current, Color theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _optionSheet(
        title: '选择运营商',
        children: [
          for (final s in CampusService.values)
            _optionRow(
              label: s.label,
              subtitle: switch (s) {
                CampusService.cernet => '校园网（CERNET），一般选这个',
                CampusService.telecom => '中国电信',
                CampusService.unicom => '中国联通',
                CampusService.mobile => '中国移动',
              },
              selected: s == current,
              theme: theme,
              onTap: () {
                Navigator.of(sheetCtx).pop();
                state.saveCampusAccount(service: s);
              },
            ),
        ],
      ),
    );
  }

  void _showHistorySheet(BuildContext context, AppState state,
      List<String> history, Color theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _optionSheet(
        title: '历史账号',
        children: [
          for (final u in history)
            _optionRow(
              label: u,
              selected: u == _userCtl.text.trim(),
              theme: theme,
              onTap: () {
                setState(() => _userCtl.text = u);
                Navigator.of(sheetCtx).pop();
              },
              onDelete: () async {
                Navigator.of(sheetCtx).pop();
                final list = [...history]..remove(u);
                await state.updateSettings(state.settings
                    .copyWith(campusUserHistory: jsonEncode(list)));
              },
            ),
        ],
      ),
    );
  }

  /// 统一风格的玻璃弹层外壳
  Widget _optionSheet({
    required String title,
    required List<Widget> children,
  }) {
    return LiquidGlass(
      radius: BorderRadius.circular(24),
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 16),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      tintAlphaOverride: 0.34,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _optionRow({
    required String label,
    String? subtitle,
    required bool selected,
    required Color theme,
    required VoidCallback onTap,
    VoidCallback? onDelete,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: LiquidGlass(
        radius: BorderRadius.circular(13),
        tintAlphaOverride: selected ? 0.30 : 0.12,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  if (subtitle != null)
                    Text(subtitle,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 11)),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_rounded, size: 18, color: theme),
            if (onDelete != null)
              GestureDetector(
                onTap: onDelete,
                child: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Icon(Icons.close_rounded,
                      size: 16, color: Colors.white.withValues(alpha: 0.5)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
