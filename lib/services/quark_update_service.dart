import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:class_manager/config/release_metadata.dart';
import 'package:class_manager/models/update_manifest.dart';

class UpdateCheckException implements Exception {
  final String message;
  const UpdateCheckException(this.message);
  @override
  String toString() => message;
}

abstract interface class UpdateTransport {
  Future<String> request(
    Uri uri, {
    Map<String, dynamic>? body,
    int maxBytes = 1024 * 1024,
  });
  void close();
}

/// Anonymous, short-lived session. No account cookies or personal data used.
class QuarkUpdateTransport implements UpdateTransport {
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 10);
  final Map<String, Map<String, Cookie>> _cookies = {};

  static bool _allowed(Uri uri) =>
      uri.scheme == 'https' &&
      (uri.host == 'drive.quark.cn' || uri.host.endsWith('.drive.quark.cn')) &&
      uri.userInfo.isEmpty &&
      uri.port == 443;

  @override
  Future<String> request(
    Uri uri, {
    Map<String, dynamic>? body,
    int maxBytes = 1024 * 1024,
  }) => _request(uri, body, maxBytes).timeout(const Duration(seconds: 12));

  Future<String> _request(
    Uri uri,
    Map<String, dynamic>? body,
    int maxBytes,
  ) async {
    for (var redirects = 0; redirects <= 3; redirects++) {
      if (!_allowed(uri)) {
        throw const UpdateCheckException('更新日志的读取地址无效');
      }
      final request = await _client.openUrl(body == null ? 'GET' : 'POST', uri);
      request.followRedirects = false;
      request.headers
        ..set(HttpHeaders.userAgentHeader, 'Mozilla/5.0')
        ..set(HttpHeaders.refererHeader, 'https://pan.quark.cn/')
        ..set('Origin', 'https://pan.quark.cn')
        ..set(HttpHeaders.cacheControlHeader, 'no-cache');
      request.cookies.addAll(_cookies[uri.host]?.values ?? <Cookie>[]);
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      final response = await request.close();
      final jar = _cookies.putIfAbsent(uri.host, () => {});
      for (final cookie in response.cookies.take(32)) {
        jar[cookie.name] = cookie;
      }
      if ([301, 302, 303, 307, 308].contains(response.statusCode)) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        if (location == null || body != null) break;
        final next = uri.resolve(location);
        if (!_allowed(next)) break;
        await response.drain<void>();
        uri = next;
        continue;
      }
      if (response.statusCode != HttpStatus.ok) {
        throw const UpdateCheckException('网盘暂时无法读取，请稍后重试');
      }
      if (response.contentLength > maxBytes) {
        throw const UpdateCheckException('更新日志或文件列表过大');
      }
      final bytes = <int>[];
      await for (final chunk in response) {
        if (bytes.length + chunk.length > maxBytes) {
          throw const UpdateCheckException('更新日志或文件列表过大');
        }
        bytes.addAll(chunk);
      }
      return utf8.decode(bytes);
    }
    throw const UpdateCheckException('更新日志的读取地址跳转异常');
  }

  @override
  void close() => _client.close(force: true);
}

abstract interface class UpdateChecker {
  Future<UpdateManifest> fetchLatest();
  void close();
}

typedef UpdateCheckerFactory = UpdateChecker Function();

class QuarkUpdateService implements UpdateChecker {
  final UpdateTransport _transport;
  QuarkUpdateService({UpdateTransport? transport})
    : _transport = transport ?? QuarkUpdateTransport();

  Uri _uri(String path, [Map<String, String> params = const {}]) => Uri.https(
    'drive.quark.cn',
    '/1/clouddrive/$path',
    {'pr': 'ucpro', 'fr': 'pc', ...params},
  );

  Future<Map<String, dynamic>> _api(
    String path, {
    Map<String, String> params = const {},
    Map<String, dynamic>? body,
  }) async {
    final json = jsonDecode(
      await _transport.request(_uri(path, params), body: body),
    );
    if (json is! Map<String, dynamic> || json['code'] != 0) {
      throw const UpdateCheckException('网盘访问失败，链接可能失效或需要验证');
    }
    return json;
  }

