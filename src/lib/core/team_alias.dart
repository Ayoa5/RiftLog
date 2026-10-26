// 队名归一化
//
// 问题：同一支队伍在不同数据源里写法不同，直接比字符串会导致匹配失败。
// 实测差异（2026-10-27）：
//   LPL 官方赛程 → MKOI、TLAW
//   虎扑比赛节点 → KOI、TL
// 两者对不上时该场比赛就显示「暂无评分」，所以必须先归一化再比较。

const Map<String, String> _alias = <String, String>{
  // LPL 写法 → 虎扑写法
  'MKOI': 'KOI',
  'MOVISTAR KOI': 'KOI',
  'TLAW': 'TL',
  'TEAM LIQUID': 'TL',
  'FURIA': 'FUR',
  'FURIA ESPORTS': 'FUR',
};

/// 归一化为可用于比较的队名（去空格、转大写、应用别名）
String canonicalTeam(String raw) {
  final t = raw.trim().toUpperCase();
  if (t.isEmpty) return '';
  return _alias[t] ?? t;
}
