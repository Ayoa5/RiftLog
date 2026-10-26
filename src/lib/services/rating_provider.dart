// 评分数据源抽象层
//
// 现状（2026-10-26 实测）：
//   虎扑 App 内的「评分」是原生交互模块，H5 侧未暴露公开 JSON 端点
//   （/api/v2/lights、/api/v2/score、/api/v2/ratings … 共 7 个候选路径全部 404）。
//
// 因此这里做成可插拔：先尝试从帖子正文内嵌结构里抠，抠不到就返回空列表，
// UI 侧自动隐藏评分区（降级），不抛异常、不空指针。
// 等拿到真实赛后帖样本 / 抓包结果，只需实现并注册一个新的 RatingProvider。

import 'dart:convert';

import '../models/hupu_models.dart';

abstract class RatingProvider {
  Future<List<PlayerRating>> load({
    required int tid,
    required String contentHtml,
  });
}

/// 空实现：保证评分源未确认时功能可用（只是不显示评分）
class NullRatingProvider implements RatingProvider {
  const NullRatingProvider();

  @override
  Future<List<PlayerRating>> load({
    required int tid,
    required String contentHtml,
  }) async =>
      const [];
}

/// 从帖子正文 HTML 里找内嵌评分结构。
///
/// 保守策略：只认显式标记，不做「9.8 分」这类模糊文本匹配——
/// 那种会把正文里的「三局比分 9-8」等误判成评分。
class ContentRatingProvider implements RatingProvider {
  const ContentRatingProvider();

  /// 形如 data-rating="[...]" / data-ratings="{...}"
  static final RegExp _attrJson = RegExp(
    r'''data-ratings?\s*=\s*["']([\[{].{2,6000}?[\]}])["']''',
    caseSensitive: false,
    dotAll: true,
  );

  /// 形如 window.__RATING__ = {...}; / window.scoreData = [...]
  static final RegExp _scriptJson = RegExp(
    r'''(?:window\.__RATING__|window\.scoreData|__PLAYER_RATINGS__)\s*=\s*([\[{].{2,8000}?[\]}])\s*;''',
    caseSensitive: false,
    dotAll: true,
  );

  @override
  Future<List<PlayerRating>> load({
    required int tid,
    required String contentHtml,
  }) async {
    for (final re in [_scriptJson, _attrJson]) {
      final m = re.firstMatch(contentHtml);
      if (m == null) continue;
      final list = _tryParse(m.group(1)!);
      if (list.isNotEmpty) return list;
    }
    return const [];
  }

  List<PlayerRating> _tryParse(String raw) {
    // HTML 实体还原：&quot; → "
    final text = raw
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&amp;', '&');
    try {
      final decoded = jsonDecode(text);
      final items = <Map<String, dynamic>>[];
      if (decoded is List) {
        for (final e in decoded) {
          if (e is Map<String, dynamic>) items.add(e);
        }
      } else if (decoded is Map<String, dynamic>) {
        final players = decoded['players'] ?? decoded['ratings'] ?? decoded['list'];
        if (players is List) {
          for (final e in players) {
            if (e is Map<String, dynamic>) items.add(e);
          }
        }
      }
      return items
          .map(PlayerRating.fromJson)
          .where((r) => r.name.isNotEmpty && r.score > 0)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
}

/// 多源链：按顺序尝试，第一个返回非空结果的胜出。
/// 后续接入真实评分接口时，把它插到链头即可，UI 无需改动。
class RatingProviderChain implements RatingProvider {
  RatingProviderChain(this.providers);

  final List<RatingProvider> providers;

  @override
  Future<List<PlayerRating>> load({
    required int tid,
    required String contentHtml,
  }) async {
    for (final p in providers) {
      try {
        final r = await p.load(tid: tid, contentHtml: contentHtml);
        if (r.isNotEmpty) return r;
      } catch (_) {
        // 单一来源失败不影响整条链
      }
    }
    return const [];
  }
}
