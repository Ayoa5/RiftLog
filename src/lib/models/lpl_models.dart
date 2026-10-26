// LPL 官方赛程模型
//
// 数据来源（实测 2026-10-26，静态 JSON，无需签名）：
//   GET https://lpl.qq.com/web201612/data/LOL_MATCH2_MATCH_HOMEPAGE_BMATCH_LIST_{gameId}.js
//   gameId=246 → 2026 全球总决赛，46 场（含未开赛）
//
// 字段实测：
//   bMatchId / bMatchName（"CFO vs T1" 或占位名 "D5G1"）
//   TeamShortNameA / TeamShortNameB（有时为空，不可靠 → 用 bMatchName 拆）
//   ScoreA / ScoreB、MatchDate（"2026-10-27 01:00:00"）
//   MatchStatus（3=已结束，1=未开始）
//   GameTypeName（阶段：入围赛/瑞士轮/淘汰赛）、GameProcName（第几天/八进四…）
//   GameModeName（BO1/BO3/BO5）、GamePlaceName、GameName

/// 一场 LPL 官方赛程
class LplMatch {
  const LplMatch({
    required this.matchId,
    required this.name,
    required this.teamA,
    required this.teamB,
    required this.scoreA,
    required this.scoreB,
    required this.date,
    required this.status,
    required this.stage,
    required this.round,
    required this.bo,
    required this.place,
    required this.gameName,
  });

  final int matchId;

  /// 原始名称，如 "CFO vs T1"；未定对阵时为占位名（如 "D5G1"）
  final String name;
  final String teamA;
  final String teamB;
  final int scoreA;
  final int scoreB;
  final DateTime? date;

  /// 3 = 已结束，1 = 未开始
  final int status;

  /// 阶段，如「瑞士轮」
  final String stage;

  /// 轮次，如「第四天」「八进四」
  final String round;

  /// 赛制，如「BO1」
  final String bo;

  /// 举办地，如「美国 加利福尼亚州洛杉矶」
  final String place;
  final String gameName;

  bool get isFinished => status == 3;
  bool get isUpcoming => status == 1;

  /// 对阵是否已确定（占位名如 D5G1 不含 " vs "）
  bool get hasTeams => teamA.isNotEmpty && teamB.isNotEmpty;

  String get dateLabel {
    final d = date;
    if (d == null) return '时间待定';
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    return '${d.month}月${d.day}日 周${weekdays[d.weekday - 1]}';
  }

  String get timeLabel {
    final d = date;
    if (d == null) return '';
    return '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  static int _i(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static String _s(dynamic v) => v == null ? '' : v.toString();

  static LplMatch? fromJson(Map<String, dynamic> j) {
    final matchId = _i(j['bMatchId']);
    if (matchId == 0) return null;

    final name = _s(j['bMatchName']);
    var a = _s(j['TeamShortNameA']);
    var b = _s(j['TeamShortNameB']);

    // TeamShortName 有空值情况，以 bMatchName 拆分为准
    if ((a.isEmpty || b.isEmpty) && name.contains(' vs ')) {
      final parts = name.split(' vs ');
      if (parts.length == 2) {
        if (a.isEmpty) a = parts[0].trim();
        if (b.isEmpty) b = parts[1].trim();
      }
    }

    DateTime? dt;
    final raw = _s(j['MatchDate']);
    if (raw.isNotEmpty) {
      dt = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    }

    return LplMatch(
      matchId: matchId,
      name: name,
      teamA: a,
      teamB: b,
      scoreA: _i(j['ScoreA']),
      scoreB: _i(j['ScoreB']),
      date: dt,
      status: _i(j['MatchStatus']),
      stage: _s(j['GameTypeName']),
      round: _s(j['GameProcName']),
      bo: _s(j['GameModeName']),
      place: _s(j['GamePlaceName']),
      gameName: _s(j['GameName']),
    );
  }

  /// 用于和虎扑比赛做粗匹配：队名排序 + 日期
  String get joinKey {
    if (!hasTeams) return '';
    final names = <String>[teamA.toUpperCase(), teamB.toUpperCase()]..sort();
    final d = date;
    final day = d == null
        ? ''
        : '${d.year}-${d.month.toString().padLeft(2, '0')}-'
            '${d.day.toString().padLeft(2, '0')}';
    return '${names.join('|')}@$day';
  }
}
