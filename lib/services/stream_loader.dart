import 'dart:convert';

import 'package:http/http.dart' as http;

/// 网络请求工具：拉取直播源、EPG 等文本内容。
class StreamLoader {
  const StreamLoader._();

  static const int _timeoutSeconds = 25;

  /// 获取远程文本内容（自动处理编码）。
  static Future<String> fetchText(String url) async {
    final client = http.Client();
    try {
      final resp = await client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: _timeoutSeconds));
      if (resp.statusCode != 200) {
        throw Exception('请求失败 (HTTP ${resp.statusCode})');
      }
      return utf8.decode(resp.bodyBytes, allowMalformed: true);
    } finally {
      client.close();
    }
  }
}
