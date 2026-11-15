// 逐局胜负：从虎扑每局选手 KDA / 评分推导，并用系列赛大比分自校验
//
// 数据来源说明（2026-11-15 实测 BLG 3-1 T1，bizId 4616）：
//   虎扑接口本身没有「单局胜负」字段，但每个 lol_item 选手节点带
//   killCount / deathCount / assistCount 与 scoreAvg，是完整对局数据：
//     第1局 BLG 18:6（均分 9.9:4.8）  第2局 T1 22:10（8.6:7.1）
//     第3局 BLG 19:10（9.8:5.6）      第4局 BLG 21:9（10.0:6.0）
//   → 击杀判胜与评分判胜 4/4 一致，且胜场数 3:1 与系列赛比分完全吻合。
//
// 判定规则：
//   1. 本局两队选手击杀分别累加，多者判胜；
//   2. 用两队选手平均评分做交叉验证（不一致时 reliable=false）；
//   3. 全部局算完后，用「胜场数 == 系列赛大比分」做整体自校验
//      （seriesConsistent=false 时界面会标「判定存疑」，避免误导）。
//   4. 任一队无选手数据 / 击杀相同 → 退回评分判定，仍无则判未知。

class GameOutcome {
  const GameOutcome({
    required this.gameBizId,
    required this.gameName,
    required this.winnerTeamId,
    required this.homeKills,
    required this.awayKills,
    required this.killsByTeam,
    required this.reliable,
    required this.seriesConsistent,
  });

  final int gameBizId;
  final String gameName;

  /// 胜方 teamId；无法确定时为空串
  final String winnerTeamId;

  final int homeKills;
  final int awayKills;

  /// 每队本局击杀合计（用于概览条）
  final Map<String, int> killsByTeam;

  /// 击杀判定与评分判定是否一致
  final bool reliable;

  /// 推导出的胜场序列是否与系列赛大比分吻合
  final bool seriesConsistent;

  bool get isKnown => winnerTeamId.isNotEmpty;

  /// 是否应当把结论当作确定结果显示
  bool get isConfident => isKnown && reliable && seriesConsistent;

  GameOutcome withSeriesConsistent(bool value) => GameOutcome(
        gameBizId: gameBizId,
        gameName: gameName,
        winnerTeamId: winnerTeamId,
        homeKills: homeKills,
        awayKills: awayKills,
        killsByTeam: killsByTeam,
        reliable: reliable,
        seriesConsistent: value,
      );
}
