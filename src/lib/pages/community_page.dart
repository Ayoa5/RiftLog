// 社区页：虎扑英雄联盟板块帖子流（含 [赛后] 过滤）
// 纯 Material 3，无任何 Cupertino 组件

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../core/theme.dart';
import '../models/hupu_models.dart';
import '../services/hupu_scraper_service.dart';
import 'thread_detail_page.dart';

class CommunityPage extends ConsumerStatefulWidget {
  const CommunityPage({super.key});

  @override
  ConsumerState<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends ConsumerState<CommunityPage> {
  /// 只看赛后帖（有评分的那类）
  bool _postMatchOnly = false;

  @override
  Widget build(BuildContext context) {
    final asyncThreads = ref.watch(zoneThreadsProvider('lol'));
    final cs = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(zoneThreadsProvider('lol'));
        await ref.read(zoneThreadsProvider('lol').future);
      },
      child: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar.large(
            title: const Text('英雄联盟 · 赛事'),
            actions: <Widget>[
              IconButton(
                tooltip: _postMatchOnly ? '显示全部' : '只看赛后',
                icon: Icon(
                  _postMatchOnly ? Icons.filter_alt : Icons.filter_alt_outlined,
                ),
                onPressed: () => setState(() => _postMatchOnly = !_postMatchOnly),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: <Widget>[
                  Icon(Icons.forum_outlined, size: 18, color: cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _postMatchOnly
                          ? '只显示带 [赛后] 标记的帖子'
                          : '虎扑 · 英雄联盟板块（实时）',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ...asyncThreads.when<List<Widget>>(
            data: (all) {
              final list =
                  _postMatchOnly ? HupuScraperService.postMatchOnly(all) : all;
              if (list.isEmpty) {
                return <Widget>[
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyView(
                      text: _postMatchOnly ? '当前没有 [赛后] 帖' : '暂无数据',
                    ),
                  ),
                ];
              }
              return <Widget>[
                SliverList.builder(
                  itemCount: list.length,
                  itemBuilder: (context, i) => _ThreadCard(thread: list[i]),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ];
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
                child: _ErrorView(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(zoneThreadsProvider('lol')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThreadCard extends StatelessWidget {
  const _ThreadCard({required this.thread});

  final HupuThread thread;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isPostMatch = thread.isPostMatch;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Card.filled(
        margin: EdgeInsets.zero,
        shape: AppTheme.cardShape(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ThreadDetailPage(
                tid: thread.tid,
                title: thread.title,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (isPostMatch)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '赛后 · 有评分',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: cs.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ),
                Text(
                  thread.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        height: 1.35,
                      ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Icon(Icons.person_outline,
                        size: 15, color: cs.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        thread.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(Icons.chat_bubble_outline,
                        size: 15, color: cs.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      '${thread.replies}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                    const Spacer(),
                    Text(
                      thread.timeText,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
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

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.inbox_outlined, size: 48, color: cs.outline),
          const SizedBox(height: 12),
          Text(text, style: TextStyle(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.cloud_off_outlined, size: 48, color: cs.error),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
