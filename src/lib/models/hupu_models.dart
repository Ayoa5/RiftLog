// 虎扑数据结构模型
// 字段来源：docs/虎扑接口实测记录_20261026.md（实测 JSON 结构）
// 注意：lights（亮评）字段在实测样本中为空数组，其元素结构为「按常见键名容错映射」，
//       拿到真实亮评样本后应据实修正。

int _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

double _asDouble(dynamic v) {
  if (v is double) return v;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

String _asString(dynamic v) => v == null ? '' : v.toString();

/// 板块帖子列表项（来自 bbs.hupu.com/{zone} 的 __NEXT_DATA__）
class HupuThread {
  const HupuThread({
    required this.tid,
    required this.title,
    required this.replies,
    required this.recommendNum,
    required this.author,
    required this.timeText,
  });

  final int tid;
  final String title;
  final int replies;
  final int recommendNum;
  final String author;
  final String timeText;

  factory HupuThread.fromJson(Map<String, dynamic> j) => HupuThread(
        tid: _asInt(j['tid']),
        title: _asString(j['title']),
        replies: _asInt(j['replies']),
        recommendNum: _asInt(j['recommendNum']),
        author: _asString(j['username'] ?? j['author']),
        timeText: _asString(j['time']),
      );

  /// 「赛后」帖判定：虎扑赛后帖标题固定以 [赛后] / 【赛后】 开头
  bool get isPostMatch =>
      title.startsWith('[赛后]') ||
      title.startsWith('【赛后】') ||
      title.contains('[赛后');

  /// 「情报站/流言板」等资讯类，不参与赛后评分
  bool get isNews => title.startsWith('[情报站]') || title.startsWith('[流言板]');
}

/// 帖子详情（来自 GET /api/v2/threads?tid=）
class ThreadDetail {
  const ThreadDetail({
    required this.tid,
    required this.title,
    required this.contentHtml,
    required this.lightsCount,
    required this.replies,
    required this.createdAt,
    required this.createdAtText,
    required this.authorName,
    required this.authorAvatar,
  });

  final int tid;
  final String title;
  final String contentHtml;
  final int lightsCount;
  final int replies;
  final int createdAt;
  final String createdAtText;
  final String authorName;
  final String authorAvatar;

  factory ThreadDetail.fromJson(Map<String, dynamic> j) {
    final author = (j['author'] as Map?)?.cast<String, dynamic>() ?? const {};
    return ThreadDetail(
      tid: _asInt(j['tid']),
      title: _asString(j['title']),
      contentHtml: _asString(j['content']),
      lightsCount: _asInt(j['lights']),
      replies: _asInt(j['replies']),
      createdAt: _asInt(j['createdAt']),
      createdAtText: _asString(j['createdAtFormat']),
      authorName: _asString(author['puname']),
      authorAvatar: _asString(author['header']),
    );
  }

  DateTime get createdAtTime =>
      DateTime.fromMillisecondsSinceEpoch(createdAt, isUtc: false);
}

/// 亮评（「这些回复亮了」）
class LightReply {
  const LightReply({
    required this.id,
    required this.content,
    required this.lightCount,
    required this.author,
    required this.timeText,
  });

  final int id;
  final String content;
  final int lightCount;
  final String author;
  final String timeText;

  /// 容错解析：虎扑不同接口对亮评的键名不完全统一
  factory LightReply.fromJson(Map<String, dynamic> j) {
    final author = (j['author'] as Map?)?.cast<String, dynamic>();
    return LightReply(
      id: _asInt(j['pid'] ?? j['id'] ?? j['replyId']),
      content: _asString(j['content'] ?? j['quote'] ?? j['text']),
      lightCount: _asInt(j['lights'] ?? j['lightCount'] ?? j['light'] ?? j['praise']),
      author: _asString(author?['puname'] ?? j['username'] ?? j['authorName']),
      timeText: _asString(
        j['createdAtFormat'] ?? j['time'] ?? j['createdAt'],
      ),
    );
  }
}

/// 选手评分
/// ⚠️ 数据源尚未锁定（见 docs），此模型先按需求定义好 UI 契约。
class PlayerRating {
  const PlayerRating({
    required this.name,
    required this.team,
    required this.role,
    required this.score,
    required this.votes,
  });

  final String name;
  final String team; // 'red' / 'blue' 或队名
  final String role; // 上单/打野/中单/ADC/辅助/教练
  final double score; // 0~10
  final int votes;

  bool get isRedSide => team == 'red' || team.contains('红');

  factory PlayerRating.fromJson(Map<String, dynamic> j) => PlayerRating(
        name: _asString(j['name'] ?? j['player'] ?? j['puname']),
        team: _asString(j['team'] ?? j['side']),
        role: _asString(j['role'] ?? j['position']),
        score: _asDouble(j['score'] ?? j['rating'] ?? j['avg']),
        votes: _asInt(j['votes'] ?? j['count'] ?? j['num']),
      );
}

/// 帖子详情页一次性需要的全部数据
class ThreadBundle {
  const ThreadBundle({
    required this.detail,
    required this.lights,
    required this.ratings,
  });

  final ThreadDetail detail;
  final List<LightReply> lights;
  final List<PlayerRating> ratings;
}
