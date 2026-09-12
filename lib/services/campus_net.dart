import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';

/// 校园网运营商（对应锐捷 ePortal 的 service 参数）
enum CampusService {
  /// 校园网（CERNET）
  cernet('Internet', '校园网'),

  /// 中国电信
  telecom('dianxin', '电信'),

  /// 中国联通
  unicom('liantong', '联通'),

  /// 中国移动
  mobile('yidong', '移动');

  const CampusService(this.code, this.label);

  /// ePortal 的 service 取值
  final String code;

  /// 界面显示名
  final String label;

  static CampusService fromCode(String? code) => CampusService.values
      .firstWhere((e) => e.code == code, orElse: () => CampusService.cernet);
}

/// 登录 / 注销结果
class CampusNetResult {
  final bool success;
  final String message;

  /// 在线会话标识（注销时使用）
  final String? userIndex;

  const CampusNetResult(this.success, this.message, {this.userIndex});

  const CampusNetResult.ok(String message, {String? userIndex})
      : this(true, message, userIndex: userIndex);

  const CampusNetResult.fail(String message)
      : this(false, message, userIndex: null);
}

/// 武汉大学校园网（锐捷 ePortal）自动认证。
///
/// 认证接口：`http://172.19.1.9:8080/eportal/InterFace.do?method=login`
///   - userId / password：统一身份账号（13 位学号）与密码
///   - service：Internet（校园网）/ dianxin / liantong / yidong
///   - queryString：未认证时被门户重定向的 URL 中 `?` 之后的查询串（`&`→`%2526`、`=`→`%253D`）
class CampusNet {
  CampusNet._();

  /// 门户认证服务器
  static const String portalBase = 'http://172.19.1.9:8080';

  /// 登录 / 注销 / 在线信息接口
  static const String loginUrl = '$portalBase/eportal/InterFace.do?method=login';
  static const String logoutUrl =
      '$portalBase/eportal/InterFace.do?method=logout';
  static const String onlineUrl =
      '$portalBase/eportal/InterFace.do?method=getOnlineUserInfo';

  /// 用户自助服务系统（下线终端、查看用量）
  static const String selfServiceUrl =
      'http://user-serv.whu.edu.cn:8080/selfservice/';

  /// 用于探测「是否需要认证」的轻量地址（未认证时会被门户劫持）
  static const String probeUrl = 'http://connect.rom.miui.com/generate_204';

  /// 校园 WiFi 名称（连接后才会自动登录）
  static const List<String> whuWifiPrefixes = ['WHU-STUDENT', 'WHU-WLAN', 'WHU'];

  // ---------------- 纯逻辑（可单测） ----------------

  /// 从门户重定向地址中取出 queryString（`?` 之后、`#` 之前的部分）。
  static String? queryStringFromPortalUrl(String url) {
    final i = url.indexOf('?');
    if (i < 0) return null;
    var q = url.substring(i + 1);
    final h = q.indexOf('#');
    if (h >= 0) q = q.substring(0, h);
    return q.isEmpty ? null : q;
  }

  /// 从页面正文（有些门户用 JS 跳转而非 302）里提取门户地址。
  static String? portalUrlFromHtml(String html) {
    final m = RegExp(
      r'''https?://[\d.]+(:\d+)?/eportal/index\.jsp\?[^"'\s<>\\]+''',
    ).firstMatch(html);
    return m?.group(0);
  }

  /// 表单提交用的转义：`&`→`%2526`、`=`→`%253D`（锐捷门户的双重编码约定）。
  static String escapeQueryString(String q) =>
      q.replaceAll('&', '%2526').replaceAll('=', '%253D');

  /// 组装登录请求体（与 curl 版 auto-whu 完全一致）。
  static String buildLoginBody({
    required String username,
    required String password,
    required CampusService service,
    required String queryString,
  }) {
    final u = Uri.encodeQueryComponent(username.trim());
    final p = Uri.encodeQueryComponent(password);
    final qs = escapeQueryString(queryString);
    return 'userId=$u&password=$p&service=${service.code}&queryString=$qs'
        '&operatorPwd=&operatorUserId=&validcode=&passwordEncrypt=false';
  }

  /// 解析认证结果（兼容 JSON 与 JSONP 包裹）。
  static CampusNetResult parseLoginResponse(String body) {
    var text = body.trim();
    if (text.startsWith('(') && text.endsWith(')')) {
      text = text.substring(1, text.length - 1);
    }
    try {
      final map = jsonDecode(text) as Map<String, dynamic>;
      final result = (map['result'] ?? '').toString();
      final message = (map['message'] ?? '').toString();
      final userIndex = map['userIndex']?.toString();
      if (result == 'success') {
        return CampusNetResult.ok('校园网登录成功', userIndex: userIndex);
      }
      return CampusNetResult.fail(humanizeMessage(message));
    } catch (_) {
      return CampusNetResult.fail('认证服务器响应异常，请稍后重试');
    }
  }

