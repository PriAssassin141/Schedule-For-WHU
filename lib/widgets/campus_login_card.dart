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
      for (final p in [Permission.locationWhenInUse, Permission.nearbyWifiDevices]) {
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

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final settings = state.settings;
    final theme = themeColorOf(settings);
    final service = CampusService.fromCode(settings.campusService);
    final history = state.campusUserHistory;

    return LiquidGlass(
      radius: BorderRadius.circular(18),
      tintAlphaOverride: 0.16,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- 标题 + 自动登录开关 ----
          Row(
            children: [
              Icon(Icons.wifi_rounded, size: 18, color: theme),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('校园网自动登录',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700)),
              ),
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
                  value: settings.campusAutoLogin,
                  onChanged: (v) async {
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
                  },
                ),
              ),
            ],
          ),
          // ---- 自助服务系统 + 帮助 ----
          Row(
            children: [
              GestureDetector(
                onTap: () => openExternalLink(context, CampusNet.selfServiceUrl),
                child: Text('用户自助服务系统（下线终端 / 查看用量）',
                    style: TextStyle(
                        color: theme,
                        fontSize: 11.5,
                        decoration: TextDecoration.underline,
                        decorationColor: theme)),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _showHelp(context),
                child: Icon(Icons.help_outline_rounded,
                    size: 17, color: Colors.white.withValues(alpha: 0.6)),
              ),
            ],
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
                PopupMenuButton<String>(
                  tooltip: '历史账号',
                  color: const Color(0xFF14302E),
                  onSelected: (u) {
                    setState(() => _userCtl.text = u);
                  },
                  itemBuilder: (_) => [
                    for (final u in history)
                      PopupMenuItem(
                        value: u,
                        child: Text(u,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13)),
                      ),
                  ],
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
              PopupMenuButton<CampusService>(
                tooltip: '选择运营商',
                color: const Color(0xFF14302E),
                onSelected: (s) => state.saveCampusAccount(service: s),
                itemBuilder: (_) => [
                  for (final s in CampusService.values)
                    PopupMenuItem(
                      value: s,
                      child: Text(s.label,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13)),
                    ),
                ],
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
        ],
      ),
    );
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

  void _showHelp(BuildContext context) {
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
                    '打开或回到本应用就会自动完成认证；\n\n'
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
}
