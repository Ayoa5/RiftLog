// 评论富文本 → 纯文本工具
//
// 2026-11-15：社区（板块帖子流 / 帖子详情）功能已移除，
// 原来的 fetchZoneThreads / fetchThreadBundle / 亮评解析全部随之删除。
// 现在只保留评论区需要的纯文本转换（match_detail_page 用它渲染虎扑评论）。

import 'package:html/parser.dart' as html_parser;

class HupuScraperService {
  const HupuScraperService();

  /// 正文 HTML → 纯文本
  static String plainTextOf(String html) {
    if (html.isEmpty) return '';
    try {
      final doc = html_parser.parse(html);
      final text = doc.body?.text ?? '';
      return text.replaceAll(RegExp(r'\s+'), ' ').trim();
    } catch (_) {
      // 解析失败时退回粗暴去标签
      return html
          .replaceAll(RegExp(r'<[^>]+>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }
  }

  /// 评论/亮评 HTML → 纯文本：直接去标签，`<img>`（虎扑表情 / 网络表情包）一并丢弃，
  /// 不保留任何占位文字——表情来源混杂无法统一渲染（2026-11-07 决策）。
  static String commentPlainText(String html) => plainTextOf(html);
}
