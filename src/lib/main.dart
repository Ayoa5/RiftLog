// 入口：Material 3 + Monet 动态取色 + 底部 NavigationBar（胶囊指示器）
// 全程不使用任何 Cupertino 组件（无 CupertinoPageRoute / CupertinoButton / CupertinoSwitch）

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'pages/schedule_page.dart';

void main() {
  runApp(const ProviderScope(child: HupuLolApp()));
}

class HupuLolApp extends StatelessWidget {
  const HupuLolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppThemeScope(
      builder: (light, dark) => MaterialApp(
        title: 'LoL 赛事 · 虎扑评分',
        debugShowCheckedModeBanner: false,
        theme: light,
        darkTheme: dark,
        themeMode: ThemeMode.system,
        home: const RootShell(),
      ),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const <Widget>[
          SchedulePage(),
          _AboutPage(),
        ],
      ),
      // 安卓风格胶囊形选中指示器
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.sports_esports_outlined),
            selectedIcon: Icon(Icons.sports_esports),
            label: '赛程',
          ),
          NavigationDestination(
            icon: Icon(Icons.info_outline),
            selectedIcon: Icon(Icons.info),
            label: '关于',
          ),
        ],
      ),
    );
  }
}

class _AboutPage extends StatelessWidget {
  const _AboutPage();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return CustomScrollView(
      slivers: <Widget>[
        const SliverAppBar.large(title: Text('关于')),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          sliver: SliverList.list(
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
                        '虎扑社区公开页面与 API（无需登录）：\n'
                        '· 板块列表：bbs.hupu.com/{板块} 的 SSR 数据\n'
                        '· 帖子详情与亮评：bbs.hupu.com/api/v2/threads\n\n'
                        '本应用为纯客户端直连，不含自建服务器，不采集、不上传任何用户数据。',
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
                          Icon(Icons.palette_outlined,
                              size: 18, color: cs.primary),
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
            ],
          ),
        ),
      ],
    );
  }
}
