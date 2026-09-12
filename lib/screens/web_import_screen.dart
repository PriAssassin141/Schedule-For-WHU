import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:class_manager/screens/import_preview_screen.dart';
import 'package:class_manager/services/schedule_importer.dart';
import 'package:class_manager/state/app_state.dart';
import 'package:class_manager/theme/palette.dart';
import 'package:class_manager/utils/links.dart';
import 'package:class_manager/widgets/app_background.dart';
import 'package:class_manager/widgets/glass.dart';

/// 网页导入课表：在内置浏览器里登录教务 / 研究生系统，
/// 打开课表页后一键提取表格并导入（无需手动导出 doc）。
class WebImportScreen extends StatefulWidget {
  const WebImportScreen({super.key});

  /// 研究生综合服务平台（默认入口）
  static const String graduateUrl =
      'https://ewyjs.whu.edu.cn/gsapp/sys/yjsemaphome/portal/index.do';

  /// 本科教务课表查询
  static const String undergraduateUrl =
      'https://jwgl.whu.edu.cn/kbcx/xskbcx_cxXskbcxIndex.html';

  /// 学校 VPN 门户（校外访问校内系统）
  static const String vpnUrl = 'https://vpn.whu.edu.cn';

  @override
  State<WebImportScreen> createState() => _WebImportScreenState();
}

class _WebImportScreenState extends State<WebImportScreen> {
  WebViewController? _controller;
  String _url = WebImportScreen.graduateUrl;
  bool _loading = true;
  double _progress = 0;
  bool _extracting = false;
  bool _autoFilled = false;
  bool _loadFailed = false;
  String _failDetail = '';

  bool get _supported => Platform.isAndroid || Platform.isIOS;

