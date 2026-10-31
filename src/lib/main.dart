// 入口：中性色面（iOS 观感）+ 玻璃拟态底部栏
//
// 设计取向（2026-10-29）：
//   不再追 M3 的「彩色底 + 胶囊指示器」，改为贴近 iOS：
//   · 背景用 systemGroupedBackground（浅 #F2F2F7 / 深 #000000），卡片纯白/深灰
//   · 底部栏做成半透明 + 高斯模糊（BackdropFilter），顶部一条发丝线
//   · 无涟漪（NoSplash），选中态靠颜色区分，tap 带轻微缩放反馈
//   注：真·Liquid Glass 的折射/色散拿不到，这里是最接近的模拟。

import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'pages/community_page.dart';
import 'pages/schedule_page.dart';
import 'pages/upcoming_page.dart';

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
        // 让 Cupertino 组件（大标题导航栏）跟着 Material 主题走，
        // 否则深色模式下导航栏会是亮色的。
        builder: (context, child) {
          final m = Theme.of(context);
          final onSurface = m.colorScheme.onSurface;
          return CupertinoTheme(
            data: CupertinoThemeData(
              brightness: m.brightness,
              primaryColor: m.colorScheme.primary,
              scaffoldBackgroundColor: m.colorScheme.surface,
              barBackgroundColor: m.colorScheme.surface,
              textTheme: CupertinoTextThemeData(
                navLargeTitleTextStyle: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.37,
                  color: onSurface,
                ),
                navTitleTextStyle: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: onSurface,
                ),
              ),
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
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
          CommunityPage(),
          UpcomingPage(),
        ],
      ),
      bottomNavigationBar: _GlassTabBar(
        index: _index,
        onChanged: (i) => setState(() => _index = i),
      ),
    );
  }
}

/// 玻璃拟态底部栏：半透明 + 模糊 + 顶部发丝线，无涟漪
class _GlassTabBar extends StatelessWidget {
  const _GlassTabBar({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  static const List<({IconData icon, IconData active, String label})> _tabs =
      <({IconData icon, IconData active, String label})>[
    (icon: Icons.calendar_month_outlined, active: Icons.calendar_month, label: '赛程'),
    (icon: Icons.forum_outlined, active: Icons.forum, label: '社区'),
    (icon: Icons.event_note_outlined, active: Icons.event_note, label: '预告'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = cs.brightness == Brightness.dark;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          decoration: BoxDecoration(
            // 深色下更透明，让内容透出来；浅色下留一点乳白
            color: cs.surfaceContainer.withOpacity(dark ? 0.58 : 0.74),
            border: Border(
              top: BorderSide(
                color: cs.outlineVariant.withOpacity(0.5),
                width: 0.5,
              ),
            ),
          ),
          padding: EdgeInsets.only(
            top: 6,
            bottom: safeBottom > 0 ? safeBottom : 6,
          ),
          child: Row(
            children: <Widget>[
              for (var i = 0; i < _tabs.length; i++)
                Expanded(
                  child: _TabItem(
                    icon: _tabs[i].icon,
                    activeIcon: _tabs[i].active,
                    label: _tabs[i].label,
                    selected: index == i,
                    onTap: () => onChanged(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = selected ? cs.primary : cs.onSurfaceVariant;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AnimatedScale(
              scale: selected ? 1.0 : 0.96,
              duration: const Duration(milliseconds: 150),
              child: Icon(selected ? activeIcon : icon, size: 23, color: color),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 150),
              style: TextStyle(
                fontSize: 10.5,
                height: 1.0,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: color,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