  @override
  Future<UpdateManifest> fetchLatest() async {
    try {
      return await _fetch().timeout(const Duration(seconds: 35));
    } on TimeoutException {
      throw const UpdateCheckException('检查更新超时，请检查网络后重试');
    } on SocketException {
      throw const UpdateCheckException('无法连接网盘，请检查网络后重试');
    } on FormatException {
      throw const UpdateCheckException('更新日志格式错误，请联系作者检查 JSON');
    } on UpdateCheckException {
      rethrow;
    } catch (_) {
      throw const UpdateCheckException('暂时无法检查更新，请稍后重试');
    } finally {
      close();
    }
  }

  Future<UpdateManifest> _fetch() async {
    final shareId = Uri.parse(appUpdateShareUrl).pathSegments.last;
    final tokenResponse = await _api(
      'share/sharepage/token',
      body: {'pwd_id': shareId, 'passcode': ''},
    );
    final token = tokenResponse['data']?['stoken'];
    if (token is! String || token.isEmpty) {
      throw const UpdateCheckException('无法访问更新分享链接');
    }
    final folders = <String>['0'];
    final seenFolders = <String>{'0'};
    final jsonFiles = <Map<String, dynamic>>[];
    var scanned = 0;
    for (var index = 0; index < folders.length; index++) {
      for (var page = 1; ; page++) {
        if (page > 20) {
          throw const UpdateCheckException('分享目录过大，无法完整检查更新');
        }
        final response = await _api(
          'share/sharepage/detail',
          params: {
            'pwd_id': shareId,
            'stoken': token,
            'pdir_fid': folders[index],
            '_page': '$page',
            '_size': '100',
            '_fetch_total': '1',
            '_sort': 'file_type:asc,file_name:asc',
          },
        );
        final list = response['data']?['list'];
        if (list is! List) {
          throw const UpdateCheckException('网盘未返回有效文件列表');
        }
        scanned += list.length;
        if (scanned > 2000) {
          throw const UpdateCheckException('分享文件过多，无法完整检查更新');
        }
        for (final item in list) {
          if (item is! Map<String, dynamic> || item['fid'] is! String) continue;
          final fid = item['fid'] as String;
          if (item['dir'] == true) {
            if (seenFolders.add(fid)) folders.add(fid);
            if (folders.length > 32) {
              throw const UpdateCheckException('分享文件夹过多，无法完整检查更新');
            }
          } else if ((item['file_name'] as String? ?? '')
              .toLowerCase()
              .endsWith('.json')) {
            jsonFiles.add(item);
            if (jsonFiles.length > 16) {
              throw const UpdateCheckException('JSON 文件过多，请精简更新分享目录');
            }
          }
        }
        final total = response['metadata']?['_total'];
        if (list.isEmpty ||
            (total is num ? page * 100 >= total : list.length < 100)) {
          break;
        }
      }
    }
    if (jsonFiles.isEmpty) {
      throw const UpdateCheckException('分享目录中未找到更新日志 JSON');
    }
    UpdateManifest? latest;
    for (final file in jsonFiles) {
      final size = file['size'];
      if (size is num && size > 64 * 1024) {
        throw const UpdateCheckException('更新日志过大，请保持在64KB以内');
      }
      final params = {
        'pwd_id': shareId,
        'stoken': token,
        'fid': file['fid'] as String,
        'fid_token': file['share_fid_token'] as String? ?? '',
      };
      final preview = await _api(
        'share/sharepage/rich_text/preview',
        params: params,
      );
      final address = preview['data']?['download_url'];
      if (address is! String) {
        throw const UpdateCheckException('无法读取更新日志内容');
      }
      final content = await _transport.request(
        Uri.parse(address),
        maxBytes: 64 * 1024,
      );
      // Other JSON files are allowed, but malformed release manifests are not
      // silently ignored: that could incorrectly report an older file as latest.
      final object = jsonDecode(content.replaceFirst(RegExp('^\uFEFF'), ''));
      if (object is! Map ||
          (!object.containsKey('latest-version') &&
              !object.containsKey('update-time'))) {
        continue;
      }
      final manifest = UpdateManifest.parse(content);
      if (latest == null || manifest.compareTo(latest) > 0) latest = manifest;
    }
    if (latest == null) {
      throw const UpdateCheckException('JSON 中未找到有效的版本号与更新时间');
    }
    return latest;
  }

  @override
  void close() => _transport.close();
}
