// 比赛阶段判定：综合「LPL 赛程状态」与「虎扑节点状态」两个数据源
//
// 为什么需要这个：LPL 官网的 MatchStatus 只有 1(未开始) / 3(已结束)，
// 一场 BO3/BO5 打完才翻成 3。而虎扑在**开赛前约 1 小时**就建好了节点
// （实测：LYON vs IG 07:00 开赛，节点 createDt 06:04），且每局都有独立评分。
//
// 所以不能只看 LPL 的 status：
//   · 虎扑节点存在且未结束        → 进行中
//   · LPL 说已结束                → 已结束
//   · LPL 说未开始但开赛时间已过  → 进行中（LPL 滞后窗口）
//   · 其余                        → 未开赛

import 'lpl_models.dart';
import 'match_models.dart';

enum MatchPhase { live, finished, upcoming }

MatchPhase phaseOf(LplMatch m, LolMatch? hupu, {DateTime? now}) {
  final t = now ?? DateTime.now();
  if (hupu != null && !hupu.isCompleted) return MatchPhase.live;
  if (m.isFinished) return MatchPhase.finished;
  final d = m.date;
  if (d != null && t.isAfter(d)) return MatchPhase.live;
  return MatchPhase.upcoming;
}
