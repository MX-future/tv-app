/// 直播源（m3u / txt 订阅链接）模型。
class PlaySource {
  const PlaySource({
    required this.id,
    required this.name,
    required this.url,
    this.builtIn = false,
    this.epgUrl,
    this.mirrors = const [],
  });

  /// 唯一标识
  final String id;

  /// 显示名称，如 "fanmingming IPv6"
  final String name;

  /// 订阅链接（m3u 或 txt）
  final String url;

  /// 是否内置源（内置源不可删除）
  final bool builtIn;

  /// EPG 节目单地址（解析自 m3u 头部 x-tvg-url，可为空）
  final String? epgUrl;

  /// 同内容镜像地址：主地址失败时按顺序尝试
  final List<String> mirrors;

  /// 全部候选地址（主地址 + 镜像），按尝试顺序
  List<String> get candidates => [url, ...mirrors];

  /// 默认 EPG 接口（fanmingming/live 提供）
  static const String defaultEpgUrl = 'https://live.fanmingming.cn/e.xml';

  PlaySource copyWith({String? epgUrl}) => PlaySource(
        id: id,
        name: name,
        url: url,
        builtIn: builtIn,
        epgUrl: epgUrl ?? this.epgUrl,
        mirrors: mirrors,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'builtIn': builtIn,
        'epgUrl': epgUrl,
        'mirrors': mirrors,
      };

  factory PlaySource.fromJson(Map<String, dynamic> json) => PlaySource(
        id: json['id'] as String? ?? '${json['name']}_${json['url']}',
        name: json['name'] as String? ?? '自定义源',
        url: json['url'] as String? ?? '',
        builtIn: json['builtIn'] as bool? ?? false,
        epgUrl: json['epgUrl'] as String?,
        mirrors: (json['mirrors'] as List?)?.cast<String>() ?? const [],
      );
}
