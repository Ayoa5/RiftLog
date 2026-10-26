// 虎扑赛事模型（lol_match / lol_bo）
//
// 数据来源（实测）：
//   GET .../bpl/score_tree/getSelfByBizKey?outBizType=lol_match&outBizNo={id}
//   → data.detail.infoJson 内含：
//       matchStatus / competitionTypeCn / competitionStageTypeCn / matchTime
//       homeTeamName / awayTeamName / homeTeamScore / awayTeamScore
//       homeTeamLogo / awayTeamLogo / homeTeamId / awayTeamId / winTeamId / matchId
//   GET .../bpl/score_tree/getCurAndSubNodeByBizKey?relation=CHILD&outBizType=lol_match&outBizNo={id}
//   → data.pageResult.data[] 为该场比赛的「局」（bizType = lol_bo）

/// infoJson 的值统一是「单元素数组」，取 [0]
String firstOf(dynamic v) {
  if (v is List && v.isNotEmpty) return v.first?.toString() ?? '';
  return v?.toString() ?? '';
}

int firstInt(dynamic v) => int.tryParse(firstOf(v)) ?? 0;

/// 一场比赛（BO1/BO3/BO5）
class LolMatch {
  const LolMatch({
    required this.bizId,
    required this.title,
    required this.homeTeam,
    required this.awayTeam,
    required this.homeScore,
    required this.awayScore,
    required this.homeLogo,
    required this.awayLogo,
    required this.competition,
    required this.stage,
    required this.status,
    required this.matchTime,
    required this.winTeamId,
    required this.homeTeamId,
    required this.awayTeamId,
  });

  /// 虎扑 bizId，用于取评分
  final int bizId;

  /// 原始标题，如 "HLE 0-1 IG"
  final String title;
  final String homeTeam;
  final String awayTeam;
  final int homeScore;
  final int awayScore;
  final String homeLogo;
  final String awayLogo;

  /// 赛事名，如「全球总决赛」
  final String competition;

  /// 阶段，如「瑞士轮」
  final String stage;

  /// 原始状态值（COMPLETED / …）
  final String status;
  final DateTime? matchTime;

  final String winTeamId;
  final String homeTeamId;
  final String awayTeamId;

  bool get isCompleted =>
      status.toUpperCase().contains('COMPLET') || status.toUpperCase().contains('FINISH');

  bool get isLive {
    final s = status.toUpperCase();
    return s.contains('LIVE') || s.contains('ONGOING') || s.contains('PLAYING');
  }

  bool get isUpcoming => !isCompleted && !isLive;

  /// 首页展示用的状态文案
  String get statusText => isCompleted ? '已结束' : (isLive ? '进行中' : '未开始');

  /// 胜方队名（未结束返回 null）
  String? get winnerName {
    if (!isCompleted || winTeamId.isEmpty) return null;
    if (winTeamId == homeTeamId) return homeTeam;
    if (winTeamId == awayTeamId) return awayTeam;
    return null;
  }

  /// 从 getSelfByBizKey 的 data 解析
  static LolMatch? fromData(Map<String, dynamic> data) {
    final det = (data['detail'] as Map?)?.cast<String, dynamic>();
    if (det == null) return null;
    final info = (det['infoJson'] as Map?)?.cast<String, dynamic>() ?? const {};

    final bizId = int.tryParse(det['bizId']?.toString() ?? '') ?? 0;
    final title = det['name']?.toString() ?? '';
    if (bizId == 0 || title.isEmpty) return null;

    final ts = firstInt(info['matchTime']);

    return LolMatch(
      bizId: bizId,
      title: title,
      homeTeam: firstOf(info['homeTeamName']),
      awayTeam: firstOf(info['awayTeamName']),
      homeScore: firstInt(info['homeTeamScore']),
      awayScore: firstInt(info['awayTeamScore']),
      homeLogo: firstOf(info['homeTeamLogo']),
      awayLogo: firstOf(info['awayTeamLogo']),
      competition: firstOf(info['competitionTypeCn']),
      stage: firstOf(info['competitionStageTypeCn']),
      status: firstOf(info['matchStatus']),
      matchTime: ts > 0 ? DateTime.fromMillisecondsSinceEpoch(ts * 1000) : null,
      winTeamId: firstOf(info['winTeamId']),
      homeTeamId: firstOf(info['homeTeamId']),
      awayTeamId: firstOf(info['awayTeamId']),
    );
  }

  /// 日期分组标题，如「10月25日 周日」
  String get dateLabel {
    final t = matchTime;
    if (t == null) return '未知日期';
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    return '${t.month}月${t.day}日 周${weekdays[t.weekday - 1]}';
  }
}

/// 一场比赛里的一「局」
class LolGame {
  const LolGame({required this.bizId, required this.name, required this.score});

  final int bizId;
  final String name;
  final double score;

  /// 局节点没有单独的 bizId 字段时，从 node.bizId 取
  static LolGame? fromItem(Map<String, dynamic> item) {
    final node = (item['node'] as Map?)?.cast<String, dynamic>() ?? const {};
    final bizId = int.tryParse(node['bizId']?.toString() ?? '') ?? 0;
    final name = node['name']?.toString() ?? '';
    if (bizId == 0 || name.isEmpty) return null;
    final s = node['scoreAvg'];
    final score = s is num ? s.toDouble() : double.tryParse(s?.toString() ?? '') ?? 0;
    return LolGame(bizId: bizId, name: name, score: score);
  }
}

/// 缓存用序列化（只存必要字段，体积小）
extension LolMatchCache on LolMatch {
  Map<String, dynamic> toCacheJson() => <String, dynamic>{
        'bizId': bizId,
        'title': title,
        'homeTeam': homeTeam,
        'awayTeam': awayTeam,
        'homeScore': homeScore,
        'awayScore': awayScore,
        'homeLogo': homeLogo,
        'awayLogo': awayLogo,
        'competition': competition,
        'stage': stage,
        'status': status,
        'matchTime': matchTime?.millisecondsSinceEpoch ?? 0,
        'winTeamId': winTeamId,
        'homeTeamId': homeTeamId,
        'awayTeamId': awayTeamId,
      };
}

/// 从缓存恢复
LolMatch? lolMatchFromCache(Map<String, dynamic> j) {
  final id = j['bizId'];
  if (id is! int || id == 0) return null;
  final ts = j['matchTime'];
  return LolMatch(
    bizId: id,
    title: (j['title'] ?? '').toString(),
    homeTeam: (j['homeTeam'] ?? '').toString(),
    awayTeam: (j['awayTeam'] ?? '').toString(),
    homeScore: j['homeScore'] is int ? j['homeScore'] as int : 0,
    awayScore: j['awayScore'] is int ? j['awayScore'] as int : 0,
    homeLogo: (j['homeLogo'] ?? '').toString(),
    awayLogo: (j['awayLogo'] ?? '').toString(),
    competition: (j['competition'] ?? '').toString(),
    stage: (j['stage'] ?? '').toString(),
    status: (j['status'] ?? '').toString(),
    matchTime: (ts is int && ts > 0)
        ? DateTime.fromMillisecondsSinceEpoch(ts)
        : null,
    winTeamId: (j['winTeamId'] ?? '').toString(),
    homeTeamId: (j['homeTeamId'] ?? '').toString(),
    awayTeamId: (j['awayTeamId'] ?? '').toString(),
  );
}

