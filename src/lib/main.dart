// 入口：Material 3 + Monet 动态取色 + 底部 NavigationBar（胶囊指示器）
// 全程不使用任何 Cupertino 组件（无 CupertinoPageRoute / CupertinoButton / CupertinoSwitch）

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
      // 安卓风格胶囊形选中指示器
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: '赛程',
          ),
          NavigationDestination(
            icon: Icon(Icons.forum_outlined),
            selectedIcon: Icon(Icons.forum),
            label: '社区',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note),
            label: '预告',
          ),
        ],
      ),
    );
  }
}
