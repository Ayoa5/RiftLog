// 赛程页
//
// 数据来源分两路，各自负责它擅长的部分：
//   · 预告（未开赛）→ LPL 官网静态赛程（含未来对阵/时间/赛制）
//     虎扑没有未开赛的比赛节点，实测 4516 之后全空，所以预告只能走 LPL。
//   · 战报（已结束）→ LPL 赛程里列全，再按「队伍+日期」匹配虎扑比赛节点，
//     匹配到的可点进详情看选手评分；匹配不到显示「暂无评分」。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../core/theme.dart';
import '../models/lpl_models.dart';
import '../models/match_models.dart';
import '../services/lpl_service.dart';
import 'match_detail_page.dart';

class SchedulePage extends ConsumerWidget {
  const SchedulePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lplAsync = ref.watch(lplScheduleProvider);
    // 虎扑比赛：用于给「已结束」行挂上评分入口（拿不到也不影响展示）
    final hupuMatches = ref.watch(scheduleProvider).valueOrNull ??
        const <LolMatch>[];
    final cs = Theme.of(context).colorScheme;

    final hupuIndex = <String, LolMatch>{};
    for (final m in hupuMatches) {
      final k = _hupuKey(m);
      if (k.isNotEmpty) hupuIndex[k] = m;
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(lplScheduleProvider);
        ref.invalidate(scheduleProvider);
      },
      child: CustomScrollView(
        slivers: <Widget>[
          const SliverAppBar.large(title: Text('赛程')),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Row(
                children: <Widget>[
                  Icon(Icons.sports_esports_outlined,
                      size: 18, color: cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '英雄联盟赛事 · 预告来自官方赛程，战报评分来自虎扑',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ...lplAsync.when<List<Widget>>(
            data: (all) {
              if (all.isEmpty) {
                return <Widget>[
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _Hint(
                      icon: Icons.event_busy_outlined,
                      text: '没有拿到赛程\n下拉刷新试试',
                      action: FilledButton.tonalIcon(
                        onPressed: () => ref.invalidate(lplScheduleProvider),
                        icon: const Icon(Icons.refresh),
                        label: const Text('重新加载'),
                      ),
                    ),
                  ),
                ];
              }

              final upcoming = LplScheduleService.upcoming(all);
              final finished = LplScheduleService.finished(all);
              final slivers = <Widget>[];

              if (upcoming.isNotEmpty) {
                slivers.add(_sectionHeader(context, '即将开始', '${upcoming.length} 场'));
                slivers.add(
                  SliverList.builder(
                    itemCount: upcoming.length,
                    itemBuilder: (ctx, i) => _UpcomingRow(
                      match: upcoming[i],
                      showDate: i == 0 ||
                          upcoming[i].dateLabel != upcoming[i - 1].dateLabel,
                    ),
                  ),
                );
              }

              if (finished.isNotEmpty) {
                slivers.add(_sectionHeader(context, '已结束', '${finished.length} 场'));
                slivers.add(
                  SliverList.builder(
                    itemCount: finished.length,
                    itemBuilder: (ctx, i) {
                      final m = finished[i];
                      final hupu = hupuIndex[m.joinKey];
                      return _FinishedRow(
                        match: m,
                        hupuMatch: hupu,
                        showDate: i == 0 ||
                            finished[i].dateLabel !=
                                finished[i - 1].dateLabel,
                      );
                    },
                  ),
                );
              }

              slivers.add(
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
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
                  text: '赛程加载失败\n$e',
                  action: FilledButton.tonalIcon(
                    onPressed: () => ref.invalidate(lplScheduleProvider),
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


  /// 虎扑比赛的匹配键：队名排序 + 日期
  static String _hupuKey(LolMatch m) {
    final teams = <String>[m.homeTeam.toUpperCase(), m.awayTeam.toUpperCase()]
      ..removeWhere((e) => e.isEmpty)
      ..sort();
    if (teams.length < 2) return '';
    final t = m.matchTime;
    if (t == null) return '';
    final day = '${t.year}-${t.month.toString().padLeft(2, '0')}-'
        '${t.day.toString().padLeft(2, '0')}';
    return '${teams.join('|')}@$day';
  }

  static Widget _sectionHeader(
    BuildContext context,
    String title,
    String trailing,
  ) {
    final cs = Theme.of(context).colorScheme;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 16, 6),
        child: Row(
          children: <Widget>[
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(width: 8),
            Text(
              trailing,
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

/// 未开赛：显示日期/时间、阶段、对阵、赛制
class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({required this.match, required this.showDate});

  final LplMatch match;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card.outlined(
        margin: EdgeInsets.zero,
        shape: AppTheme.cardShape(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    <String>[
                      if (showDate) match.dateLabel,
                      if (match.timeLabel.isNotEmpty) match.timeLabel,
                    ].join('  '),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      <String>[
                        if (match.bo.isNotEmpty) match.bo,
                        if (match.stage.isNotEmpty) match.stage,
                      ].join(' · '),
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                match.hasTeams
                    ? '${match.teamA}  vs  ${match.teamB}'
                    : (match.name.isEmpty ? '对阵待定' : match.name),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              if (match.round.isNotEmpty) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  match.round,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 已结束：比分 + 评分入口（匹配不到虎扑比赛时灰掉）
class _FinishedRow extends StatelessWidget {
  const _FinishedRow({
    required this.match,
    required this.hupuMatch,
    required this.showDate,
  });

  final LplMatch match;
  final LolMatch? hupuMatch;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasRating = hupuMatch != null;

    final content = Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                <String>[
                  if (showDate) match.dateLabel,
                  if (match.timeLabel.isNotEmpty) match.timeLabel,
                ].join('  '),
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              const Spacer(),
              if (hasRating)
                Row(
                  children: <Widget>[
                    Icon(Icons.star_rounded, size: 13, color: cs.primary),
                    const SizedBox(width: 2),
                    Text(
                      '评分',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: cs.primary),
                    ),
                  ],
                )
              else
                Text(
                  '暂无评分',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: cs.outline),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  match.teamA.isEmpty ? '待定' : match.teamA,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  '${match.scoreA} : ${match.scoreB}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              Expanded(
                child: Text(
                  match.teamB.isEmpty ? '待定' : match.teamB,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
          if (match.stage.isNotEmpty || match.round.isNotEmpty) ...<Widget>[
            const SizedBox(height: 3),
            Text(
              <String>[
                if (match.stage.isNotEmpty) match.stage,
                if (match.round.isNotEmpty) match.round,
                if (match.bo.isNotEmpty) match.bo,
              ].join(' · '),
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card.filled(
        margin: EdgeInsets.zero,
        shape: AppTheme.cardShape(),
        clipBehavior: Clip.antiAlias,
        child: hasRating
            ? InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MatchDetailPage(match: hupuMatch!),
                  ),
                ),
                child: content,
              )
            : content,
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
