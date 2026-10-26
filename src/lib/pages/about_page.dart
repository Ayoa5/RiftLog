// 关于页（从底部导航移到右上角入口后单独成页）

import 'package:flutter/material.dart';

import '../core/theme.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          Card.filled(
            margin: EdgeInsets.zero,
            shape: AppTheme.cardShape(),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '数据来源',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '全部为公开数据，无需登录，不采集任何用户数据：\n\n'
                    '· 赛事预告：腾讯 LPL 官网静态赛程\n'
                    '· 比赛战报与选手评分：虎扑评分接口\n'
                    '· 社区帖子与亮评：虎扑社区公开页面\n'
                    '· 评论与楼中楼：虎扑评论接口\n\n'
                    '纯客户端直连，无自建服务器。',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(height: 1.6),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card.outlined(
            margin: EdgeInsets.zero,
            shape: AppTheme.cardShape(),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(Icons.palette_outlined, size: 18, color: cs.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Material You',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '界面遵循 Material Design 3：大标题折叠顶栏、胶囊导航指示器、'
                    '24px 圆角色阶卡片。Android 上跟随壁纸取色（Monet），'
                    'iOS 上使用蓝紫种子色派生色板。',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(height: 1.6),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card.outlined(
            margin: EdgeInsets.zero,
            shape: AppTheme.cardShape(),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(Icons.info_outline, size: 18, color: cs.primary),
                      const SizedBox(width: 8),
                      Text(
                        '说明',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '本应用为非官方客户端，评分与评论内容版权归虎扑及原作者所有。\n'
                    '未开赛的对阵信息会随官方赛程更新；阵容未定时显示占位名（如 D5G1）。',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(height: 1.6),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 各页 AppBar 右上角的「关于」入口
class AboutIconButton extends StatelessWidget {
  const AboutIconButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '关于',
      icon: const Icon(Icons.info_outline),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const AboutPage()),
      ),
    );
  }
}
