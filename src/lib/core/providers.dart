// 全局 Provider
// 放在 core/ 下，避免页面之间互相 import 造成循环依赖
//
// 2026-11-15：社区（论坛帖子流）功能已移除，
// 随之删除 scraperProvider 与 zoneThreadsProvider。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/game_outcome.dart';
import '../models/lpl_models.dart';
import '../models/match_models.dart';
import '../models/rating_models.dart';
import '../services/hupu_match_service.dart';
import '../services/hupu_rating_service.dart';
import '../services/lpl_service.dart';

// ── 服务实例 ──
final matchServiceProvider = Provider<HupuMatchService>(
  (ref) => HupuMatchService(),
);

final ratingServiceProvider = Provider<HupuRatingService>(
  (ref) => HupuRatingService(),
);

// ── 赛程 ──
/// 最近一个连续比赛区块（按时间倒序）
final scheduleProvider = FutureProvider.autoDispose<List<LolMatch>>(
  (ref) => ref.watch(matchServiceProvider).discover(),
);

/// 单场比赛的局列表
final gamesProvider = FutureProvider.autoDispose.family<List<LolGame>, int>(
  (ref, matchId) => ref.watch(matchServiceProvider).fetchGames(matchId),
);

/// 某一局的全部评分对象
final gameScoresProvider =
    FutureProvider.autoDispose.family<List<ScoreItem>, int>(
  (ref, gameId) => ref.watch(matchServiceProvider).fetchGameScores(gameId),
);

/// 逐局胜负推导的参数（只含基本类型，保证 family key 稳定）
typedef GameOutcomeArgs = ({
  int matchBizId,
  String homeTeamId,
  String awayTeamId,
  int homeScore,
  int awayScore,
});

/// 这场比赛每一局的胜方 + 击杀对比；并发拉取各局评分，只请求一次并缓存
final gameOutcomesProvider =
    FutureProvider.autoDispose.family<List<GameOutcome>, GameOutcomeArgs>(
  (ref, a) => ref.watch(matchServiceProvider).fetchGameOutcomes(
        matchBizId: a.matchBizId,
        homeTeamId: a.homeTeamId,
        awayTeamId: a.awayTeamId,
        homeScore: a.homeScore,
        awayScore: a.awayScore,
      ),
);

final lplServiceProvider = Provider<LplScheduleService>(
  (ref) => LplScheduleService(),
);

/// LPL 官方赛程（含未开赛，用于「即将开始」区块）
final lplScheduleProvider = FutureProvider.autoDispose<List<LplMatch>>(
  (ref) => ref.watch(lplServiceProvider).fetchAll(),
);
