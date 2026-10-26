// 虎扑「评分」数据服务（免登录，实测可用）
//
// 接口族（baseURL 来自 detail.js 的 axios 实例，浏览器环境会拼上 /1/8.2.99）：
//   base = https://games.mobileapi.hupu.com/1/8.2.99/bplcommentapi
//
//   1) GET bpl/score_tree/getSelfByBizKey?outBizType=&outBizNo=
//        → data.nodeId / data.linkNodes[]（含父级，如「第1局」lol_bo:7717）
//   2) GET bpl/score_tree/getCurAndSubNodeByBizKey?relation=CHILD&page=1&pageSize=30&outBizType=&outBizNo=
//        → data.self.node（当前节点）+ data.pageResult.data[]（子节点=选手/教练/BP英雄/解说）
//
// 实测结论：
//   · 无需登录、无需 Cookie，只需移动端 UA（带 Referer 更稳）
//   · 选手级 bizKey（lol_item:79822）能拿到 scoreAvg=2.4、scorePersonCount=23604
//   · 局级 bizKey（lol_bo:7717）能一次拿到 24 条：选手 10 + 教练 2 + BP英雄 2 + 解说主持等
//   · 选手级没有子节点（subNodeCount=0），所以要先反查出所属「局」的 bizKey

import '../models/rating_models.dart';
import 'hupu_client.dart';

class HupuRatingService {
  HupuRatingService({HupuClient? client}) : _client = client ?? HupuClient();

  final HupuClient _client;

  /// 实测 prod baseURL（浏览器环境会自动拼 /1/<appVersion>）
  static const String apiBase =
      'https://games.mobileapi.hupu.com/1/8.2.99/bplcommentapi';

  /// 从评分页 URL 解析出 outBizType / outBizNo
  /// 例：https://m.hupu.com/score/detail.html?outBizType=lol_item&outBizNo=79822
  static ({String type, String no})? parseScoreUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return null;
    final t = uri.queryParameters['outBizType'];
    final n = uri.queryParameters['outBizNo'];
    if (t == null || n == null || t.isEmpty || n.isEmpty) return null;
    return (type: t, no: n);
  }

  /// 主入口：给一个评分页 URL 或 (type,no)，返回整场评分
  ///
  /// 逻辑：
  ///   1. 若拿到的是选手级（lol_item），先 getSelfByBizKey 反查它所属的「局」（lol_bo）
  ///   2. 用「局」级 bizKey 调 getCurAndSubNodeByBizKey 拿全阵容
  ///   3. 拿不到父级就退回用原 bizKey（至少能显示单个人）
  Future<RatingBundle> load({
    required String outBizType,
    required String outBizNo,
  }) async {
    var type = outBizType;
    var no = outBizNo;

    // 选手级 → 反查所属局
    if (type != 'lol_bo') {
      final parent = await _findGameBizKey(type, no);
      if (parent != null) {
        type = parent.$1;
        no = parent.$2;
      }
    }

    return _fetchChildren(type, no);
  }

  /// 便捷方法：直接传评分页 URL
  Future<RatingBundle> loadFromUrl(String url) async {
    final key = parseScoreUrl(url);
    if (key == null) {
      throw HupuException('URL 里没有 outBizType / outBizNo，不是评分页链接');
    }
    return load(outBizType: key.type, outBizNo: key.no);
  }

  // ───────────────────────── 内部实现 ─────────────────────────

  /// 从 linkNodes 里找出所属的 lol_bo（局）
  Future<(String, String)?> _findGameBizKey(String type, String no) async {
    try {
      final json = await _client.getJson(
        '$apiBase/bpl/score_tree/getSelfByBizKey',
        query: {'outBizType': type, 'outBizNo': no},
        okCodes: const {1},
      );
      final data = (json['data'] as Map?)?.cast<String, dynamic>();
      if (data == null) return null;

      final links = data['linkNodes'];
      if (links is List) {
        for (final e in links) {
          if (e is! Map) continue;
          final bizKey = (e['outBizKey'] as Map?)?.cast<String, dynamic>();
          if (bizKey == null) continue;
          final t = asString(bizKey['outBizType']);
          final n = asString(bizKey['outBizNo']);
          if (t.isNotEmpty && n.isNotEmpty) return (t, n);
        }
      }
    } catch (_) {
      // 反查失败就用原 bizKey
    }
    return null;
  }

  Future<RatingBundle> _fetchChildren(String type, String no) async {
    final json = await _client.getJson(
      '$apiBase/bpl/score_tree/getCurAndSubNodeByBizKey',
      query: {
        'relation': 'CHILD',
        'page': 1,
        'pageSize': 30,
        'outBizType': type,
        'outBizNo': no,
      },
      okCodes: const {1},
    );

    final data = (json['data'] as Map?)?.cast<String, dynamic>() ?? const {};
    final selfNode =
        ((data['self'] as Map?)?['node'] as Map?)?.cast<String, dynamic>() ??
            const {};
    final pageResult =
        (data['pageResult'] as Map?)?.cast<String, dynamic>() ?? const {};
    final rawList = pageResult['data'];

    final items = <ScoreItem>[];
    if (rawList is List) {
      for (final e in rawList) {
        if (e is Map<String, dynamic>) {
          final it = ScoreItem.fromNode(e);
          if (it.name.isNotEmpty) items.add(it);
        }
      }
    }

    // 若没有子节点（选手级），把自身也放进列表
    if (items.isEmpty && asString(selfNode['name']).isNotEmpty) {
      items.add(
        ScoreItem.fromNode(<String, dynamic>{
          'nodeId': selfNode['nodeId'],
          'node': selfNode,
        }),
      );
    }

    final hot = selfNode['hottestComments'];
    final comments = <String>[];
    if (hot is List) {
      for (final c in hot) {
        final s = asString(c);
        if (s.isNotEmpty) comments.add(s);
      }
    }

    return RatingBundle(
      title: asString(selfNode['name']),
      items: items,
      comments: comments,
      outBizType: type,
      outBizNo: no,
    );
  }
}

/// 便于外部传参的错误类型复用
class RatingRequestException implements Exception {
  RatingRequestException(this.message);

  final String message;

  @override
  String toString() => message;
}