  /// 把门户返回的错误码翻译成中文提示。
  static String humanizeMessage(String message) {
    final m = message.trim();
    if (m.isEmpty) return '登录失败，请检查账号与密码';
    const known = {
      'dXNlcmlkIGVycm9yMg==': '账号或密码错误',
      'dXNlcmlkIGVycm9yMQ==': '账号不存在，请核对学号',
      'bGRhcCBhdXRoIGVycm9y': '用户名或密码错误',
      'UmFkOkxpbWl0IFVzZXJzIEVycg==': '在线终端数已达上限，请先在自助服务系统下线其他设备',
      'SSd4dGluZ3Vpc2hlcnM=': '账号已在其他设备登录',
    };
    if (known.containsKey(m)) return known[m]!;
    if (m.contains('已经在线') || m.contains('已在线')) return '该账号已在线，无需重复登录';
    if (m.contains('密码') || m.contains('password')) return '账号或密码错误';
    if (m.contains('余额') || m.contains('欠费')) return '账号余额不足，请先充值';
    return m;
  }

  /// 是否是武大校园 WiFi（自动登录的前提）。
  static bool isWhuWifi(String? ssid) {
    if (ssid == null) return false;
    final s = ssid.replaceAll('"', '').trim().toUpperCase();
    if (s.isEmpty) return false;
    for (final p in whuWifiPrefixes) {
      if (s.startsWith(p)) return true;
    }
    return false;
  }

  // ---------------- 网络操作 ----------------

  /// 当前 WiFi 名称（非 WiFi 或缺少权限时返回 null）。
  static Future<String?> currentSsid() async {
    try {
      final name = await NetworkInfo().getWifiName();
      if (name == null) return null;
      return name.replaceAll('"', '');
    } catch (_) {
      return null;
    }
  }

  /// 探测是否已经联网（无需认证即可访问外网）。
  static Future<bool> isOnline({http.Client? client}) async {
    final c = client ?? http.Client();
    try {
      final req = http.Request('GET', Uri.parse(probeUrl))
        ..followRedirects = false;
      final res = await c.send(req).timeout(const Duration(seconds: 6));
      // 204/200 说明已通；302 说明被门户劫持，需要认证
      return res.statusCode == 204 || res.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      if (client == null) c.close();
    }
  }

  /// 取门户 queryString：未认证时访问外网会被重定向到门户。
  static Future<String?> fetchQueryString({http.Client? client}) async {
    final c = client ?? http.Client();
    try {
      final req = http.Request('GET', Uri.parse(probeUrl))
        ..followRedirects = false;
      final res = await c.send(req).timeout(const Duration(seconds: 8));
      final location = res.headers['location'];
      if (location != null) {
        final q = queryStringFromPortalUrl(location);
        if (q != null) return q;
      }
      // 有些场景返回 200 + 脚本跳转
      final body = await res.stream.bytesToString();
      final portal = portalUrlFromHtml(body);
      if (portal != null) return queryStringFromPortalUrl(portal);
      return null;
    } catch (_) {
      return null;
    } finally {
      if (client == null) c.close();
    }
  }

  /// 登录校园网。
  static Future<CampusNetResult> login({
    required String username,
    required String password,
    required CampusService service,
    http.Client? client,
  }) async {
    if (username.trim().isEmpty || password.isEmpty) {
      return const CampusNetResult.fail('请先填写账号与密码');
    }
    if (await isOnline(client: client)) {
      return const CampusNetResult.ok('您已登录校园网');
    }
    final queryString = await fetchQueryString(client: client);
    if (queryString == null) {
      return const CampusNetResult.fail(
          '未检测到校园网门户，请确认已连接 WHU-STUDENT-WiFi');
    }
    final c = client ?? http.Client();
    try {
      final res = await c
          .post(
            Uri.parse(loginUrl),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: buildLoginBody(
              username: username,
              password: password,
              service: service,
              queryString: queryString,
            ),
          )
          .timeout(const Duration(seconds: 12));
      return parseLoginResponse(res.body);
    } catch (_) {
      return const CampusNetResult.fail('网络错误，登录失败');
    } finally {
      if (client == null) c.close();
    }
  }

  /// 注销当前在线终端。
  static Future<CampusNetResult> logout({http.Client? client}) async {
    final c = client ?? http.Client();
    try {
      final res = await c
          .post(Uri.parse(logoutUrl),
              headers: {'Content-Type': 'application/x-www-form-urlencoded'},
              body: '')
          .timeout(const Duration(seconds: 10));
      final text = res.body.trim();
      if (text.contains('success') || text.contains('注销成功')) {
        return const CampusNetResult.ok('已注销校园网');
      }
      return CampusNetResult.fail(humanizeMessage(text));
    } catch (_) {
      return const CampusNetResult.fail('网络错误，注销失败');
    } finally {
      if (client == null) c.close();
    }
  }

  /// 自动登录：仅当连接的是武大校园 WiFi 且账号已保存时执行。
  static Future<CampusNetResult> autoLogin({
    required String username,
    required String password,
    required CampusService service,
    http.Client? client,
  }) async {
    if (username.trim().isEmpty || password.isEmpty) {
      return const CampusNetResult.fail('未保存校园网账号');
    }
    final ssid = await currentSsid();
    if (ssid == null) {
      return const CampusNetResult.fail(
          '未能读取 WiFi 名称：请确认已连接 WiFi 并授予定位权限');
    }
    if (!isWhuWifi(ssid)) {
      return CampusNetResult.fail('当前 WiFi（$ssid）不是校园网，已跳过自动登录');
    }
    return login(
        username: username,
        password: password,
        service: service,
        client: client);
  }
}
