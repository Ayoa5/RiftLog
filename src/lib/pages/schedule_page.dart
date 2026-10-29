// 赛程页：进行中 + 已结束
//
// 关键设计（2026-10-29 修正）：
//   不能只看 LPL 的 MatchStatus —— 它只有 1(未开始)/3(已结束)，一场 BO3/BO5 打完才翻。
//   而虎扑在**开赛前约 1 小时**就建好了节点（实测 LYON vs IG：07:00 开赛，节点 06:04 创建），
//   且每局都有独立评分。
//   ⇒ 只要「虎扑节点存在且未结束」或「开赛时间已过」，就算进行中，并允许点进看评分。
//   ⇒ 比赛中每 60 秒只刷新这几场（每次 1 个请求），不做全量扫描。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../core/team_alias.dart';
import '../core/theme.dart';
import '../models/lpl_models.dart';
import '../models/match_models.dart';
import '../models/match_phase.dart';
import '../services/lpl_service.dart';
import 'about_page.dart';
import 'match_detail_page.dart';

class SchedulePage extends ConsumerStatefulWidget {
  const SchedulePage({super.key});

  @override
  ConsumerState<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends ConsumerState<SchedulePage> {
  Timer? _ticker;
  List<int> _liveIds = const <int>[];

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// 有进行中的比赛时才开定时器，避免无谓请求
  void _syncTicker(bool need) {
    if (need && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 60), (_) => _tick());
    } else if (!need) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  Future<void> _tick() async {
    if (_liveIds.isEmpty) return;
    final svc = ref.read(matchServiceProvider);
    for (final id in _liveIds) {
      await svc.refreshOne(id);
    }
    ref.invalidate(scheduleProvider);
  }

  @override
  Widget build(BuildContext context) {
    final lplAsync = ref.watch(lplScheduleProvider);
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
        await ref.read(matchServiceProvider).discover(force: true);
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
                      '进行中每分钟自动刷新 · 带评分可点开看选手打分与评论',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ...lplAsync.when<List<Widget>>(
            data: (all) {
              final now = DateTime.now();
              final live = <(LplMatch, LolMatch?)>[];
              final finished = <(LplMatch, LolMatch?)>[];
              for (final m in all) {
                final h = hupuIndex[m.joinKey];
                final phase = phaseOf(m, h, now: now);
                if (phase == MatchPhase.live) {
                  live.add((m, h));
                } else if (phase == MatchPhase.finished) {
                  finished.add((m, h));
                }
              }
              live.sort((a, b) => _cmp(b.$1, a.$1));
              finished.sort((a, b) => _cmp(b.$1, a.$1));

              _liveIds = <int>[
                for (final e in live)
                  if (e.$2 != null) e.$2!.bizId,
              ];
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _syncTicker(live.isNotEmpty);
              });

              if (live.isEmpty && finished.isEmpty) {
                return <Widget>[
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _Hint(
                      icon: Icons.event_busy_outlined,
                      text: '当前没有进行中或已结束的比赛\n去「预告」看看待开赛的场次',
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
              if (live.isNotEmpty) {
                slivers.add(_sectionTitle(context, '进行中', '${live.length} 场',
                    color: cs.primary));
                for (final e in live) {
                  slivers.add(SliverToBoxAdapter(
                    child: _MatchRow(lpl: e.$1, hupu: e.$2, live: true),
                  ));
                }
              }
              if (finished.isNotEmpty) {
                slivers.add(_sectionTitle(
                    context, '已结束', '${finished.length} 场',
                    color: cs.onSurfaceVariant));
                for (final e in finished) {
                  slivers.add(SliverToBoxAdapter(
                    child: _MatchRow(lpl: e.$1, hupu: e.$2, live: false),
                  ));
                }
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

  static int _cmp(LplMatch a, LplMatch b) {
    final da = a.date, db = b.date;
    if (da != null && db != null) return da.compareTo(db);
    return a.matchId.compareTo(b.matchId);
  }

  static Widget _sectionTitle(BuildContext context, String title, String trailing,
      {required Color color}) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 16, 6),
        child: Row(
          children: <Widget>[
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(width: 8),
            Text(
              trailing,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  /// 虎扑比赛的匹配键：队名排序 + 日期
  static String _hupuKey(LolMatch m) {
    final teams = <String>[canonicalTeam(m.homeTeam), canonicalTeam(m.awayTeam)]
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

/// 单场比赛行：进行中 / 已结束共用
class _MatchRow extends StatelessWidget {
  const _MatchRow({
    required this.lpl,
    required this.hupu,
    required this.live,
  });

  final LplMatch lpl;
  final LolMatch? hupu;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasRating = hupu != null;

    // 有虎扑节点时用虎扑的比分（更新更及时），否则用 LPL 的
    final scoreA = hasRating ? hupu!.homeScore : lpl.scoreA;
    final scoreB = hasRating ? hupu!.awayScore : lpl.scoreB;
    final teamA = lpl.teamA.isNotEmpty ? lpl.teamA : (hupu?.homeTeam ?? '待定');
    final teamB = lpl.teamB.isNotEmpty ? lpl.teamB : (hupu?.awayTeam ?? '待定');

    final content = Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 11),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                lpl.timeLabel,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: live ? cs.primary : cs.onSurfaceVariant,
                      fontWeight: live ? FontWeight.w700 : FontWeight.w400,
                    ),
              ),
              const SizedBox(width: 8),
              if (live)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: cs.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '进行中',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: cs.onPrimaryContainer),
                      ),
                    ],
                  ),
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
                  teamA,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: hasRating ? FontWeight.w700 : FontWeight.w500,
                      ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  '$scoreA : $scoreB',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: live ? cs.primary : null,
                      ),
                ),
              ),
              Expanded(
                child: Text(
                  teamB,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: hasRating ? FontWeight.w700 : FontWeight.w500,
                      ),
                ),
              ),
            ],
          ),
          if (lpl.stage.isNotEmpty || lpl.round.isNotEmpty) ...<Widget>[
            const SizedBox(height: 3),
            Text(
              <String>[
                if (lpl.stage.isNotEmpty) lpl.stage,
                if (lpl.round.isNotEmpty) lpl.round,
                if (lpl.bo.isNotEmpty) lpl.bo,
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
                    builder: (_) => MatchDetailPage(match: hupu!),
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
