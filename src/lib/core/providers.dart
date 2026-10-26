// 全局 Provider
// 放在 core/ 下，避免页面之间互相 import 造成循环依赖

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/comment_models.dart';
import '../models/hupu_models.dart';
import '../models/match_models.dart';
import '../models/rating_models.dart';
import '../services/hupu_match_service.dart';
import '../services/hupu_rating_service.dart';
import '../services/hupu_scraper_service.dart';

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

/// 某个评分对象的评论（实测只有选手节点 lol_item 有数据）
final commentsProvider =
    FutureProvider.autoDispose.family<CommentPage, CommentQuery>(
  (ref, q) => ref.watch(matchServiceProvider).fetchComments(
        type: q.type,
        no: q.no,
        order: q.order,
      ),
);
