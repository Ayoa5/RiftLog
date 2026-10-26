// 虎扑数据抓取与解析（Step 2 核心）
//
// 两个已实测的真实数据源（详见 docs/虎扑接口实测记录_20261026.md）：
//   1) 板块列表：GET https://bbs.hupu.com/{zone}  →  SSR 的 __NEXT_DATA__
//      props.pageProps.postList.topicThreads[] = { tid, title, replies, recommendNum, username, time }
//   2) 帖子详情：GET https://bbs.hupu.com/api/v2/threads?tid={tid}
//      data.thread  = { tid, title, content(HTML), lights, replies, createdAt, createdAtFormat, author{...} }
//      data.lights  = 「这些回复亮了」高赞评论
//      data.replies.list = 普通回复（无亮点时会作为亮评的退路数据源）

import 'dart:convert';

import 'package:html/parser.dart' as html_parser;

import '../models/hupu_models.dart';
import 'hupu_client.dart';
import 'rating_provider.dart';

class HupuScraperService {
  HupuScraperService({HupuClient? client, RatingProvider? ratingProvider})
      : _client = client ?? HupuClient(),
        _ratingProvider = ratingProvider ??
            RatingProviderChain(const [ContentRatingProvider()]);

  final HupuClient _client;
  final RatingProvider _ratingProvider;

  static const String zoneBase = 'https://bbs.hupu.com';
  static const String apiBase = 'https://bbs.hupu.com';

  // ───────────────────────── 板块列表 ─────────────────────────

  /// 拉取某板块首屏帖子。zone 例：lol（英雄联盟）
  ///
  /// 翻页：SSR 里带 `nextCursor`，但 `?cursor=` 参数**未实测**；
  /// 若服务端不支持，会返回同一批数据（不会报错），调用方按需去重即可。
  Future<List<HupuThread>> fetchZoneThreads({
    String zone = 'lol',
    int? cursor,
  }) async {
    final url = cursor == null ? '$zoneBase/$zone' : '$zoneBase/$zone?cursor=$cursor';
    final html = await _client.getHtml(url);

    final nextData = extractNextData(html);
    if (nextData == null) {
      throw HupuException(
        '未找到 __NEXT_DATA__：可能是 UA 不含移动端特征，或虎扑改了页面结构',
      );
    }

    final pageProps = _mapAt(nextData, const ['props', 'pageProps']);
    final postList = pageProps?['postList'];
    if (postList is! Map) return const [];

    final threads = postList['topicThreads'];
    if (threads is! List) return const [];

    return threads
        .whereType<Map<String, dynamic>>()
        .map(HupuThread.fromJson)
        .where((t) => t.tid > 0 && t.title.isNotEmpty)
        .toList(growable: false);
  }

  /// 从列表中筛出「赛后」帖（有评分的通常是这类）
  static List<HupuThread> postMatchOnly(List<HupuThread> all) =>
      all.where((t) => t.isPostMatch).toList(growable: false);

  // ───────────────────────── 帖子详情 + 亮评 ─────────────────────────

  Future<ThreadBundle> fetchThreadBundle(int tid) async {
    final data = await _fetchThreadData(tid);

    final threadJson = (data['thread'] as Map?)?.cast<String, dynamic>();
    if (threadJson == null) {
      throw HupuException('接口未返回 thread 字段（tid=$tid）');
    }
    final detail = ThreadDetail.fromJson(threadJson);

    final lights = _parseLights(data);

    // 评分：可能为空（数据源待锁），UI 会自动降级
    var ratings = const <PlayerRating>[];
    try {
      ratings = await _ratingProvider.load(
        tid: tid,
        contentHtml: detail.contentHtml,
      );
    } catch (_) {
      ratings = const [];
    }

    return ThreadBundle(detail: detail, lights: lights, ratings: ratings);
  }

  Future<Map<String, dynamic>> _fetchThreadData(int tid) async {
    final json = await _client.getJson(
      '$apiBase/api/v2/threads',
      query: {'tid': tid},
    );
    final data = json['data'];
    if (data is! Map<String, dynamic>) {
      throw HupuException('接口 data 字段异常（tid=$tid）');
    }
    return data;
  }

  /// 亮评解析：优先 data.lights；为空时退回 replies.list 里 lightCount>0 的条目
  List<LightReply> _parseLights(Map<String, dynamic> data) {
    final out = <LightReply>[];

    final lights = data['lights'];
    if (lights is List) {
      for (final e in lights) {
        if (e is Map<String, dynamic>) {
          final r = LightReply.fromJson(e);
          if (r.content.isNotEmpty) out.add(r);
        }
      }
    }

    if (out.isEmpty) {
      final replies = (data['replies'] as Map?)?['list'];
      if (replies is List) {
        for (final e in replies) {
          if (e is Map<String, dynamic>) {
            final r = LightReply.fromJson(e);
            if (r.content.isNotEmpty && r.lightCount > 0) out.add(r);
          }
        }
      }
    }

    // 亮数高的排前面，最多留 10 条
    out.sort((a, b) => b.lightCount.compareTo(a.lightCount));
    return out.length > 10 ? out.sublist(0, 10) : out;
  }

  // ───────────────────────── 工具方法 ─────────────────────────

  /// 提取 Next.js 的 __NEXT_DATA__ JSON
  static Map<String, dynamic>? extractNextData(String html) {
    final m = RegExp(
      r'<script[^>]+id="__NEXT_DATA__"[^>]*>([\s\S]*?)</script>',
      caseSensitive: false,
    ).firstMatch(html);
    if (m == null) return null;
    try {
      final decoded = jsonDecode(m.group(1)!);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// 安全按路径取 Map
  static Map<String, dynamic>? _mapAt(
    Map<String, dynamic> root,
    List<String> path,
  ) {
    Object? cur = root;
    for (final key in path) {
      if (cur is! Map) return null;
      cur = cur[key];
    }
    return cur is Map<String, dynamic> ? cur : null;
  }

  /// 正文 HTML → 纯文本（用于预览、搜索关键词）
  static String plainTextOf(String html) {
    if (html.isEmpty) return '';
    try {
      final doc = html_parser.parse(html);
      final text = doc.body?.text ?? '';
      return text.replaceAll(RegExp(r'\s+'), ' ').trim();
    } catch (_) {
      // 解析失败时退回粗暴去标签
      return html.replaceAll(RegExp(r'<[^>]+>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    }
  }

  /// 提取正文里的图片地址（M3 卡片里可做横向图片条）
  static List<String> imageUrlsOf(String html) {
    if (html.isEmpty) return const [];
    try {
      final doc = html_parser.parse(html);
      return doc
          .querySelectorAll('img')
          .map((e) => e.attributes['src'] ?? e.attributes['data-src'] ?? '')
          .where((s) => s.startsWith('http'))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
}
