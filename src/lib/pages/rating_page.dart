// 选手评分页：粘贴虎扑评分页链接 → 解析全阵容评分
//
// 为什么用「粘贴链接」而不是自动关联：
//   实测虎扑帖子正文里**不含**评分链接（评分属于独立赛事模块），
//   帖子 → 评分编号的映射需要赛程接口，暂未找到。
//   因此先用链接入口保证功能可跑，等赛程接口拿到后再改成自动关联。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../models/rating_models.dart';
import '../services/hupu_client.dart';
import '../services/hupu_rating_service.dart';

final ratingServiceProvider =
    Provider<HupuRatingService>((ref) => HupuRatingService());

class RatingPage extends ConsumerStatefulWidget {
  const RatingPage({super.key, this.initialUrl});

  /// 可从别处带初始链接进来
  final String? initialUrl;

  @override
  ConsumerState<RatingPage> createState() => _RatingPageState();
}

class _RatingPageState extends ConsumerState<RatingPage> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialUrl ?? '');

  RatingBundle? _bundle;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if ((widget.initialUrl ?? '').isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _bundle = null;
    });

    try {
      final key = HupuRatingService.parseScoreUrl(raw);
      if (key == null) {
        throw HupuException('链接里没有 outBizType / outBizNo，确认是评分页链接');
      }
      final bundle = await ref.read(ratingServiceProvider).load(
            outBizType: key.type,
            outBizNo: key.no,
          );
      setState(() => _bundle = bundle);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('选手评分')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          Card.outlined(
            margin: EdgeInsets.zero,
            shape: AppTheme.cardShape(),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '粘贴虎扑评分页链接',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 3,
                    style: Theme.of(context).textTheme.bodySmall,
                    decoration: InputDecoration(
                      hintText: 'https://m.hupu.com/score/detail.html'
                          '?outBizType=lol_item&outBizNo=79822',
                      hintStyle: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: cs.outline),
                      filled: true,
                      fillColor: cs.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        tooltip: '粘贴',
                        icon: const Icon(Icons.content_paste),
                        onPressed: () async {
                          final data =
                              await Clipboard.getData(Clipboard.kTextPlain);
                          final text = data?.text ?? '';
                          if (text.isNotEmpty) {
                            _controller.text = text;
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      FilledButton.icon(
                        onPressed: _loading ? null : _load,
                        icon: _loading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.search),
                        label: Text(_loading ? '查询中…' : '查询评分'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          _controller.text =
                              'https://m.hupu.com/score/detail.html'
                              '?outBizType=lol_item&outBizNo=79822';
                        },
                        child: const Text('填入示例'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (_error != null) ...<Widget>[
            const SizedBox(height: 16),
            Card.filled(
              margin: EdgeInsets.zero,
              shape: AppTheme.cardShape(),
              color: cs.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.error_outline, color: cs.onErrorContainer),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: cs.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          if (_bundle != null) ..._buildBundle(context, _bundle!),
        ],
      ),
    );
  }

  List<Widget> _buildBundle(BuildContext context, RatingBundle b) {
    final roster = b.roster;
    final teams = b.byTeam.entries
        .where((e) => e.value.any((x) => x.isPlayer || x.isCoach))
        .toList();

    return <Widget>[
      const SizedBox(height: 20),
      Row(
        children: <Widget>[
          Text(
            b.title.isEmpty ? '评分' : b.title,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          Text(
            '${roster.length} 项',
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
      const SizedBox(height: 12),
      for (final team in teams) ...<Widget>[
        _TeamBlock(items: team.value),
        const SizedBox(height: 14),
      ],
      if (b.comments.isNotEmpty) ...<Widget>[
        const SizedBox(height: 8),
        Text(
          '热门评论',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        for (final c in b.comments.take(5))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card.outlined(
              margin: EdgeInsets.zero,
              shape: AppTheme.cardShape(),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  c,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(height: 1.5),
                ),
              ),
            ),
          ),
      ],
    ];
  }
}

/// 一支队伍：教练在前，选手按分数降序
class _TeamBlock extends StatelessWidget {
  const _TeamBlock({required this.items});

  final List<ScoreItem> items;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sorted = [...items]
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
              '队伍 ${sorted.first.teamId}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...sorted.map((e) => _ItemTile(item: e)),
      ],
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item});

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
                                horizontal: 6,
                                vertical: 1,
                              ),
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
              // 评分胶囊徽章
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
