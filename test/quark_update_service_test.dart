import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:class_manager/services/quark_update_service.dart';

class _Transport implements UpdateTransport {
  final FutureOr<Object> Function(Uri, Map<String, dynamic>?) handler;
  final List<Uri> requests = [];
  bool closed = false;
  _Transport(this.handler);
  @override
  Future<String> request(
    Uri uri, {
    Map<String, dynamic>? body,
    int maxBytes = 1024 * 1024,
  }) async {
    requests.add(uri);
    final result = await handler(uri, body);
    return result is String ? result : jsonEncode(result);
  }

  @override
  void close() => closed = true;
}

Map<String, Object?> _ok(Object data, {int? total}) => {
  'code': 0,
  'data': data,
  if (total != null) 'metadata': {'_total': total},
};
Map<String, Object?> _jsonFile(String fid) => {
  'fid': fid,
  'file_name': '$fid.json',
  'dir': false,
  'size': 262,
  'share_fid_token': 'file-token-$fid',
};
Map<String, Object?> _manifest(String version, int time) => {
  'latest-version': version,
  'update-time': time,
  'describe': '更新说明',
};

void main() {
  test('匿名扫描嵌套目录，使用同会话令牌读取JSON，多份日志按版本及时间选新', () async {
    final transport = _Transport((uri, body) {
      if (uri.path.endsWith('/token')) {
        expect(body, {'pwd_id': 'b57d9dfe897a', 'passcode': ''});
        return _ok({'stoken': 'session-token'});
      }
      if (uri.path.endsWith('/detail')) {
        expect(uri.queryParameters['stoken'], 'session-token');
        final folder = uri.queryParameters['pdir_fid'];
        return _ok({
          'list': folder == '0'
              ? [
                  {'fid': 'wrapped', 'dir': true, 'file_name': '表里珞珈'},
                ]
              : [_jsonFile('old'), _jsonFile('new'), _jsonFile('revision')],
        });
      }
      if (uri.path.endsWith('/rich_text/preview')) {
        final fid = uri.queryParameters['fid'];
        expect(uri.queryParameters['fid_token'], 'file-token-$fid');
        return _ok({'download_url': 'https://test.drive.quark.cn/$fid'});
      }
      return switch (uri.path) {
        '/old' => _manifest('v1.0.3', 202701010000),
        '/new' => _manifest('v1.0.4', 202610170013),
        _ => _manifest('v1.0.4', 202610170014),
      };
    });
    final result = await QuarkUpdateService(transport: transport).fetchLatest();
    expect(result.version.label, '1.0.4');
    expect(result.updatedAt.minute, 14);
    expect(transport.closed, isTrue);
    expect(
      transport.requests.any((uri) => uri.path.contains('/save')),
      isFalse,
    );
  });

  test('文件列表分页后仍能找到第二页的日志，忽略无关JSON', () async {
    final transport = _Transport((uri, body) {
      if (uri.path.endsWith('/token')) return _ok({'stoken': 't'});
      if (uri.path.endsWith('/detail')) {
        return _ok({
          'list': uri.queryParameters['_page'] == '1'
              ? List.generate(100, (i) => {'fid': '$i', 'file_name': '$i.apk'})
              : [_jsonFile('other'), _jsonFile('release')],
        }, total: 102);
      }
      if (uri.path.endsWith('/preview')) {
        return _ok({
          'download_url':
              'https://test.drive.quark.cn/${uri.queryParameters['fid']}',
        });
      }
      return uri.path == '/other'
          ? {'unrelated': true}
          : _manifest('v1.0.5', 202610180001);
    });
    final result = await QuarkUpdateService(transport: transport).fetchLatest();
    expect(result.version.label, '1.0.5');
    expect(
      transport.requests.where((u) => u.path.endsWith('/detail')).length,
      2,
    );
  });

  test('没有日志或无效日志不能误报无需更新，并关闭连接', () async {
    for (final mode in ['missing', 'invalid', 'too-large']) {
      final transport = _Transport((uri, body) {
        if (uri.path.endsWith('/token')) return _ok({'stoken': 't'});
        if (uri.path.endsWith('/detail')) {
          return _ok({
            'list': mode == 'missing'
                ? []
                : [
                    {
                      ..._jsonFile('release'),
                      if (mode == 'too-large') 'size': 100000,
                    },
                  ],
          });
        }
        if (uri.path.endsWith('/preview')) {
          return _ok({'download_url': 'https://test.drive.quark.cn/release'});
        }
        return _manifest('v1.0.4', 202602300000);
      });
      await expectLater(
        QuarkUpdateService(transport: transport).fetchLatest(),
        throwsA(isA<UpdateCheckException>()),
      );
      expect(transport.closed, isTrue);
    }
  });

  test('网盘验证拦截、离线和超时均返回可显示的失败状态', () async {
    for (final problem in ['blocked', 'offline', 'timeout']) {
      final transport = _Transport((uri, body) {
        if (problem == 'offline') throw const SocketException('offline');
        if (problem == 'timeout') throw TimeoutException('timeout');
        return {'code': 41020, 'status': 403};
      });
      await expectLater(
        QuarkUpdateService(transport: transport).fetchLatest(),
        throwsA(isA<UpdateCheckException>()),
      );
      expect(transport.closed, isTrue);
    }
  });

  test('日志读取地址只能使用夸克HTTPS域名，不跟随任意地址', () async {
    final transport = QuarkUpdateTransport();
    try {
      for (final url in [
        'https://example.com/log.json',
        'http://drive.quark.cn/log.json',
        'https://drive.quark.cn.evil.test/log.json',
        'https://user:pass@drive.quark.cn/log.json',
        'https://drive.quark.cn:8080/log.json',
      ]) {
        await expectLater(
          transport.request(Uri.parse(url)),
          throwsA(isA<UpdateCheckException>()),
        );
      }
    } finally {
      transport.close();
    }
  });
}
