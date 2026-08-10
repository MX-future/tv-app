/// 电视频道模型。
class Channel {
  const Channel({
    required this.name,
    required this.group,
    required this.url,
    this.tvgName,
    this.logo,
    this.sourceName,
    this.altUrls = const [],
  });

  /// 频道显示名（如 "CCTV-1综合"）
  final String name;

  /// 分组（group-title）
  final String group;

  /// 直播流地址（首选）
  final String url;

  /// 频道短名（tvg-name，用于 EPG 匹配）
  final String? tvgName;

  /// 台标地址（tvg-logo）
  final String? logo;

  /// 所属源名称
  final String? sourceName;

  /// 备用播放地址（来自其他源的同名频道，主地址失败时依次尝试）
  final List<String> altUrls;

  /// 唯一标识（收藏用）
  String get id => '$name|$url';

  /// EPG 节目单匹配键
  String get epgKey => tvgName ?? name;

  /// 频道名归一化（用于跨源匹配同名频道）
  static String normalizeName(String name) => name
      .toLowerCase()
      .replaceAll(RegExp(r'[\s\-+．.·]'), '');

  String get normalizedKey => normalizeName(epgKey);

  /// 全部候选播放地址（主地址 + 备用）
  List<String> get candidates => [url, ...altUrls];

  Channel withAltUrls(List<String> alts) => Channel(
        name: name,
        group: group,
        url: url,
        tvgName: tvgName,
        logo: logo,
        sourceName: sourceName,
        altUrls: alts,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'group': group,
        'url': url,
        'tvgName': tvgName,
        'logo': logo,
        'sourceName': sourceName,
        'altUrls': altUrls,
      };

  factory Channel.fromJson(Map<String, dynamic> json) => Channel(
        name: json['name'] as String? ?? '未知频道',
        group: json['group'] as String? ?? '未分组',
        url: json['url'] as String? ?? '',
        tvgName: json['tvgName'] as String?,
        logo: json['logo'] as String?,
        sourceName: json['sourceName'] as String?,
        altUrls: (json['altUrls'] as List?)?.cast<String>() ?? const [],
      );
}
