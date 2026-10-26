// 预告页：未开赛的赛程（来自 LPL 官方静态赛程）
//
// 虎扑只有「已开赛/已结束」的比赛节点，所以预告单独做成一个板块，
// 数据源是腾讯 LPL 官网的 LOL_MATCH2_MATCH_HOMEPAGE_BMATCH_LIST_{gameId}.js。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../core/theme.dart';
import '../models/lpl_models.dart';
import '../services/lpl_service.dart';
import 'about_page.dart';

class UpcomingPage extends ConsumerWidget {
  const UpcomingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(lplScheduleProvider);
    final cs = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(lplScheduleProvider);
        await ref.read(lplScheduleProvider.future);
      },
      child: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar.large(
            title: const Text('预告'),
            actions: const <Widget>[AboutIconButton()],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Row(
                children: <Widget>[
                  Icon(Icons.event_note_outlined,
                      size: 18, color: cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '未开赛 · 数据来自官方赛程',
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
            data: (all) {
              final upcoming = LplScheduleService.upcoming(all);
              if (upcoming.isEmpty) {
                return <Widget>[
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _Hint(
                      icon: Icons.event_available_outlined,
                      text: '暂时没有待进行的比赛\n下拉刷新试试',
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
              for (var i = 0; i < upcoming.length; i++) {
                final m = upcoming[i];
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
                  SliverToBoxAdapter(child: _UpcomingRow(match: m)),
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
}

/// 单场预告：时间 + 阶段/赛制 + 对阵
class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({required this.match});

  final LplMatch match;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasTeams = match.hasTeams;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card.outlined(
        margin: EdgeInsets.zero,
        shape: AppTheme.cardShape(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    match.timeLabel,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    <String>[
                      if (match.stage.isNotEmpty) match.stage,
                      if (match.round.isNotEmpty) match.round,
                    ].join(' · '),
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: cs.tertiaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      match.bo.isEmpty ? '待定' : match.bo,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: cs.onTertiaryContainer),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (hasTeams)
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        match.teamA,
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'VS',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        match.teamB,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: <Widget>[
                    Icon(Icons.help_outline, size: 16, color: cs.outline),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        match.name.isEmpty ? '对阵待定' : '${match.name}（对阵待定）',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              if (match.place.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    Icon(Icons.place_outlined, size: 13, color: cs.outline),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        match.place,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: cs.outline),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
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
