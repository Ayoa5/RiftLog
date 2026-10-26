// 赛程页（战报）：已结束的比赛
//
// 数据链路：
//   1. LPL 官方静态赛程提供「已结束」的完整列表（26 场）
//   2. 按「队名排序 + 日期」匹配虎扑比赛节点（16 场有评分）
//   3. 匹配到的可点进详情看选手评分与评论；匹配不到的显示「暂无评分」
//
// 未开赛的预告已独立成「预告」板块（pages/upcoming_page.dart）。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../core/theme.dart';
import '../models/lpl_models.dart';
import '../models/match_models.dart';
import '../services/lpl_service.dart';
import 'about_page.dart';
import 'match_detail_page.dart';

class SchedulePage extends ConsumerWidget {
  const SchedulePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lplAsync = ref.watch(lplScheduleProvider);
    // 虎扑比赛：用于给「已结束」行挂评分入口（拿不到也不影响展示）
    final hupuMatches =
        ref.watch(scheduleProvider).valueOrNull ?? const <LolMatch>[];
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
          SliverAppBar.large(
            title: const Text('赛程'),
            actions: const <Widget>[AboutIconButton()],
          ),
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
                      '已结束 · 带评分的可点开看选手打分与评论',
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
              final finished = LplScheduleService.finished(all);
              if (finished.isEmpty) {
                return <Widget>[
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _Hint(
                      icon: Icons.event_busy_outlined,
                      text: '暂时没有已结束的比赛\n下拉刷新试试',
                      action: FilledButton.tonalIcon(
                        onPressed: () => ref.invalidate(lplScheduleProvider),
                        icon: const Icon(Icons.refresh),
                        label: const Text('重新加载'),
                      ),
                    ),
                  ),
                ];
              }

              final slivers = <Widget>[];
              String? lastLabel;
              for (var i = 0; i < finished.length; i++) {
                final m = finished[i];
                final label = m.dateLabel;
                if (label != lastLabel) {
                  slivers.add(
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 16, 6),
                        child: Text(
                          label,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: cs.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                    ),
                  );
                  lastLabel = label;
                }
                slivers.add(
                  SliverToBoxAdapter(
                    child: _FinishedRow(
                      match: m,
                      hupuMatch: hupuIndex[m.joinKey],
                    ),
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
}

/// 已结束：比分 + 评分入口（匹配不到虎扑比赛时灰掉）
class _FinishedRow extends StatelessWidget {
  const _FinishedRow({required this.match, required this.hupuMatch});

  final LplMatch match;
  final LolMatch? hupuMatch;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasRating = hupuMatch != null;

    final content = Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 11),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                match.timeLabel,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              const Spacer(),
              if (hasRating)
                Row(
                  children: <Widget>[
                    Icon(Icons.star_rounded, size: 14, color: cs.primary),
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
                        fontWeight:
                            hasRating ? FontWeight.w700 : FontWeight.w500,
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
                        fontWeight:
                            hasRating ? FontWeight.w700 : FontWeight.w500,
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
