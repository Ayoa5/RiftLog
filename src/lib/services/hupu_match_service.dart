// 虎扑赛程服务（lol_match / lol_bo / lol_item）
//
// 实测结论（2026-10-26）：
//   1. 树结构：lol:1（根）← lol_match（比赛）← lol_bo（第几局）← lol_item（选手/教练）
//   2. 根节点 subNodeCount = 0，赛事/阶段节点不存在（lol_competition / lol_season 均查不到）
//      ⇒ **无法通过父节点列出比赛**，只能按 bizId 枚举
//   3. 同一赛事内 bizId **连续**：实测 4501–4516 全是「全球总决赛」，4500/4517 为空
//      ⇒ 用「锚点 + 向两侧逐号探测，连续 N 次未命中即停」来发现比赛
//   4. 单场信息全在 detail.infoJson（队名/比分/队标/赛事/阶段/时间/状态）

import '../models/comment_models.dart';
import '../models/match_models.dart';
import '../models/rating_models.dart';
import 'hupu_client.dart';

class HupuMatchService {
  HupuMatchService({HupuClient? client}) : _client = client ?? HupuClient();

  final HupuClient _client;

  static const String apiBase =
      'https://games.mobileapi.hupu.com/1/8.2.99/bplcommentapi';

  /// 初始锚点：2026-10-26 实测的最新一场（全球总决赛 瑞士轮）。
  /// 赛事结束后编号会继续增长，discover() 会在锚点失效时自动粗扫另找。
  static const int defaultSeed = 4516;

  /// 连续多少次未命中就认为「这一段结束」
  static const int _missStop = 3;

  /// 单向最多探测多少个编号
  static const int _maxProbe = 40;

  // ───────────────────────── 单场 ─────────────────────────

  /// 取一场比赛；不存在或解析失败返回 null（探测时用它判断空号）
  Future<LolMatch?> fetchMatch(int bizId) async {
    try {
      final json = await _client.getJson(
        '$apiBase/bpl/score_tree/getSelfByBizKey',
        query: {'outBizType': 'lol_match', 'outBizNo': bizId},
        okCodes: const <int>{1},
      );
      final data = (json['data'] as Map?)?.cast<String, dynamic>();
      if (data == null) return null;
      return LolMatch.fromData(data);
    } catch (_) {
      return null;
    }
  }

  /// 该场比赛包含的「局」（BO1 一局、BO3 最多三局）
  Future<List<LolGame>> fetchGames(int matchBizId) async {
    final items = await _children('lol_match', matchBizId);
    final games = <LolGame>[];
    for (final e in items) {
      final g = LolGame.fromItem(e);
      if (g != null) games.add(g);
    }
    return games;
  }

  /// 某一局里所有评分对象（选手 / 教练 / BP 英雄 / 解说…）
  Future<List<ScoreItem>> fetchGameScores(int gameBizId) async {
    final items = await _children('lol_bo', gameBizId);
    final out = <ScoreItem>[];
    for (final e in items) {
      final s = ScoreItem.fromNode(e);
      if (s.name.isNotEmpty) out.add(s);
    }
    return out;
  }

  // ───────────────────────── 赛程发现 ─────────────────────────

  /// 发现「最近的一个连续比赛区块」
  ///
  /// 策略：
  ///   1. 锚点有效就直接用；无效则向上/向下按步长 8 粗扫（最多 10 轮）寻找可用锚点
  ///   2. 从锚点向两侧逐号探测，连续 [_missStop] 次未命中即停
  Future<List<LolMatch>> discover({
    int seed = defaultSeed,
    int maxProbe = _maxProbe,
  }) async {
    // 1) 找可用锚点
    var anchor = seed;
    var first = await fetchMatch(anchor);

    if (first == null) {
      for (var step = 1; step <= 10 && first == null; step++) {
        for (final cand in <int>[seed + step * 8, seed - step * 8]) {
          if (cand <= 0) continue;
          final m = await fetchMatch(cand);
          if (m != null) {
            first = m;
            anchor = cand;
            break;
          }
        }
      }
      if (first == null) return const <LolMatch>[];
    }

    final found = <int, LolMatch>{anchor: first};

    // 2) 向下
    var miss = 0;
    for (var i = 1; i <= maxProbe && miss < _missStop; i++) {
      final id = anchor - i;
      if (id <= 0) break;
      final m = await fetchMatch(id);
      if (m == null) {
        miss++;
      } else {
        found[id] = m;
        miss = 0;
      }
    }

    // 3) 向上
    miss = 0;
    for (var i = 1; i <= maxProbe && miss < _missStop; i++) {
      final id = anchor + i;
      final m = await fetchMatch(id);
      if (m == null) {
        miss++;
      } else {
        found[id] = m;
        miss = 0;
      }
    }

    // 4) 按比赛时间倒序（时间缺失时退化为 bizId 倒序）
    final list = List<LolMatch>.from(found.values);
    list.sort((a, b) {
      final ta = a.matchTime;
      final tb = b.matchTime;
      if (ta != null && tb != null && ta != tb) return tb.compareTo(ta);
      return b.bizId.compareTo(a.bizId);
    });
    return list;
  }

