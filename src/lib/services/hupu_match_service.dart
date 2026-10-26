// 虎扑赛程服务（lol_match / lol_bo / lol_item）
//
// 实测结论（2026-10-26）：
//   1. 树结构：lol:1（根）← lol_match（比赛）← lol_bo（第几局）← lol_item（选手/教练）
//   2. 根节点 subNodeCount = 0，赛事/阶段节点不存在（lol_competition / lol_season 均查不到）
//      ⇒ **无法通过父节点列出比赛**，只能按 bizId 枚举
//   3. 同一赛事内 bizId **连续**：实测 4501–4516 全是「全球总决赛」，4500/4517 为空
//      ⇒ 用「锚点 + 向两侧逐号探测，连续 N 次未命中即停」来发现比赛
//   4. 单场信息全在 detail.infoJson（队名/比分/队标/赛事/阶段/时间/状态）

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

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

  /// 发现虎扑里现有的比赛节点
  ///
  /// ⚠️ 编号不是「一路递增」，而是**分簇的**（实测 2026-10-27）：
  ///   4501–4516 → 10-18 ~ 10-26 的比赛
  ///   4601–4610 → 10-24 ~ 10-27 的比赛（新开一段）
  ///   4219–4222 → 10-16 ~ 10-17 入围赛（离瑞士轮那段隔了 280 个号！）
  ///   4517–4600 全空
  /// 所以不能用「从锚点逐号 ±1，连续 3 次未命中就停」——那样永远到不了新簇。
  ///
  /// 策略：
  /// 策略：
  ///   · 本地缓存新鲜（默认 20 分钟）→ 直接返回，并在后台做增量补齐
  ///   · 否则全量扫描：步长 3 网格 [seed-350, seed+250] + 每个命中点 ±10 展开
  ///     （实测簇长度 4~22，步长 3 可稳定命中；步长 25 会整段漏掉）
  ///   · 结果写入 SharedPreferences，下次启动秒开
  /// 全程 14 路并发。
  Future<List<LolMatch>> discover({
    int seed = defaultSeed,
    bool force = false,
  }) async {
    if (!force) {
      final cached = await _readCache();
      if (cached != null) {
        _cache
          ..clear()
          ..addEntries(cached.items.map((m) => MapEntry(m.bizId, m)));
        // 后台补新，不阻塞首屏
        _refreshIncremental();
        return _sortedCache();
      }
    }

    // ── 全量扫描 ──
    final grid = <int>[];
    for (var id = seed - 350; id <= seed + 250; id += 3) {
      if (id > 0) grid.add(id);
    }
    for (final m in await _probeMany(grid)) {
      _cache[m.bizId] = m;
    }

    // 每个命中点向两侧展开，把整簇补齐
    final anchors = List<int>.from(_cache.keys);
    final expand = <int>{};
    for (final a in anchors) {
      for (var i = 1; i <= 10; i++) {
        if (a - i > 0) expand.add(a - i);
        expand.add(a + i);
      }
    }
    expand.removeAll(_cache.keys);
    for (final m in await _probeMany(expand.toList())) {
      _cache[m.bizId] = m;
    }

    await _writeCache();
    return _sortedCache();
  }

  // ── 内存缓存 ──
  final Map<int, LolMatch> _cache = <int, LolMatch>{};

  static const String _prefsKey = 'hupu_match_cache_v1';
  static const Duration _ttl = Duration(minutes: 20);

  int get _cacheMax =>
      _cache.isEmpty ? 0 : _cache.keys.reduce((a, b) => a > b ? a : b);

  /// 增量刷新：从已知最大号往上探 40、往下补 10
  Future<void> _refreshIncremental() async {
    final top = _cacheMax;
    if (top == 0) return;
    final ids = <int>[];
    for (var i = 1; i <= 40; i++) {
      ids.add(top + i);
    }
    for (var i = 1; i <= 10; i++) {
      if (top - i > 0) ids.add(top - i);
    }
    var changed = false;
    for (final m in await _probeMany(ids)) {
      _cache[m.bizId] = m;
      changed = true;
    }
    if (changed) await _writeCache();
  }

  List<LolMatch> _sortedCache() {
    final list = List<LolMatch>.from(_cache.values);
    list.sort((a, b) {
      final ta = a.matchTime;
      final tb = b.matchTime;
      if (ta != null && tb != null && ta != tb) return tb.compareTo(ta);
      return b.bizId.compareTo(a.bizId);
    });
    return list;
  }

  // ── 持久化 ──

  Future<({List<LolMatch> items, DateTime at})?> _readCache() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final atMs = decoded['at'];
      if (atMs is! int) return null;
      final at = DateTime.fromMillisecondsSinceEpoch(atMs);
      if (DateTime.now().difference(at) > _ttl) return null;
      final list = decoded['items'];
      if (list is! List) return null;
      final items = <LolMatch>[];
      for (final e in list) {
        if (e is Map<String, dynamic>) {
          final m = lolMatchFromCache(e);
          if (m != null) items.add(m);
        }
      }
      if (items.isEmpty) return null;
      return (items: items, at: at);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final payload = <String, dynamic>{
        'at': DateTime.now().millisecondsSinceEpoch,
        'items': _cache.values.map((m) => m.toCacheJson()).toList(),
      };
      await sp.setString(_prefsKey, jsonEncode(payload));
    } catch (_) {
      // 缓存失败不影响主流程
    }
  }

  /// 并发探测一批编号（14 路）
  Future<List<LolMatch>> _probeMany(List<int> ids) async {
    final out = <LolMatch>[];
    const batch = 14;
    for (var i = 0; i < ids.length; i += batch) {
      final end = (i + batch) > ids.length ? ids.length : i + batch;
      final chunk = ids.sublist(i, end);
      final results = await Future.wait(chunk.map(fetchMatch));
      for (final m in results) {
        if (m != null) out.add(m);
      }
    }
    return out;
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

  /// 拉取某条评论的**子回复**（楼中楼）
  ///
  /// 实测（2026-10-26）：`subCommentList` 返回 data=null，真正的楼中楼接口是 `getMore`：
  ///   GET bpl/comment/list/primarySingleRow/getMore
  ///       ?publishTime=<父评论 publishTime 或上一页 cursor>
  ///       &outBizNo=&outBizType=&queryType=asc&parentCommentId=<父评论id>
  ///       &pageSize=20&clientCode=&cid=
  Future<CommentPage> fetchSubComments({
    required String type,
    required String no,
    required int parentId,
    required int publishTime,
    int pageSize = 20,
  }) async {
    try {
      final json = await _client.getJson(
        '$apiBase/bpl/comment/list/primarySingleRow/getMore',
        query: {
          'publishTime': publishTime,
          'outBizNo': no,
          'outBizType': type,
          'queryType': 'asc',
          'parentCommentId': parentId,
          'pageSize': pageSize,
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
