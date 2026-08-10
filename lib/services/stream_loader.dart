import 'dart:convert';

import 'package:http/http.dart' as http;

/// 网络请求工具：拉取直播源、EPG 等文本内容。
class StreamLoader {
  const StreamLoader._();

  static const int _timeoutSeconds = 15;

  /// 部分 CDN（如 CloudFlare）会拒绝无 UA 的请求，这里固定一个常见 UA。
  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) '
            'Chrome/124.0 Mobile Safari/537.36',
    'Accept': '*/*',
  };

  /// 获取远程文本内容（自动处理编码）。
  static Future<String> fetchText(String url) async {
    final client = http.Client();
    try {
      final resp = await client
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: _timeoutSeconds));
      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}（$url）');
      }
      return utf8.decode(resp.bodyBytes, allowMalformed: true);
    } on Exception catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('连接超时（$url）');
      }
      rethrow;
    } finally {
      client.close();
    }
  }
}
