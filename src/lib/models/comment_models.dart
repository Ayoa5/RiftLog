// 虎扑评分评论模型
//
// 来源（实测）：
//   GET .../bplcommentapi/bpl/comment/list
//       ?outBizType=lol_item&outBizNo=79822&publishTime=0&order=HOT&page=1&pageSize=20
//   → data.comments[] / commentCount / hasMore / cursor
//
// ⚠️ 实测：评论挂在 **选手节点（lol_item）** 上（Gumayusi 有 4688 条）；
//    比赛（lol_match）与局（lol_bo）的 commentCount 均为 0。
//    所以「每场比赛的评论」实际要按选手拉取。

class HupuComment {
  const HupuComment({
    required this.id,
    required this.userName,
    required this.userHead,
    required this.content,
    required this.images,
    required this.dateText,
    required this.lightCount,
    required this.score,
    required this.ipLocation,
    required this.occasion,
    required this.subCount,
    required this.publishTime,
  });

  final String id;
  final String userName;
  final String userHead;
  final String content;

  /// 评论配图（原文 commentContentImages，可能为 null / 字符串数组 / 对象数组）
  final List<String> images;
  final String dateText;
  final int lightCount;

  /// 该用户给这个选手打的分（0 表示未打分）
  final int score;
  final String ipLocation;

  /// 如「发布于比赛中」
  final String occasion;

  /// 子回复数量（楼中楼），>0 时可展开
  final int subCount;

  /// 发布时间戳（ms），拉子回复时作为 publishTime 游标
  final int publishTime;

  bool get hasImage => images.isNotEmpty;

  static HupuComment fromJson(Map<String, dynamic> j) {
    final raw = j['commentContentImages'];
    final imgs = <String>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is String) {
          if (e.startsWith('http')) imgs.add(e);
        } else if (e is Map) {
          final u = e['url'] ?? e['imageUrl'] ?? e['src'];
          if (u is String && u.startsWith('http')) imgs.add(u);
        }
      }
    }

    return HupuComment(
      id: (j['commentId'] ?? '').toString(),
      userName: (j['commentUserName'] ?? '匿名').toString(),
      userHead: (j['commentUserHeadImg'] ?? '').toString(),
      content: (j['commentContent'] ?? '').toString(),
      images: imgs,
      dateText: (j['commentDate'] ?? '').toString(),
      lightCount: _i(j['lightCount']),
      score: _i(j['score']),
      ipLocation: (j['ipLocation'] ?? '').toString(),
      occasion: (j['commentOccasionText'] ?? '').toString(),
      subCount: _i(j['subCommentCount'] ?? j['descendantCount']),
      publishTime: _i(j['publishTime']),
    );
  }

  static int _i(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}

/// 一页评论
class CommentPage {
  const CommentPage({
    required this.items,
    required this.total,
    required this.hasMore,
    this.nextCursor,
  });

  final List<HupuComment> items;
  final int total;
  final bool hasMore;

  /// 下一页游标（服务端的 cursor.publishTime）
  final int? nextCursor;

  bool get isEmpty => items.isEmpty;
}

/// 评论排序方式 —— 对应虎扑评分页的三个 tab
///
/// 实测（2026-10-26）三者走的参数/接口完全不同：
///   最亮 = GET primarySingleRow/hottest（返回数组，50 条，按亮数降序）
///   最晚 = GET primarySingleRow?order=desc&publishTime=<当前ms>
///   最早 = GET primarySingleRow?order=asc&publishTime=0
enum CommentSort {
  brightest('最亮'),
  latest('最晚'),
  earliest('最早');

  const CommentSort(this.label);

  final String label;
}

/// 评论查询参数（作为 Riverpod family 的 key，需要值相等语义）
class CommentQuery {
  const CommentQuery({
    required this.type,
    required this.no,
    this.sort = CommentSort.brightest,
  });

  final String type;
  final String no;
  final CommentSort sort;

  @override
  bool operator ==(Object other) =>
      other is CommentQuery &&
      other.type == type &&
      other.no == no &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(type, no, sort);
}
