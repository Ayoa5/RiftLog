// 比赛详情页：BO 局切换 + 该局选手评分（红蓝方分组）
// 数据链：lol_match → (CHILD) 局列表 → (CHILD) 选手/教练评分

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../core/theme.dart';
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
                _GameScores(gameId: games[idx].bizId),
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
  const _GameScores({required this.gameId});

  final int gameId;

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
              _TeamSection(teamId: entry.key, items: entry.value),
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
  const _TeamSection({required this.teamId, required this.items});

  final String teamId;
  final List<ScoreItem> items;

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
            Text(
              '队伍 $teamId',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const Spacer(),
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
        ...sorted.map((e) => _ScoreRow(item: e)),
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
