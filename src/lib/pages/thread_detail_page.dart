// 帖子详情页：选手评分徽章 + 赛后神评（亮评）
// 评分数据源未锁定时自动降级：不显示评分区，只显示正文与亮评，不报错

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../models/hupu_models.dart';
import '../services/hupu_scraper_service.dart';
import 'rating_page.dart';
import 'schedule_page.dart' show scraperProvider;

final threadBundleProvider =
    FutureProvider.autoDispose.family<ThreadBundle, int>(
  (ref, tid) => ref.watch(scraperProvider).fetchThreadBundle(tid),
);

class ThreadDetailPage extends ConsumerWidget {
  const ThreadDetailPage({super.key, required this.tid, required this.title});

  final int tid;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(threadBundleProvider(tid));
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: async.when(
        data: (bundle) => _Body(bundle: bundle),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.cloud_off_outlined, size: 48, color: cs.error),
                const SizedBox(height: 12),
                Text(
                  e.toString(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  onPressed: () => ref.invalidate(threadBundleProvider(tid)),
                  icon: const Icon(Icons.refresh),
                  label: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.bundle});

  final ThreadBundle bundle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final detail = bundle.detail;
    final text = HupuScraperService.plainTextOf(detail.contentHtml);
    final images = HupuScraperService.imageUrlsOf(detail.contentHtml);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: <Widget>[
        // ── 标题 ──
        Text(
          detail.title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Icon(Icons.person_outline, size: 15, color: cs.onSurfaceVariant),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                detail.authorName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.schedule, size: 15, color: cs.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              detail.createdAtText,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),

        // ── 评分入口 ──
        // 实测：虎扑帖子正文不含评分链接（评分是独立赛事模块），
        // 帖子 → 评分编号 的自动映射需要赛程接口（尚未找到）。
        // 因此这里给一个直达入口：粘评分页链接即可查全阵容。
        const SizedBox(height: 16),
        Card.outlined(
          margin: EdgeInsets.zero,
          shape: AppTheme.cardShape(),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radius),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const RatingPage()),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: <Widget>[
                  Icon(Icons.star_rounded, color: cs.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '查看选手评分',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '粘贴虎扑评分页链接，看红蓝双方 10 人分数',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),

        // ── 若正文里解析出评分，则直接展示 ──
        if (bundle.ratings.isNotEmpty) ...<Widget>[
          const SizedBox(height: 20),
          _SectionTitle(
            icon: Icons.star_rounded,
            text: '选手评分',
            trailing: '${bundle.ratings.length} 人',
          ),
          const SizedBox(height: 10),
          _RatingGroups(ratings: bundle.ratings),
        ],

        // ── 正文 ──
        const SizedBox(height: 20),
        Card.filled(
          margin: EdgeInsets.zero,
          shape: AppTheme.cardShape(),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (text.isNotEmpty)
                  Text(
                    text,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(height: 1.6),
                  ),
                if (images.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Icon(Icons.image_outlined,
                          size: 16, color: cs.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text(
                        '正文含 ${images.length} 张图片',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),

        // ── 亮评 ──
        const SizedBox(height: 24),
        _SectionTitle(
          icon: Icons.local_fire_department_rounded,
          text: '这些回复亮了',
          trailing: '${bundle.lights.length} 条',
        ),
        const SizedBox(height: 10),
        if (bundle.lights.isEmpty)
          Card.outlined(
            margin: EdgeInsets.zero,
            shape: AppTheme.cardShape(),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: <Widget>[
                  Icon(Icons.hourglass_empty,
                      size: 18, color: cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '这篇帖子还没有「亮」评（赛事刚结束或原文无高赞回复）',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...bundle.lights.map((r) => _LightCard(reply: r)),

        if (bundle.lights.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          Center(
            child: FilledButton.tonalIcon(
              onPressed: () => _openLightsSheet(context),
              icon: const Icon(Icons.expand_more),
              label: const Text('展开全部亮评'),
            ),
          ),
        ],
      ],
    );
  }

  void _openLightsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (ctx2, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: <Widget>[
            Text(
              '这些回复亮了',
              style: Theme.of(ctx2).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            ...bundle.lights.map((r) => _LightCard(reply: r)),
          ],
        ),
      ),
    );
  }
}

/// 评分分组：红方 / 蓝方（按 team 字段判断，未知则归到同组）
class _RatingGroups extends StatelessWidget {
  const _RatingGroups({required this.ratings});

  final List<PlayerRating> ratings;

  @override
  Widget build(BuildContext context) {
    final red = ratings.where((r) => r.isRedSide).toList();
    final blue = ratings.where((r) => !r.isRedSide).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (red.isNotEmpty) ...<Widget>[
          _SideLabel(text: '红方', color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: red.map((r) => _RatingChip(rating: r)).toList(),
          ),
          const SizedBox(height: 14),
        ],
        if (blue.isNotEmpty) ...<Widget>[
          _SideLabel(text: '蓝方', color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: blue.map((r) => _RatingChip(rating: r)).toList(),
          ),
        ],
      ],
    );
  }
}

class _SideLabel extends StatelessWidget {
  const _SideLabel({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 4,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(text, style: Theme.of(context).textTheme.labelLarge),
      ],
    );
  }
}

/// 评分胶囊徽章：分数决定配色（高→主色，低→error）
class _RatingChip extends StatelessWidget {
  const _RatingChip({required this.rating});

  final PlayerRating rating;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = AppTheme.scoreColors(cs, rating.score);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                rating.name,
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: c.fg),
              ),
              if (rating.role.isNotEmpty)
                Text(
                  rating.role,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      // 用 withOpacity 而非 withValues：后者需要 Flutter 3.27+
                      ?.copyWith(color: c.fg.withOpacity(0.75)),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Text(
            rating.score.toStringAsFixed(1),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: c.fg,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _LightCard extends StatelessWidget {
  const _LightCard({required this.reply});

  final LightReply reply;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
                  Icon(Icons.person_outline, size: 14, color: cs.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      reply.author.isEmpty ? '匿名' : reply.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                  const Spacer(),
                  // 亮数徽章
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.wb_sunny_outlined,
                            size: 12, color: cs.onSecondaryContainer),
                        const SizedBox(width: 3),
                        Text(
                          '${reply.lightCount}',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: cs.onSecondaryContainer),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                reply.content,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.text,
    this.trailing,
  });

  final IconData icon;
  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        Icon(icon, size: 20, color: cs.primary),
        const SizedBox(width: 8),
        Text(
          text,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const Spacer(),
        if (trailing != null)
          Text(
            trailing!,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
      ],
    );
  }
}
