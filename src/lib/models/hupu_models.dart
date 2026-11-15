// 虎扑数据结构模型
//
// 2026-11-15：社区（论坛帖子流）功能已移除，
// 随之删除 HupuThread / ThreadDetail / LightReply / ThreadBundle 四个模型。
// 现在只剩评分链路里仍在用的 PlayerRating。

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