  // ───────────────────────── 评论 ─────────────────────────

  /// 拉取某个评分对象的评论
  ///
  /// 实测（2026-10-26）：三种排序走不同接口/参数
  ///   最亮 → GET bpl/comment/list/primarySingleRow/hottest（data 是数组，约 50 条）
  ///   最晚 → GET bpl/comment/list/primarySingleRow?order=desc&publishTime=<最近一页的 cursor>
  ///   最早 → GET bpl/comment/list/primarySingleRow?order=asc&publishTime=<上一页 cursor>
  ///
  /// 注意：之前用的 `bpl/comment/list` 是另一个接口，固定返回 10 条且忽略排序，
  /// 不要再用。
  Future<CommentPage> fetchComments({
    required String type,
    required String no,
    CommentSort sort = CommentSort.brightest,
    int? cursor,
    int pageSize = 10,
  }) async {
    try {
      if (sort == CommentSort.brightest) {
        return _fetchBrightest(type, no);
      }

      // latest：首屏用「当前时间」作为游标；earliest：用 0
      final publishTime = cursor ??
          (sort == CommentSort.latest
              ? DateTime.now().millisecondsSinceEpoch
              : 0);

      final json = await _client.getJson(
        '$apiBase/bpl/comment/list/primarySingleRow',
        query: {
          'publishTime': publishTime,
          'order': sort == CommentSort.latest ? 'desc' : 'asc',
          'outBizType': type,
          'outBizNo': no,
          'clientCode': '',
          'cid': '',
        },
        okCodes: const <int>{1},
      );
      final data = (json['data'] as Map?)?.cast<String, dynamic>();
      if (data == null) {
        return const CommentPage(
          items: <HupuComment>[],
          total: 0,
          hasMore: false,
        );
      }
      final items = _parseCommentList(data['comments']);
      final cur = (data['cursor'] as Map?)?.cast<String, dynamic>();
      final next = cur?['publishTime'];
      final total = data['commentCount'];

      return CommentPage(
        items: items,
        total: total is num ? total.toInt() : items.length,
        hasMore: data['hasMore'] == true && items.isNotEmpty,
        nextCursor: next is num ? next.toInt() : null,
      );
    } catch (_) {
      return const CommentPage(
        items: <HupuComment>[],
        total: 0,
        hasMore: false,
      );
    }
  }

  /// 最亮：独立接口，返回裸数组（约 50 条，按亮数降序）
  Future<CommentPage> _fetchBrightest(String type, String no) async {
    final json = await _client.getJson(
      '$apiBase/bpl/comment/list/primarySingleRow/hottest',
      query: {
        'outBizType': type,
        'outBizNo': no,
        'clientCode': '',
        'cid': '',
      },
      okCodes: const <int>{1},
    );
    final items = _parseCommentList(json['data']);
    return CommentPage(
      items: items,
      total: items.length,
      hasMore: false,
      nextCursor: null,
    );
  }

  List<HupuComment> _parseCommentList(dynamic raw) {
    if (raw is! List) return const <HupuComment>[];
    final out = <HupuComment>[];
    for (final e in raw) {
      if (e is Map<String, dynamic>) {
        final c = HupuComment.fromJson(e);
        if (c.content.isNotEmpty) out.add(c);
      }
    }
    return out;
  }

  // ───────────────────────── 内部 ─────────────────────────

  Future<List<Map<String, dynamic>>> _children(String bizType, int bizNo) async {
    try {
      final json = await _client.getJson(
        '$apiBase/bpl/score_tree/getCurAndSubNodeByBizKey',
        query: {
          'relation': 'CHILD',
          'page': 1,
          'pageSize': 30,
          'outBizType': bizType,
          'outBizNo': bizNo,
        },
        okCodes: const <int>{1},
      );
      final data = (json['data'] as Map?)?.cast<String, dynamic>();
      final page = (data?['pageResult'] as Map?)?.cast<String, dynamic>();
      final raw = page?['data'];
      if (raw is! List) return const <Map<String, dynamic>>[];
      return raw.whereType<Map<String, dynamic>>().toList(growable: false);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }
}
