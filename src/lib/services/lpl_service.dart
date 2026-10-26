// LPL 官方赛程服务
//
// 数据来源（实测 2026-10-26）：腾讯 LPL 官网的**静态 JSON 文件**，无需签名/登录
//   GET https://lpl.qq.com/web201612/data/LOL_MATCH2_MATCH_HOMEPAGE_BMATCH_LIST_{gameId}.js
//
// 为什么用它：
//   虎扑的评分体系只有「已开赛/已结束」的比赛节点（实测 4516 之后全空），
//   拿不到赛前预告；LPL 官网的赛程文件里**含未开赛的比赛**（含明天/后天对阵）。
//
// gameId 说明：
//   246 = 2026 全球总决赛（实测 46 场）
//   赛事列表在 LOL_MATCH2_GAME_LIST_BRIEF.js（GameId/GameName），
//   换赛季时需要更新 [_gameIds]。

import 'dart:convert';

import '../models/lpl_models.dart';
import 'hupu_client.dart';

class LplScheduleService {
  LplScheduleService({HupuClient? client}) : _client = client ?? HupuClient();

  final HupuClient _client;

  static const String _base =
      'https://lpl.qq.com/web201612/data/LOL_MATCH2_MATCH_HOMEPAGE_BMATCH_LIST_';

  /// 当前关注的赛事 id（2026 全球总决赛）。
  /// 若要同时显示 LPL 联赛，可再加其它 id（可从 GAME_LIST_BRIEF 里查）。
  static const List<int> _gameIds = <int>[246];

  /// 拉取赛程：返回按时间倒序的全部比赛（含未开赛）
  Future<List<LplMatch>> fetchAll() async {
    final all = <LplMatch>[];
    for (final gid in _gameIds) {
      try {
        final raw = await _client.getHtml('$_base$gid.js');
        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic>) continue;
        if ((decoded['status']?.toString() ?? '0') != '0') continue;
        final list = decoded['msg'];
        if (list is! List) continue;
        for (final e in list) {
          if (e is Map<String, dynamic>) {
            final m = LplMatch.fromJson(e);
            if (m != null) all.add(m);
          }
        }
      } catch (_) {
        // 单个赛事失败不影响其它
      }
    }
    all.sort((a, b) {
      final da = a.date, db = b.date;
      if (da != null && db != null) return db.compareTo(da);
      return b.matchId.compareTo(a.matchId);
    });
    return all;
  }

  /// 只看未开赛（按时间升序，最近的在前）
  static List<LplMatch> upcoming(List<LplMatch> all) {
    final list = all.where((m) => m.isUpcoming).toList();
    list.sort((a, b) {
      final da = a.date, db = b.date;
      if (da != null && db != null) return da.compareTo(db);
      return a.matchId.compareTo(b.matchId);
    });
    return list;
  }

  /// 只看已结束
  static List<LplMatch> finished(List<LplMatch> all) =>
      all.where((m) => m.isFinished).toList();
}