  @override
  void initState() {
    super.initState();
    if (!_supported) return;
    final saved = context.read<AppState>().settings.webImportUrl;
    _url = saved.isNotEmpty ? saved : WebImportScreen.graduateUrl;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) => setState(() => _progress = p / 100),
        onPageStarted: (_) => setState(() {
          _loading = true;
          _loadFailed = false;
        }),
        onPageFinished: (url) async {
          setState(() {
            _loading = false;
            _url = url;
            _loadFailed = false;
          });
          await _tryAutoFillCas(url);
        },
        onWebResourceError: (err) {
          // 主文档加载失败（多为校内域名校外无法解析）
          if (err.isForMainFrame == false) return;
          setState(() {
            _loading = false;
            _loadFailed = true;
            _failDetail = err.description;
          });
        },
      ))
      ..loadRequest(Uri.parse(_url));
  }

  /// CAS 统一身份认证页：自动填充账号密码并提交。
  Future<void> _tryAutoFillCas(String url) async {
    if (!url.contains('/authserver/login')) return;
    if (_autoFilled) return;
    final state = context.read<AppState>();
    final user = state.settings.portalUser.trim();
    final pwd = state.settings.portalPassword;
    if (user.isEmpty || pwd.isEmpty) {
      _snack('检测到统一身份认证登录页：点右上角「账号」保存学号与密码后即可自动登录');
      return;
    }
    _autoFilled = true;
    final js = _casFillScript(user, pwd);
    final res = await _controller?.runJavaScriptReturningResult(js);
    if (!mounted) return;
    _snack(res.toString().contains('submitted')
        ? '已自动填写统一身份认证账号，正在登录…'
        : '未能自动填写登录表单，请手动登录');
  }

  /// 在 CAS 登录页填表并提交（兼容多种表单结构）。
  static String _casFillScript(String user, String pwd) => '''
(function(){
  var u = document.querySelector('#username') || document.querySelector('input[name=username]') || document.querySelector('input[type=text]');
  var p = document.querySelector('#password') || document.querySelector('input[name=password]') || document.querySelector('input[type=password]');
  var b = document.querySelector('#login_submit') || document.querySelector('button[type=submit]') || document.querySelector('input[type=submit]') || document.querySelector('.login-btn');
  if(!u || !p || !b) return 'no-form';
  u.value = ${jsonEncode(user)};
  p.value = ${jsonEncode(pwd)};
  u.dispatchEvent(new Event('input', {bubbles:true}));
  p.dispatchEvent(new Event('input', {bubbles:true}));
  b.click();
  return 'submitted';
})()
''';

  /// 取当前页面（含同源 iframe）里最大的表格 HTML。
  static const String _extractScript = '''
(function(){
  function biggest(doc){
    var best = null, len = 0;
    try {
      var ts = doc.querySelectorAll('table');
      for (var i = 0; i < ts.length; i++) {
        var h = ts[i].outerHTML || '';
        if (h.length > len) { len = h.length; best = ts[i]; }
      }
    } catch (e) {}
    return best;
  }
  var html = biggest(document) ? biggest(document).outerHTML : '';
  var ifr = document.querySelectorAll('iframe');
  for (var j = 0; j < ifr.length; j++) {
    try {
      var d = ifr[j].contentDocument;
      if (!d) continue;
      var t = biggest(d);
      var h = t ? t.outerHTML : '';
      if (h.length > html.length) html = h;
    } catch (e) {}
  }
  if (!html) { html = document.body ? document.body.innerHTML : ''; }
  return html;
})()
''';

  Future<void> _extract() async {
    if (_extracting) return;
    setState(() => _extracting = true);
    try {
      final raw = await _controller?.runJavaScriptReturningResult(_extractScript);
      var html = raw?.toString() ?? '';
      // webview_flutter 对字符串结果会做 JSON 编码，需要解回
      if (html.length >= 2 && html.startsWith('"') && html.endsWith('"')) {
        try {
          html = jsonDecode(html) as String;
        } catch (_) {}
      }
      if (html.trim().isEmpty) {
        _snack('未找到表格：请先在网页里打开课表页面，再点「提取课表」');
        return;
      }
      final result = await importScheduleFile(
          'web_import.html', Uint8List.fromList(utf8.encode(html)));
      if (!mounted) return;
      if (result.courses.isEmpty) {
        _snack('未能解析出课程：${result.note.isEmpty ? "请确认当前页面是课表页" : result.note}');
        return;
      }
      // 记住成功提取的页面，下次直接打开
      final state = context.read<AppState>();
      await state.updateSettings(state.settings.copyWith(webImportUrl: _url));
      if (!mounted) return;

      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ImportPreviewScreen(
          courses: result.courses,
          sourceName: '网页导入（${Uri.parse(_url).host}）',
          note: result.note,
        ),
      ));
    } finally {
      if (mounted) setState(() => _extracting = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 3)));
  }

  /// 主文档加载失败提示（校内域名在校外无法解析 / 无网络）。
  Widget _failOverlay(Color theme) {
    return Container(
      color: Colors.black.withValues(alpha: 0.45),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: LiquidGlass(
            radius: BorderRadius.circular(20),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            tintAlphaOverride: 0.38,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.wifi_off_rounded, size: 18, color: theme),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('无法打开该网页',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '研究生综合服务平台（ewyjs.whu.edu.cn）只能在校内网络访问，'
                  '校外会提示域名无法解析。\n\n'
                  '· 连接校园网 ${'WHU-STUDENT-WIFI'} 后重试（推荐）\n'
                  '· 或先登录学校 VPN：vpn.whu.edu.cn\n'
                  '· 本科教务（jwgl.whu.edu.cn）在校外也可直接访问\n'
                  '· 也可以改用「文件导入」：在电脑上导出课表 doc 后传手机导入',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12.5,
                      height: 1.65),
                ),
                if (_failDetail.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(_failDetail,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 10.5)),
                ],
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _overlayButton(
                      label: '打开学校 VPN',
                      theme: theme,
                      onTap: () => openExternalLink(context, WebImportScreen.vpnUrl),
                    ),
                    _overlayButton(
                      label: '改用文件导入',
                      theme: theme,
                      onTap: () => runScheduleImport(context),
                    ),
                    _overlayButton(
                      label: '重试',
                      theme: theme,
                      onTap: () => _controller?.reload(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _overlayButton({
    required String label,
    required Color theme,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 38,
      child: LiquidGlass(
        radius: BorderRadius.circular(11),
        padding: EdgeInsets.zero,
        tintColor: theme,
        tintAlphaOverride: 0.55,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Center(
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }

  /// 保存统一身份认证账号（用于 CAS 登录页自动填充）。
  void _showAccountSheet() {
    final state = context.read<AppState>();
    final userCtl =
        TextEditingController(text: state.settings.portalUser);
    final pwdCtl =
        TextEditingController(text: state.settings.portalPassword);
    final theme = themeColorOf(state.settings);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => LiquidGlass(
        radius: BorderRadius.circular(24),
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 16),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        tintAlphaOverride: 0.34,
        child: Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('统一身份认证账号',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('保存后，登录页会自动填写并提交；账号密码仅保存在本机。',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 11.5)),
              const SizedBox(height: 14),
              _sheetField(userCtl, '学号'),
              const SizedBox(height: 10),
              _sheetField(pwdCtl, '密码', obscure: true),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: LiquidGlass(
                  radius: BorderRadius.circular(13),
                  padding: EdgeInsets.zero,
                  tintColor: theme,
                  tintAlphaOverride: 0.75,
                  onTap: () async {
                    await state.updateSettings(state.settings.copyWith(
                      portalUser: userCtl.text.trim(),
                      portalPassword: pwdCtl.text,
                    ));
                    if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                    if (mounted) _snack('已保存账号，下次登录页会自动填充');
                  },
                  child: const Center(
                    child: Text('保存',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      userCtl.dispose();
      pwdCtl.dispose();
    });
  }

  Widget _sheetField(TextEditingController ctl, String hint,
      {bool obscure = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(11),
      ),
      child: TextField(
        controller: ctl,
        obscureText: obscure,
        style: const TextStyle(color: Colors.white, fontSize: 13.5),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.35), fontSize: 12.5),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = themeColorOf(context.watch<AppState>().settings);

    if (!_supported) {
      // 桌面端无内置浏览器
      return BackgroundedScaffold(
        child: Column(
          children: [
            _header(theme, title: '网页导入课表'),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Text(
                    '网页导入需要在手机上使用（内置浏览器）。\n\n'
                    '在电脑上可以先从研究生综合服务平台导出课表 doc 文件，'
                    '再用「导入课表 → 选择文件」导入。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13.5,
                        height: 1.7),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            _header(theme, title: '网页导入课表', url: _url),
            if (_progress < 1)
              LinearProgressIndicator(
                value: _progress,
                minHeight: 2,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(theme),
              ),
            Expanded(
              child: Stack(
                children: [
                  if (_controller != null)
                    WebViewWidget(controller: _controller!),
                  if (_loading)
                    const Center(
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  // ---- 主文档加载失败（校内域名校外无法解析）----
                  if (_loadFailed)
                    Positioned.fill(child: _failOverlay(theme)),
                ],
              ),
            ),
            // ---- 底部操作条 ----
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Column(
                children: [
                  Text(
                    '登录后请打开「课表」页面（研究生：培养 → 课务管理 → 学期课表查询），'
                    '再点下方按钮提取',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '提示：研究生系统仅校内可访问；本科教务校外也能打开',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.42),
                        fontSize: 10.5),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _miniButton(
                        label: '研究生系统',
                        active: _url.contains('ewyjs'),
                        onTap: () => _controller
                            ?.loadRequest(Uri.parse(WebImportScreen.graduateUrl)),
                      ),
                      const SizedBox(width: 6),
                      _miniButton(
                        label: '本科教务',
                        active: _url.contains('jwgl'),
                        onTap: () => _controller?.loadRequest(
                            Uri.parse(WebImportScreen.undergraduateUrl)),
                      ),
                      const SizedBox(width: 6),
                      _miniButton(
                        label: '学校 VPN',
                        active: false,
                        onTap: () => _controller?.loadRequest(
                            Uri.parse(WebImportScreen.vpnUrl)),
                      ),
                      const Spacer(),
                      SizedBox(
                        height: 40,
                        child: LiquidGlass(
                          radius: BorderRadius.circular(12),
                          padding: EdgeInsets.zero,
                          tintColor: theme,
                          tintAlphaOverride: 0.75,
                          onTap: _extracting ? null : _extract,
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 18),
                            child: Center(
                              child: Text(
                                _extracting ? '提取中…' : '提取课表',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(Color theme, {required String title, String? url}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Row(
        children: [
          GlassIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            size: 34,
            onTap: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
                if (url != null)
                  Text(Uri.parse(url).host,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 10.5)),
              ],
            ),
          ),
          if (_controller != null) ...[
            GlassIconButton(
              icon: Icons.person_outline_rounded,
              size: 34,
              onTap: _showAccountSheet,
            ),
            const SizedBox(width: 8),
            GlassIconButton(
              icon: Icons.refresh_rounded,
              size: 34,
              onTap: () => _controller?.reload(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniButton({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 40,
      child: LiquidGlass(
        radius: BorderRadius.circular(12),
        padding: EdgeInsets.zero,
        tintColor: Colors.white,
        tintAlphaOverride: active ? 0.35 : 0.14,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Center(
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}
