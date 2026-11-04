// 评分数据模型（对应虎扑 score_tree 接口）
// 接口：GET https://games.mobileapi.hupu.com/1/8.2.99/bplcommentapi/bpl/score_tree/getCurAndSubNodeByBizKey
// 实测字段来源：docs/虎扑接口实测记录_20261026.md

int asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

double asDouble(dynamic v) {
  if (v is double) return v;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

String asString(dynamic v) => v == null ? '' : v.toString();

/// infoJson 里的值统一是「单元素数组」，例如 {"type":["player"],"teamId":["2"]}
String _firstOf(dynamic v) {
  if (v is List && v.isNotEmpty) return asString(v.first);
  return asString(v);
}

/// 一个评分节点（选手 / 教练 / BP 英雄 / 解说…）
class ScoreItem {
  const ScoreItem({
    required this.nodeId,
    required this.bizId,
    required this.name,
    required this.kind,
    required this.score,
    required this.votes,
    required this.teamId,
    required this.kda,
    required this.avatar,
    required this.championPic,
  });

  final int nodeId;

  /// 选手/教练的 bizId（如 Gumayusi=79822）。评论接口用它，不是 nodeId
  final int bizId;
  final String name;

  /// player / coach / bpHero / ''（解说等杂项）
  final String kind;
  final double score;
  final int votes;

  /// 阵营标识：同 teamId 为同一队（实测 iG=2、HLE=100193）
  final String teamId;

  /// 形如 "12/4/6"，无数据时为 ''
  final String kda;
  final String avatar;

  /// 本局使用的英雄头像 URL。
  ///
  /// 实测（2026-11-04）：虎扑把选手本局英雄图放在 `infoJson.auxiliaryPic[0]`，
  /// 命中时形如 `https://p1.hoopchina.com.cn/gdc/lol/champion/pic/<hash>.png`；
  /// 数据缺失时会退化成队徽/编辑图等兜底图（路径不含 `/champion/pic/`），
  /// 为避免把兜底图误当英雄，这里只认官方英雄图 CDN，其余置空。
  final String championPic;

  bool get isPlayer => kind == 'player';
  bool get isCoach => kind == 'coach';

  factory ScoreItem.fromNode(Map<String, dynamic> item) {
    final node = (item['node'] as Map?)?.cast<String, dynamic>() ?? const {};
    final info = (node['infoJson'] as Map?)?.cast<String, dynamic>() ?? const {};
    final img = node['image'];

    final k = _firstOf(info['killCount']);
    final d = _firstOf(info['deathCount']);
    final a = _firstOf(info['assistCount']);
    final kda = (k.isNotEmpty && k != '-') ? '$k/$d/$a' : '';

    // 本局英雄头像：auxiliaryPic 是单元素数组（偶尔是字符串）
    final auxRaw = info['auxiliaryPic'];
    final aux = (auxRaw is List && auxRaw.isNotEmpty)
        ? asString(auxRaw.first)
        : asString(auxRaw);
    final championPic = aux.contains('/champion/pic/') ? aux : '';

    return ScoreItem(
      nodeId: asInt(item['nodeId'] ?? node['nodeId']),
      bizId: asInt(node['bizId']),
      name: asString(node['name']),
      kind: _firstOf(info['type']),
      score: asDouble(node['scoreAvg']),
      votes: asInt(node['scorePersonCount']),
      teamId: _firstOf(info['teamId']),
      kda: kda,
      avatar: (img is List && img.isNotEmpty) ? asString(img.first) : '',
      championPic: championPic,
    );
  }
}

/// 一次评分查询的结果
class RatingBundle {
  const RatingBundle({
    required this.title,
    required this.items,
    required this.comments,
    required this.outBizType,
    required this.outBizNo,
  });

  /// 节点名，如「第1局」
  final String title;
  final List<ScoreItem> items;

  /// 该节点的热评（hottestComments，纯文本数组）
  final List<String> comments;
  final String outBizType;
  final String outBizNo;

  bool get isEmpty => items.isEmpty;

  /// 按 teamId 分组（保持原顺序）
  Map<String, List<ScoreItem>> get byTeam {
    final map = <String, List<ScoreItem>>{};
    for (final it in items) {
      map.putIfAbsent(it.teamId, () => <ScoreItem>[]).add(it);
    }
    return map;
  }

  /// 只要选手+教练，过滤掉 BP 英雄、解说、二路、主持等杂项
  List<ScoreItem> get roster =>
      items.where((e) => e.isPlayer || e.isCoach).toList(growable: false);
}
