// 比赛详情页：BO 局切换 + 该局选手评分（红蓝方分组）
// 数据链：lol_match → (CHILD) 局列表 → (CHILD) 选手/教练评分

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../core/theme.dart';
import '../models/comment_models.dart';
import '../models/game_outcome.dart';
import '../models/match_models.dart';
import '../models/rating_models.dart';
import '../services/hupu_scraper_service.dart';

class MatchDetailPage extends ConsumerStatefulWidget {
  const MatchDetailPage({super.key, required this.match});

  final LolMatch match;

  @override
  ConsumerState<MatchDetailPage> createState() => _MatchDetailPageState();
}

class _MatchDetailPageState extends ConsumerState<MatchDetailPage> {
  int _gameIndex = 0;

  /// 进行中的比赛首次加载时自动跳到最后一局（当前正在打的那局）
  bool _autoPicked = false;

  @override
  Widget build(BuildContext context) {
    final match = widget.match;
    final gamesAsync = ref.watch(gamesProvider(match.bizId));
    final outcomesAsync = ref.watch(
      gameOutcomesProvider(
        (
          matchBizId: match.bizId,
          homeTeamId: match.homeTeamId,
          awayTeamId: match.awayTeamId,
          homeScore: match.homeScore,
          awayScore: match.awayScore,
        ),
      ),
    );

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
            data: (gamesRaw) {
              if (gamesRaw.isEmpty) {
                return <Widget>[
                  const _EmptyHint(text: '这场比赛还没有可用的评分数据'),
                ];
              }
              // 虎扑 CHILD 实测是倒序（第4局→第1局），按局号重排，
              // 这样胜负序列和「自动跳到当前局」才是对的。
              final games = List<LolGame>.from(gamesRaw)
                ..sort(
                  (a, b) => (_gameNumberOf(a.name) ?? 0)
                      .compareTo(_gameNumberOf(b.name) ?? 0),
                );
              final int idx = _gameIndex.clamp(0, games.length - 1);
              if (!_autoPicked) {
                _autoPicked = true;
                if (!match.isCompleted && games.length > 1) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() => _gameIndex = games.length - 1);
                    }
                  });
                }
              }

              final outcomes =
                  outcomesAsync.asData?.value ?? const <GameOutcome>[];
              final current = _outcomeFor(outcomes, games[idx].bizId);

              return <Widget>[
                if (games.length > 1) ...<Widget>[
                  _SeriesStrip(
                    match: match,
                    games: games,
                    outcomes: outcomes,
                    selectedIndex: idx,
                    loading: outcomesAsync.isLoading,
                    onTap: (i) => setState(() => _gameIndex = i),
                  ),
                  const SizedBox(height: 16),
                ],
                _GameScores(
                  gameId: games[idx].bizId,
                  match: match,
                  gameName: games[idx].name,
                  outcome: current,
                  outcomesLoading: outcomesAsync.isLoading,
                ),
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

/// 从「第4局」里取局号；解析不了返回 null
int? _gameNumberOf(String name) {
  final m = RegExp(r'第\s*(\d+)\s*局').firstMatch(name);
  if (m == null) return null;
  return int.tryParse(m.group(1)!);
}

GameOutcome? _outcomeFor(List<GameOutcome> list, int gameBizId) {
  for (final o in list) {
    if (o.gameBizId == gameBizId) return o;
  }
  return null;
}

/// 小局胜负序列条：一眼看完整场 BO 的各局胜负走势，点击可切局
class _SeriesStrip extends StatelessWidget {
  const _SeriesStrip({
    required this.match,
    required this.games,
    required this.outcomes,
    required this.selectedIndex,
    required this.loading,
    required this.onTap,
  });

  final LolMatch match;
  final List<LolGame> games;
  final List<GameOutcome> outcomes;
  final int selectedIndex;
  final bool loading;
  final ValueChanged<int> onTap;

  String _nameOf(String id) {
    if (id.isNotEmpty && id == match.homeTeamId) return match.homeTeam;
    if (id.isNotEmpty && id == match.awayTeamId) return match.awayTeam;
    return '未知';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final consistent =
        outcomes.isEmpty || outcomes.every((o) => o.seriesConsistent);
    final winColor = const Color(0xFF2E7D32);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              '小局胜负',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            Text(
              '大比分 ${match.homeScore} : ${match.awayScore}',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            const Spacer(),
            if (loading)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (!consistent)
              Text(
                '判定存疑',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: cs.error, fontWeight: FontWeight.w600),
              )
            else
              Text(
                '与比分吻合',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: winColor, fontWeight: FontWeight.w600),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              for (var i = 0; i < games.length; i++) ...<Widget>[
                _cell(context, i),
                if (i < games.length - 1) const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '蓝=主队胜 · 灰=客队胜 · 依据每局击杀，评分交叉验证',
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _cell(BuildContext context, int i) {
    final cs = Theme.of(context).colorScheme;
    final game = games[i];
    final out = _outcomeFor(outcomes, game.bizId);
    final known = out?.isKnown ?? false;
    final isHomeWin = known && out!.winnerTeamId == match.homeTeamId;
    final selected = i == selectedIndex;

    final bg = !known
        ? cs.surfaceContainerHighest
        : (isHomeWin ? cs.primaryContainer : cs.tertiaryContainer);
    final fg = !known
        ? cs.onSurfaceVariant
        : (isHomeWin ? cs.onPrimaryContainer : cs.onTertiaryContainer);
    final label = known
        ? '${_nameOf(out!.winnerTeamId)} 胜'
        : (loading ? '判定中' : '未开赛');

    return GestureDetector(
      onTap: () => onTap(i),
      child: Container(
        width: 78,
        height: 56,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? cs.primary : Colors.transparent,
            width: selected ? 1.5 : 0,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              game.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: fg),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
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
    final winner = match.winnerName;
    final winColor = const Color(0xFF2E7D32);

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
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight:
                              winner == match.homeTeam ? FontWeight.w800 : FontWeight.w600,
                          color: winner == match.homeTeam ? winColor : null,
                        ),
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
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight:
                              winner == match.awayTeam ? FontWeight.w800 : FontWeight.w600,
                          color: winner == match.awayTeam ? winColor : null,
                        ),
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
  const _GameScores({
    required this.gameId,
    required this.match,
    required this.gameName,
    this.outcome,
    this.outcomesLoading = false,
  });

  final int gameId;
  final LolMatch match;

  /// 局名，如「第4局」
  final String gameName;

  /// 本局胜负推导结果（加载中或失败时为 null）
  final GameOutcome? outcome;
  final bool outcomesLoading;

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

        // 本局各队击杀合计（虎扑选手节点自带 KDA，是真实数据，不是推测）
        final killsByTeam = <String, int>{};
        for (final it in roster) {
          if (!it.isPlayer) continue;
          killsByTeam[it.teamId] =
              (killsByTeam[it.teamId] ?? 0) + _killsOf(it);
        }

        // 本局胜负以推导结果为准（击杀 + 评分交叉验证 + 大比分自校验）
        final confident = outcome?.isConfident ?? false;
        final winnerId = confident ? (outcome!.winnerTeamId) : '';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _GameBanner(
              match: match,
              gameName: gameName,
              killsByTeam: killsByTeam,
              outcome: outcome,
              outcomesLoading: outcomesLoading,
            ),
            const SizedBox(height: 14),
            for (final entry in grouped.entries) ...<Widget>[
              _TeamSection(
                teamId: entry.key,
                items: entry.value,
                match: match,
                isWinner: winnerId.isNotEmpty && entry.key == winnerId,
                showResult: winnerId.isNotEmpty,
                kills: killsByTeam[entry.key],
                outcome: outcome,
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

/// 从 "12/4/6" 里取击杀数
int _killsOf(ScoreItem s) {
  final first = s.kda.split('/').first;
  return int.tryParse(first) ?? 0;
}

/// 本局概览条：第几局 + 本局胜方 + 大比分 + 双方本局击杀对比
///
/// 虎扑接口没有「单局胜负」字段，但每局选手节点带完整 KDA 与评分：
/// 由 `HupuMatchService.fetchGameOutcomes` 用「两队击杀」判胜、
/// 「平均评分」交叉验证、「胜场数 = 系列赛比分」自校验后给出结论。
/// 结论不可靠时明确标注「待确认」，不冒充官方赛果。
class _GameBanner extends StatelessWidget {
  const _GameBanner({
    required this.match,
    required this.gameName,
    required this.killsByTeam,
    this.outcome,
    this.outcomesLoading = false,
  });

  final LolMatch match;
  final String gameName;
  final Map<String, int> killsByTeam;
  final GameOutcome? outcome;
  final bool outcomesLoading;

  String _nameOf(String id) {
    if (id.isNotEmpty && id == match.homeTeamId) return match.homeTeam;
    if (id.isNotEmpty && id == match.awayTeamId) return match.awayTeam;
    return '未知队伍';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final homeKills = killsByTeam[match.homeTeamId] ?? 0;
    final awayKills = killsByTeam[match.awayTeamId] ?? 0;
    final total = homeKills + awayKills;
    final homeRatio = total == 0 ? 0.5 : homeKills / total;
    final out = outcome;
    final known = out?.isKnown ?? false;
    final confident = out?.isConfident ?? false;
    final winnerName = known ? _nameOf(out!.winnerTeamId) : null;
    final winColor = const Color(0xFF2E7D32);

    return Card.filled(
      margin: EdgeInsets.zero,
      shape: AppTheme.cardShape(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    gameName,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: cs.onSecondaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '大比分 ${match.homeScore} : ${match.awayScore}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
                const Spacer(),
                if (winnerName != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: confident
                          ? winColor.withOpacity(0.14)
                          : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.emoji_events,
                          size: 13,
                          color: confident ? winColor : cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          confident
                              ? '本局 $winnerName 获胜'
                              : '本局 $winnerName 领先（待确认）',
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(
                                color: confident ? winColor : cs.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  )
                else
                  Text(
                    outcomesLoading ? '本局判定中…' : match.statusText,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // 本局击杀对比（真实数据）
            Row(
              children: <Widget>[
                Text(
                  match.homeTeam,
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 6),
                Text(
                  '$homeKills',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: SizedBox(
                      height: 6,
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            flex: (homeRatio * 1000).round().clamp(1, 999).toInt(),
                            child: ColoredBox(color: cs.primary),
                          ),
                          Expanded(
                            flex: ((1 - homeRatio) * 1000)
                                .round()
                                .clamp(1, 999)
                                .toInt(),
                            child: ColoredBox(color: cs.tertiary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$awayKills',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: cs.tertiary,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(width: 6),
                Text(
                  match.awayTeam,
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              !known
                  ? '本局击杀对比（选手 KDA 累加），结果判定中或暂无数据'
                  : (confident
                      ? '依据：本局击杀 $homeKills : $awayKills，评分交叉验证且与系列赛比分吻合'
                      : '依据：本局击杀 $homeKills : $awayKills；判定存疑，请结合比赛核对'),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamSection extends StatelessWidget {
  const _TeamSection({
    required this.teamId,
    required this.items,
    required this.match,
    this.isWinner = false,
    this.showResult = false,
    this.kills,
    this.outcome,
  });

  final String teamId;
  final List<ScoreItem> items;
  final LolMatch match;

  /// 本局推导结果（评论标题里展示「本局谁胜」）
  final GameOutcome? outcome;

  /// 该队是否为**本局**胜方（由逐局推导结果给出）
  final bool isWinner;

  /// 本局胜负已确定时才显示「胜/负」徽章
  final bool showResult;

  /// 本局该队击杀合计（无数据时为 null）
  final int? kills;

  bool get _isHome => teamId.isNotEmpty && teamId == match.homeTeamId;

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

  /// 本局结果文案（只有判定可靠时才给，避免误导）
  String? get _resultText {
    final o = outcome;
    if (o == null || !o.isConfident) return null;
    final name = o.winnerTeamId == match.homeTeamId
        ? match.homeTeam
        : (o.winnerTeamId == match.awayTeamId ? match.awayTeam : '');
    return name.isEmpty ? null : '本局 $name 胜';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sorted = List<ScoreItem>.from(items)
      ..sort((a, b) {
        if (a.isCoach != b.isCoach) return a.isCoach ? -1 : 1;
        return b.score.compareTo(a.score);
      });

    // 主队用 primary、客队用 tertiary，和概览条里的击杀对比色保持一致
    final teamColor = _isHome ? cs.primary : cs.tertiary;
    final winColor = const Color(0xFF2E7D32);
    final lossColor = cs.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 4,
              height: 14,
              decoration: BoxDecoration(
                color: teamColor,
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
            if (showResult) ...<Widget>[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isWinner
                      ? winColor.withOpacity(0.14)
                      : lossColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isWinner ? '胜' : '负',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: isWinner ? winColor : lossColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                ),
              ),
            ],
            const Spacer(),
            if (kills != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  '本局击杀 $kills',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: teamColor,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
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
            onTap: () => _showComments(
              context,
              e,
              teamName: _teamName,
              resultText: _resultText,
            ),
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
              _ChampionThumb(item: item),
              const SizedBox(width: 10),
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

/// 选手本局使用的英雄头像（虎扑 `auxiliaryPic` 里的官方英雄图）。
///
/// 只有「玩家 + 有英雄图」时显示；教练或数据缺失时留同宽空槽，
/// 保证各行的姓名/评分列对齐，不引入额外视觉元素。
class _ChampionThumb extends StatelessWidget {
  const _ChampionThumb({required this.item});

  final ScoreItem item;

  static const double _size = 34;

  @override
  Widget build(BuildContext context) {
    if (!item.isPlayer) {
      return const SizedBox(width: _size, height: _size);
    }

    final cs = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(8);

    // 极少数确实没有英雄数据时，用选手首字母做占位，避免"图片加载失败"的观感。
    final initial = item.name.isNotEmpty ? item.name.substring(0, 1) : '·';
    Widget placeholder() => Container(
          width: _size,
          height: _size,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: radius,
          ),
          alignment: Alignment.center,
          child: Text(
            initial,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        );

    if (item.championPic.isEmpty) return placeholder();

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: _size,
        height: _size,
        child: Image.network(
          item.championPic,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => placeholder(),
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
void _showComments(
  BuildContext context,
  ScoreItem item, {
  String? teamName,
  String? resultText,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _CommentsSheet(
      item: item,
      teamName: teamName,
      resultText: resultText,
    ),
  );
}

/// 评论区
///
/// 实测（2026-11-04 修正）：
///   最亮 → /hottest 取真高赞前 N 条 + 时间流分页补充，去重后按 lightCount 降序
///   最晚 → primarySingleRow?order=desc&publishTime=<当前时间ms>
///   最早 → primarySingleRow?order=asc&publishTime=0
/// 翻页：把上一页的 cursor.publishTime 作为下一轮 publishTime 传回。
class _CommentsSheet extends ConsumerStatefulWidget {
  const _CommentsSheet({required this.item, this.teamName, this.resultText});

  final ScoreItem item;

  /// 所属队伍名（用于标题里标出「这是哪一边的选手」）
  final String? teamName;

  /// 本局结果（如「本局 BLG 胜」）
  final String? resultText;

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

  /// 爬楼超过一定距离后显示「回顶部」
  bool _showToTop = false;

  /// DraggableScrollableSheet 提供的滚动控制器（builder 里赋值，供回顶用）
  ScrollController? _sheetController;

  /// 固定头部高度（标题 + 关闭 + 排序），ListView 顶部留同样的空间
  static const double _headerHeight = 112.0;

  void _onScroll(double pixels) {
    final show = pixels > 600;
    if (show != _showToTop && mounted) {
      setState(() => _showToTop = show);
    }
  }

  void _scrollToTop() {
    final c = _sheetController;
    if (c == null || !c.hasClients) return;
    c.animateTo(
      0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

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
      final svc = ref.read(matchServiceProvider);
      final no = widget.item.bizId.toString();

      if (_sort == CommentSort.brightest) {
        // 「最亮」= 虎扑「亮回复」(`/hottest` 的真高赞前 N 条) + 时间流分页补充。
        // 真高赞评论常在几千条之前，只拉时间流根本够不到（拉到的都是最新低赞），
        // 所以 reset 时先取 /hottest 拿到真顶部；「加载更多」再从时间流补。
        if (reset) {
          final hot = await svc.fetchHottestComments(type: 'lol_item', no: no);
          if (!mounted) return;
          _items.addAll(hot);
        }
        const int pagesPerLoad = 3;
        var pages = 0;
        while (pages < pagesPerLoad) {
          final page = await svc.fetchComments(
            type: 'lol_item',
            no: no,
            sort: _sort,
            cursor: _cursor,
          );
          if (!mounted) return;
          if (pages == 0 && reset) _total = page.total;
          _items.addAll(page.items);
          _cursor = page.nextCursor;
          _hasMore = page.hasMore;
          pages++;
          if (!page.hasMore || page.items.isEmpty) break;
        }
        // 去重（/hottest 与时间流可能重叠）后按点赞降序；同亮按时间新→旧
        final seen = <String>{};
        final uniq = <HupuComment>[];
        for (final c in _items) {
          if (c.id.isEmpty || seen.add(c.id)) uniq.add(c);
        }
        _items
          ..clear()
          ..addAll(uniq);
        _items.sort((a, b) {
          final byLight = b.lightCount.compareTo(a.lightCount);
          return byLight != 0
              ? byLight
              : b.publishTime.compareTo(a.publishTime);
        });
      } else {
        final page = await svc.fetchComments(
          type: 'lol_item',
          no: no,
          sort: _sort,
          cursor: _cursor,
        );
        if (!mounted) return;
        if (reset) _total = page.total;
        _items.addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
      }
      setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeSort(CommentSort s) {
    if (s == _sort) return;
    setState(() => _sort = s);
    _scrollToTop();
    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      maxChildSize: 0.95,
      builder: (ctx, controller) {
        _sheetController = controller;
        return Stack(
          children: <Widget>[
            NotificationListener<ScrollNotification>(
              onNotification: (n) {
                _onScroll(n.metrics.pixels);
                return false;
              },
              child: ListView(
                controller: controller,
                // 顶部给固定头部让位，底部给「回顶部」按钮让位
                padding: const EdgeInsets.fromLTRB(16, _headerHeight + 8, 16, 80),
                children: <Widget>[
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
                              ?.copyWith(color: Theme.of(ctx).colorScheme.onSurfaceVariant),
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
                          style: TextStyle(
                              color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ),

                  for (final c in _items)
                    _CommentTile(
                      comment: c,
                      bizNo: widget.item.bizId.toString(),
                      bizType: 'lol_item',
                    ),

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
            ),

            // 固定头部：爬到再深也能一键关闭 / 换排序，不用滑回顶部
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: _headerHeight,
              child: _buildHeader(ctx),
            ),

            // 悬浮「回顶部」：滚过 600px 才出现，不挡阅读
            Positioned(
              right: 16,
              bottom: 16,
              child: _buildToTopButton(ctx),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext ctx) {
    final cs = Theme.of(ctx).colorScheme;
    return Container(
      height: _headerHeight,
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          bottom: BorderSide(
            color: cs.outlineVariant.withOpacity(0.5),
            width: 0.5,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 6, 6, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${widget.item.name} 的评论',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      <String>[
                        if ((widget.resultText ?? '').isNotEmpty)
                          widget.resultText!,
                        if ((widget.teamName ?? '').isNotEmpty)
                          widget.teamName!,
                        if (widget.item.isCoach) '教练' else '选手',
                        if (widget.item.kda.isNotEmpty)
                          '本局 KDA ${widget.item.kda}',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                  ],
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
              IconButton(
                onPressed: () => Navigator.of(ctx).pop(),
                icon: const Icon(Icons.close_rounded),
                tooltip: '关闭评论',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 8),
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
        ],
      ),
    );
  }

  Widget _buildToTopButton(BuildContext ctx) {
    final cs = Theme.of(ctx).colorScheme;
    return AnimatedOpacity(
      opacity: _showToTop ? 1 : 0,
      duration: const Duration(milliseconds: 180),
      child: IgnorePointer(
        ignoring: !_showToTop,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Material(
            color: cs.primaryContainer,
            child: InkWell(
              onTap: _scrollToTop,
              child: SizedBox(
                width: 62,
                height: 56,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      Icons.keyboard_arrow_up_rounded,
                      size: 20,
                      color: cs.onPrimaryContainer,
                    ),
                    Text(
                      '顶部',
                      style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                            color: cs.onPrimaryContainer,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 单条评论（含楼中楼展开）
///
/// 实测：`subCommentCount>0` 的评论占多数（50 条里 33 条有子回复），
/// 子回复接口是 `primarySingleRow/getMore`（不是 subCommentList，后者返回 null）。
class _CommentTile extends ConsumerStatefulWidget {
  const _CommentTile({
    required this.comment,
    required this.bizNo,
    required this.bizType,
  });

  final HupuComment comment;

  /// 选手 bizId
  final String bizNo;
  final String bizType;

  @override
  ConsumerState<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends ConsumerState<_CommentTile> {
  final List<HupuComment> _subs = <HupuComment>[];
  int? _cursor;
  bool _hasMore = false;
  bool _loading = false;
  bool _expanded = false;
  String? _error;

  Future<void> _toggle() async {
    if (_expanded) {
      setState(() => _expanded = false);
      return;
    }
    setState(() => _expanded = true);
    if (_subs.isEmpty && !_loading) await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ref.read(matchServiceProvider).fetchSubComments(
            type: widget.bizType,
            no: widget.bizNo,
            parentId: int.tryParse(widget.comment.id) ?? 0,
            publishTime: _cursor ?? widget.comment.publishTime,
          );
      if (!mounted) return;
      setState(() {
        _subs.addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = widget.comment;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card.outlined(
        margin: EdgeInsets.zero,
        shape: AppTheme.cardShape(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ClipOval(
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: c.userHead.isEmpty
                          ? Container(color: cs.surfaceContainerHigh)
                          : Image.network(
                              c.userHead,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  Container(color: cs.surfaceContainerHigh),
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
                                c.userName,
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
                            if (c.score > 0) ...<Widget>[
                              const SizedBox(width: 6),
                              Text(
                                '${c.score} 分',
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
                          HupuScraperService.commentPlainText(c.content),
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(height: 1.45),
                        ),
                        if (c.hasImage) ...<Widget>[
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              c.images.first,
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
                                if (c.dateText.isNotEmpty) c.dateText,
                                if (c.ipLocation.isNotEmpty) c.ipLocation,
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
                              '${c.lightCount}',
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

              // 楼中楼入口
              if (c.subCount > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 42, top: 2),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _toggle,
                      icon: Icon(
                        _expanded
                            ? Icons.expand_less
                            : Icons.subdirectory_arrow_right,
                        size: 15,
                      ),
                      label: Text(
                        _expanded
                            ? '收起回复'
                            : '查看 ${c.subCount} 条回复',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                ),

              // 子回复列表
              if (_expanded) ...<Widget>[
                const SizedBox(height: 4),
                Container(
                  margin: const EdgeInsets.only(left: 42),
                  padding: const EdgeInsets.only(left: 10),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: cs.outlineVariant, width: 2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (_loading && _subs.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            '子回复加载失败',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: cs.error),
                          ),
                        ),
                      for (final s in _subs) _SubCommentRow(comment: s),
                      if (_hasMore)
                        Padding(
                          padding: const EdgeInsets.only(top: 2, bottom: 4),
                          child: TextButton(
                            onPressed: _loading ? null : _loadMore,
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              _loading ? '加载中…' : '加载更多回复',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 子回复行（比主评论紧凑，无卡片）
class _SubCommentRow extends StatelessWidget {
  const _SubCommentRow({required this.comment});

  final HupuComment comment;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipOval(
            child: SizedBox(
              width: 22,
              height: 22,
              child: comment.userHead.isEmpty
                  ? Container(color: cs.surfaceContainerHigh)
                  : Image.network(
                      comment.userHead,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: cs.surfaceContainerHigh),
                    ),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  comment.userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  HupuScraperService.commentPlainText(comment.content),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(height: 1.4),
                ),
                const SizedBox(height: 3),
                Row(
                  children: <Widget>[
                    Text(
                      comment.dateText,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: cs.outline, fontSize: 10),
                    ),
                    const Spacer(),
                    Icon(Icons.thumb_up_alt_outlined,
                        size: 11, color: cs.outline),
                    const SizedBox(width: 2),
                    Text(
                      '${comment.lightCount}',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: cs.outline, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
