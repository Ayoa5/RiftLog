// 赛程页：真实比赛列表（虎扑 lol_match 节点）
// 点卡片 → 比赛详情（BO 局切换 + 选手评分）

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../core/theme.dart';
import '../models/match_models.dart';
import 'match_detail_page.dart';

class SchedulePage extends ConsumerWidget {
  const SchedulePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(scheduleProvider);
    final cs = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(scheduleProvider);
        await ref.read(scheduleProvider.future);
      },
      child: CustomScrollView(
        slivers: <Widget>[
          const SliverAppBar.large(title: Text('赛程')),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Row(
                children: <Widget>[
                  Icon(Icons.sports_esports_outlined,
                      size: 18, color: cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '虎扑 · 英雄联盟赛事（实时）',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ...async.when<List<Widget>>(
            data: (matches) {
              if (matches.isEmpty) {
                return <Widget>[
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _Hint(
                      icon: Icons.event_busy_outlined,
                      text: '暂时没有找到比赛\n下拉刷新试试',
                      action: FilledButton.tonalIcon(
                        onPressed: () => ref.invalidate(scheduleProvider),
                        icon: const Icon(Icons.refresh),
                        label: const Text('重新探测'),
                      ),
                    ),
                  ),
                ];
              }

              // 按日期分组（discover 已按时间倒序）
              final groups = <String, List<LolMatch>>{};
              for (final m in matches) {
                groups.putIfAbsent(m.dateLabel, () => <LolMatch>[]).add(m);
              }

              final slivers = <Widget>[];
              groups.forEach((label, list) {
                slivers.add(
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 16, 6),
                      child: Text(
                        label,
                        style:
                            Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: cs.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                    ),
                  ),
                );
                slivers.add(
                  SliverList.builder(
                    itemCount: list.length,
                    itemBuilder: (ctx, i) => _MatchCard(match: list[i]),
                  ),
                );
              });
              slivers.add(
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              );
              return slivers;
            },
            loading: () => <Widget>[
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (e, _) => <Widget>[
              SliverFillRemaining(
                hasScrollBody: false,
                child: _Hint(
                  icon: Icons.cloud_off_outlined,
                  text: '加载失败\n$e',
                  action: FilledButton.tonalIcon(
                    onPressed: () => ref.invalidate(scheduleProvider),
                    icon: const Icon(Icons.refresh),
                    label: const Text('重试'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.match});

  final LolMatch match;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = match.matchTime;
    final timeText = t == null
        ? ''
        : '${t.hour.toString().padLeft(2, '0')}:'
            '${t.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Card.filled(
        margin: EdgeInsets.zero,
        shape: AppTheme.cardShape(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => MatchDetailPage(match: match),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: cs.secondaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        <String>[
                          if (match.competition.isNotEmpty) match.competition,
                          if (match.stage.isNotEmpty) match.stage,
                        ].join(' · '),
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: cs.onSecondaryContainer),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      <String>[
                        match.statusText,
                        if (timeText.isNotEmpty) timeText,
                      ].join('  '),
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _Team(
                        name: match.homeTeam,
                        logo: match.homeLogo,
                        alignEnd: false,
                        winner: match.winnerName == match.homeTeam,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        '${match.homeScore} : ${match.awayScore}',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Expanded(
                      child: _Team(
                        name: match.awayTeam,
                        logo: match.awayLogo,
                        alignEnd: true,
                        winner: match.winnerName == match.awayTeam,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Team extends StatelessWidget {
  const _Team({
    required this.name,
    required this.logo,
    required this.alignEnd,
    required this.winner,
  });

  final String name;
  final String logo;
  final bool alignEnd;
  final bool winner;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final label = Flexible(
      child: Text(
        name.isEmpty ? '待定' : name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: alignEnd ? TextAlign.end : TextAlign.start,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: winner ? FontWeight.w700 : FontWeight.w500,
              color: winner ? cs.primary : cs.onSurface,
            ),
      ),
    );
    final avatar = _Logo(url: logo);

    return Row(
      mainAxisAlignment:
          alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: alignEnd
          ? <Widget>[label, const SizedBox(width: 8), avatar]
          : <Widget>[avatar, const SizedBox(width: 8), label],
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 28,
        height: 28,
        child: url.isEmpty
            ? Container(color: cs.surfaceContainerHighest)
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(color: cs.surfaceContainerHighest),
              ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 48, color: cs.outline),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            if (action != null) ...<Widget>[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
