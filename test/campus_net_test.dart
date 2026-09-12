import 'package:flutter_test/flutter_test.dart';

import 'package:class_manager/services/campus_net.dart';

/// 校园网（武大锐捷 ePortal）认证逻辑的纯函数测试。
void main() {
  group('门户 queryString 提取', () {
    test('从重定向地址取 ? 之后的部分', () {
      const url =
          'http://172.19.1.9:8080/eportal/index.jsp?wlanuserip=10.1.2.3&nasip=172.19.1.9&t=wireless-v2';
      expect(
        CampusNet.queryStringFromPortalUrl(url),
        'wlanuserip=10.1.2.3&nasip=172.19.1.9&t=wireless-v2',
      );
    });

    test('去掉 # 片段；无 ? 时返回 null', () {
      expect(CampusNet.queryStringFromPortalUrl('http://a/b?x=1#frag'), 'x=1');
      expect(CampusNet.queryStringFromPortalUrl('http://a/b'), isNull);
      expect(CampusNet.queryStringFromPortalUrl('http://a/b?'), isNull);
    });

    test('从 JS 跳转页面中提取门户地址', () {
      const html = "<script>top.location.href='http://172.19.1.9:8080/eportal/index.jsp?wlanuserip=1.2.3.4&nasip=5.6.7.8';</script>";
      final portal = CampusNet.portalUrlFromHtml(html);
      expect(portal, isNotNull);
      expect(CampusNet.queryStringFromPortalUrl(portal!),
          'wlanuserip=1.2.3.4&nasip=5.6.7.8');
    });
  });

  group('登录请求组装', () {
    test('queryString 双重转义（& → %2526，= → %253D）', () {
      expect(CampusNet.escapeQueryString('a=1&b=2'), 'a%253D1%2526b%253D2');
    });

    test('请求体包含全部必需字段', () {
      final body = CampusNet.buildLoginBody(
        username: '2026282210182',
        password: 'p@ss word',
        service: CampusService.cernet,
        queryString: 'wlanuserip=1.2.3.4&nasip=5.6.7.8',
      );
      expect(body, contains('userId=2026282210182'));
      expect(body, contains('service=Internet'));
      expect(body, contains('queryString=wlanuserip%253D1.2.3.4%2526nasip%253D5.6.7.8'));
      expect(body, contains('operatorPwd=&operatorUserId=&validcode='));
      expect(body, contains('passwordEncrypt=false'));
      // 密码中的空格需被编码
      expect(body, contains('password=p%40ss+word'));
    });

    test('运营商 service 取值', () {
      expect(CampusService.cernet.code, 'Internet');
      expect(CampusService.telecom.code, 'dianxin');
      expect(CampusService.unicom.code, 'liantong');
      expect(CampusService.mobile.code, 'yidong');
      expect(CampusService.fromCode('dianxin'), CampusService.telecom);
      expect(CampusService.fromCode('unknown'), CampusService.cernet);
      expect(CampusService.fromCode(null), CampusService.cernet);
    });
  });

  group('认证结果解析', () {
    test('成功（含 userIndex）', () {
      final res = CampusNet.parseLoginResponse(
          '{"result":"success","message":"","userIndex":"abc123","forwordurl":null}');
      expect(res.success, isTrue);
      expect(res.userIndex, 'abc123');
      expect(res.message, '校园网登录成功');
    });

    test('JSONP 包裹同样可解析', () {
      final res = CampusNet.parseLoginResponse(
          '({"result":"success","message":"","userIndex":"x"})');
      expect(res.success, isTrue);
    });

    test('失败：base64 错误码翻译为中文', () {
      final res = CampusNet.parseLoginResponse(
          '{"result":"fail","message":"dXNlcmlkIGVycm9yMg=="}');
      expect(res.success, isFalse);
      expect(res.message, '账号或密码错误');
    });

    test('失败：中文提示原样返回', () {
      final res = CampusNet.parseLoginResponse(
          '{"result":"fail","message":"您的账号余额不足"}');
      expect(res.success, isFalse);
      expect(res.message, contains('余额'));
    });

    test('非法响应不会抛异常', () {
      final res = CampusNet.parseLoginResponse('<html>502 Bad Gateway</html>');
      expect(res.success, isFalse);
      expect(res.message, isNotEmpty);
    });
  });

  group('校园 WiFi 判断', () {
    test('武大校园网 SSID 命中', () {
      expect(CampusNet.isWhuWifi('WHU-STUDENT-WiFi'), isTrue);
      expect(CampusNet.isWhuWifi('"WHU-STUDENT-WiFi"'), isTrue);
      expect(CampusNet.isWhuWifi('WHU-WLAN'), isTrue);
      expect(CampusNet.isWhuWifi('whu-student'), isTrue);
    });

    test('其它 WiFi / 无 WiFi 不命中', () {
      expect(CampusNet.isWhuWifi('CMCC-EDU'), isFalse);
      expect(CampusNet.isWhuWifi('TP-LINK_5G'), isFalse);
      expect(CampusNet.isWhuWifi(''), isFalse);
      expect(CampusNet.isWhuWifi(null), isFalse);
    });
  });

  group('接口地址', () {
    test('与武大门户一致', () {
      expect(CampusNet.portalBase, 'http://172.19.1.9:8080');
      expect(CampusNet.loginUrl,
          'http://172.19.1.9:8080/eportal/InterFace.do?method=login');
      expect(CampusNet.logoutUrl,
          'http://172.19.1.9:8080/eportal/InterFace.do?method=logout');
      expect(CampusNet.selfServiceUrl,
          'http://user-serv.whu.edu.cn:8080/selfservice/');
    });
  });
}
