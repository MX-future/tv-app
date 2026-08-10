/// EPG 节目单条目。
class EpgProgram {
  const EpgProgram({
    required this.start,
    required this.end,
    required this.channel,
    required this.title,
    this.desc,
  });

  final DateTime start;
  final DateTime end;
  final String channel;
  final String title;
  final String? desc;

  bool get isNow {
    final now = DateTime.now();
    return now.isAfter(start) && now.isBefore(end);
  }

  factory EpgProgram.fromJson(Map<String, dynamic> json) => EpgProgram(
        start: DateTime.parse(json['start'] as String),
        end: DateTime.parse(json['end'] as String),
        channel: json['channel'] as String,
        title: json['title'] as String,
        desc: json['desc'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'channel': channel,
        'title': title,
        'desc': desc,
      };
}
