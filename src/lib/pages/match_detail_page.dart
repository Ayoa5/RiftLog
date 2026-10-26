// 比赛详情页：BO 局切换 + 该局选手评分（红蓝方分组）
// 数据链：lol_match → (CHILD) 局列表 → (CHILD) 选手/教练评分

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../core/theme.dart';
import '../models/comment_models.dart';
import '../models/match_models.dart';
import '../models/rating_models.dart';

class MatchDetailPage extends ConsumerStatefulWidget {
  const MatchDetailPage({super.key, required this.match});

  final LolMatch match;

  @override
  ConsumerState<MatchDetailPage> createState() => _MatchDetailPageState();
}

class _MatchDetailPageState extends ConsumerState<MatchDetailPage> {
  int _gameIndex = 0;

  @override
  Widget build(BuildContext context) {
    final match = widget.match;
    final gamesAsync = ref.watch(gamesProvider(match.bizId));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          match.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          _MatchHeader(match: match),
          const SizedBox(height: 16),
          ...gamesAsync.when<List<Widget>>(
            data: (games) {
              if (games.isEmpty) {
                return <Widget>[
                  const _EmptyHint(text: '这场比赛还没有可用的评分数据'),
                ];
              }
              final idx = _gameIndex.clamp(0, games.length - 1);
              return <Widget>[
                if (games.length > 1) ...<Widget>[
                  Wrap(
                    spacing: 8,
                    children: List<Widget>.generate(games.length, (i) {
                      final sel = i == idx;
                      return ChoiceChip(
                        label: Text(games[i].name),
                        selected: sel,
                        onSelected: (_) => setState(() => _gameIndex = i),
                      );
                    }),
                  ),
                  const SizedBox(height: 14),
                ],
                _GameScores(gameId: games[idx].bizId, match: match),
              ];
            },
            loading: () => <Widget>[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (e, _) => <Widget>[
              _EmptyHint(text: '局数据加载失败\n$e'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MatchHeader extends StatelessWidget {
  const _MatchHeader({required this.match});

  final LolMatch match;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = match.matchTime;

    return Card.filled(
      margin: EdgeInsets.zero,
      shape: AppTheme.cardShape(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          children: <Widget>[
            Text(
              <String>[
                if (match.competition.isNotEmpty) match.competition,
                if (match.stage.isNotEmpty) match.stage,
              ].join(' · '),
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    match.homeTeam,
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    '${match.homeScore} : ${match.awayScore}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Expanded(
                  child: Text(
                    match.awayTeam,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              <String>[
                match.statusText,
                if (t != null)
                  '${t.month}月${t.day}日 '
                      '${t.hour.toString().padLeft(2, '0')}:'
                      '${t.minute.toString().padLeft(2, '0')}',
              ].join('  ·  '),
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// 某一局的选手评分（按 teamId 分组）
class _GameScores extends ConsumerWidget {
  const _GameScores({required this.gameId, required this.match});

  final int gameId;
  final LolMatch match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(gameScoresProvider(gameId));

    return async.when(
      data: (items) {
        final roster = items
            .where((e) => e.isPlayer || e.isCoach)
            .toList(growable: false);
        if (roster.isEmpty) {
          return const _EmptyHint(text: '这一局还没有评分');
        }

        // 按 teamId 分组，保持出现顺序
        final grouped = <String, List<ScoreItem>>{};
        for (final it in roster) {
          grouped.putIfAbsent(it.teamId, () => <ScoreItem>[]).add(it);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (final entry in grouped.entries) ...<Widget>[
              _TeamSection(
                teamId: entry.key,
                items: entry.value,
                match: match,
              ),
              const SizedBox(height: 14),
            ],
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _EmptyHint(text: '评分加载失败\n$e'),
    );
  }
}

class _TeamSection extends StatelessWidget {
  const _TeamSection({
    required this.teamId,
    required this.items,
    required this.match,
  });

  final String teamId;
  final List<ScoreItem> items;
  final LolMatch match;

  /// teamId → 队名：用比赛的 home/away 映射，查不到才退回原始 id
  String get _teamName {
    if (teamId.isNotEmpty && teamId == match.homeTeamId) return match.homeTeam;
    if (teamId.isNotEmpty && teamId == match.awayTeamId) return match.awayTeam;
    return '队伍 $teamId';
  }

  String get _teamLogo {
    if (teamId.isNotEmpty && teamId == match.homeTeamId) {
      return match.homeLogo;
    }
    if (teamId.isNotEmpty && teamId == match.awayTeamId) {
      return match.awayLogo;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sorted = List<ScoreItem>.from(items)
      ..sort((a, b) {
        if (a.isCoach != b.isCoach) return a.isCoach ? -1 : 1;
        return b.score.compareTo(a.score);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 4,
              height: 14,
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            if (_teamLogo.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: Image.network(
                      _teamLogo,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            Flexible(
              child: Text(
                _teamName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${sorted.length} 人',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...sorted.map(
          (e) => GestureDetector(
            onTap: () => _showComments(context, e),
            child: _ScoreRow(item: e),
          ),
        ),
      ],
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({required this.item});

  final ScoreItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = AppTheme.scoreColors(cs, item.score);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Card.filled(
        margin: EdgeInsets.zero,
        shape: AppTheme.cardShape(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (item.isCoach)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: cs.tertiaryContainer,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '教练',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: cs.onTertiaryContainer,
                                      fontSize: 10,
                                    ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      <String>[
                        if (item.kda.isNotEmpty) 'KDA ${item.kda}',
                        '${item.votes} 人打分',
                      ].join(' · '),
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: c.bg,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  item.score.toStringAsFixed(1),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: c.fg,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: <Widget>[
          Icon(Icons.inbox_outlined, size: 40, color: cs.outline),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// 打开某位选手的评论区
void _showComments(BuildContext context, ScoreItem item) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _CommentsSheet(item: item),
  );
}

/// 评论区
///
/// 实测（2026-10-26）虎扑三种排序走不同接口：
///   最亮 → primarySingleRow/hottest（裸数组，约 50 条，按亮数降序）
///   最晚 → primarySingleRow?order=desc&publishTime=<当前时间ms>
///   最早 → primarySingleRow?order=asc&publishTime=0
/// 翻页：把上一页的 cursor.publishTime 作为下一轮 publishTime 传回。
class _CommentsSheet extends ConsumerStatefulWidget {
  const _CommentsSheet({required this.item});

  final ScoreItem item;

  @override
  ConsumerState<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<_CommentsSheet> {
  CommentSort _sort = CommentSort.brightest;

  final List<HupuComment> _items = <HupuComment>[];
  int? _cursor;
  bool _hasMore = false;
  bool _loading = false;
  String? _error;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _items.clear();
        _cursor = null;
        _hasMore = false;
        _total = 0;
      }
    });

    try {
      final page = await ref.read(matchServiceProvider).fetchComments(
            type: 'lol_item',
            no: widget.item.bizId.toString(),
            sort: _sort,
            cursor: _cursor,
          );
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
        if (reset) _total = page.total;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeSort(CommentSort s) {
    if (s == _sort) return;
    setState(() => _sort = s);
    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      maxChildSize: 0.95,
      builder: (ctx, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: <Widget>[
          // 标题
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${widget.item.name} 的评论',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              if (_total > 0)
                Text(
                  '共 $_total 条',
                  style: Theme.of(ctx)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // 排序：最亮 / 最晚 / 最早
          Row(
            children: <Widget>[
              for (final s in CommentSort.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(s.label),
                    selected: _sort == s,
                    onSelected: (_) => _changeSort(s),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  '评论加载失败\n$_error',
                  textAlign: TextAlign.center,
                  style: Theme.of(ctx)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ),

          if (_items.isEmpty && _loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            ),

          if (_items.isEmpty && !_loading && _error == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  '还没有评论',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
            ),

          for (final c in _items) _CommentTile(comment: c),

          // 加载更多
          if (_hasMore)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Center(
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : FilledButton.tonal(
                        onPressed: () => _load(),
                        child: const Text('加载更多'),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});

  final HupuComment comment;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card.outlined(
        margin: EdgeInsets.zero,
        shape: AppTheme.cardShape(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ClipOval(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: comment.userHead.isEmpty
                      ? Container(color: cs.surfaceContainerHighest)
                      : Image.network(
                          comment.userHead,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Container(color: cs.surfaceContainerHighest),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            comment.userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        if (comment.score > 0) ...<Widget>[
                          const SizedBox(width: 6),
                          Text(
                            '${comment.score} 分',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: cs.primary),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      comment.content,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(height: 1.45),
                    ),
                    if (comment.hasImage) ...<Widget>[
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          comment.images.first,
                          height: 90,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const SizedBox.shrink(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: <Widget>[
                        Text(
                          <String>[
                            if (comment.dateText.isNotEmpty) comment.dateText,
                            if (comment.ipLocation.isNotEmpty)
                              comment.ipLocation,
                          ].join(' · '),
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                        const Spacer(),
                        Icon(Icons.thumb_up_alt_outlined,
                            size: 13, color: cs.onSurfaceVariant),
                        const SizedBox(width: 3),
                        Text(
                          '${comment.lightCount}',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
