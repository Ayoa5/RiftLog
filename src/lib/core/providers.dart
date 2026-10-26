// 全局 Provider
// 放在 core/ 下，避免页面之间互相 import 造成循环依赖

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/hupu_models.dart';
import '../models/lpl_models.dart';
import '../models/match_models.dart';
import '../models/rating_models.dart';
import '../services/hupu_match_service.dart';
import '../services/hupu_rating_service.dart';
import '../services/hupu_scraper_service.dart';
import '../services/lpl_service.dart';

// ── 服务实例 ──
final scraperProvider = Provider<HupuScraperService>(
  (ref) => HupuScraperService(),
);

final matchServiceProvider = Provider<HupuMatchService>(
  (ref) => HupuMatchService(),
);

final ratingServiceProvider = Provider<HupuRatingService>(
  (ref) => HupuRatingService(),
);

// ── 社区（论坛帖子）──
final zoneThreadsProvider =
    FutureProvider.autoDispose.family<List<HupuThread>, String>(
  (ref, zone) => ref.watch(scraperProvider).fetchZoneThreads(zone: zone),
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


final lplServiceProvider = Provider<LplScheduleService>(
  (ref) => LplScheduleService(),
);

/// LPL 官方赛程（含未开赛，用于「即将开始」区块）
final lplScheduleProvider = FutureProvider.autoDispose<List<LplMatch>>(
  (ref) => ref.watch(lplServiceProvider).fetchAll(),
);
