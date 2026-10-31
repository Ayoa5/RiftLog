// Material 3 主题：ColorScheme.fromSeed + Monet 动态取色 + 深浅色

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  /// iOS 上 dynamic_color 拿不到壁纸取色，回退用这个种子色生成柔和莫奈色板。
  /// 选蓝紫色：接近 LoL 视觉，且 M3 派生出的 tonal palette 对比度舒适。
  static const Color seedColor = Color(0xFF5B4BD6);

  /// 统一圆角：10px —— 对齐 iOS 分组列表（inset grouped）
  static const double radius = 10;

  static ThemeData light(ColorScheme? dynamic) =>
      _build(dynamic ?? ColorScheme.fromSeed(seedColor: seedColor));

  static ThemeData dark(ColorScheme? dynamic) => _build(
        dynamic ??
            ColorScheme.fromSeed(
              seedColor: seedColor,
              brightness: Brightness.dark,
            ),
      );

  /// iOS 风格中性色面：保留 seed 派生的 primary/secondary（品牌色），
  /// 把 surface 家族换成中性灰阶 —— iOS 的层次靠明度差，M3 靠色调。
  static ColorScheme _neutralize(ColorScheme cs) {
    final dark = cs.brightness == Brightness.dark;
    return cs.copyWith(
      surface: dark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
      surfaceContainerLowest: dark ? const Color(0xFF0A0A0B) : const Color(0xFFFFFFFF),
      surfaceContainerLow: dark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF),
      surfaceContainer: dark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF),
      surfaceContainerHigh: dark ? const Color(0xFF2C2C2E) : const Color(0xFFE9E9EE),
      // Card.filled 用的就是这个色：iOS 是「灰底白卡」，所以浅色取纯白
      surfaceContainerHighest: dark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF),
      outlineVariant: dark ? const Color(0xFF38383A) : const Color(0xFFD1D1D6),
    );
  }

  static ThemeData _build(ColorScheme raw) {
    final cs = _neutralize(raw);
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      // M3 的 textTheme 默认是 Roboto；用 Cupertino 的系统字体名，
      // iOS 上会解析成 SF Pro（中文仍回退到苹方），观感立刻贴近系统
      fontFamily: 'CupertinoSystemText',
      scaffoldBackgroundColor: cs.surface,

      // 安卓大标题折叠顶栏：去掉默认着色与阴影，靠色阶区分层级
      appBarTheme: AppBarTheme(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),

      // 底部导航：胶囊形指示器（M3 默认形状，这里显式声明避免主题漂移）
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cs.surfaceContainer,
        indicatorColor: cs.secondaryContainer,
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        elevation: 0,
      ),

      // 无生硬阴影：卡片靠填充色 / 描边区分
      dividerTheme: DividerThemeData(
        color: cs.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      splashFactory: NoSplash.splashFactory,
    );
  }

  /// 卡片装饰：24px 圆角 + 无阴影。filled 与 outlined 两种语义分别取不同容器色阶。
  static RoundedRectangleBorder cardShape() =>
      const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(radius)),
      );

  /// 评分徽章配色：高分用主色系，低分用 error 系，中间用中性容器色。
  static ({Color bg, Color fg}) scoreColors(ColorScheme cs, double score) {
    if (score >= 9.0) {
      return (bg: cs.primaryContainer, fg: cs.onPrimaryContainer);
    }
    if (score >= 7.0) {
      return (bg: cs.secondaryContainer, fg: cs.onSecondaryContainer);
    }
    if (score >= 5.0) {
      return (bg: cs.surfaceContainerHigh, fg: cs.onSurfaceVariant);
    }
    return (bg: cs.errorContainer, fg: cs.onErrorContainer);
  }
}

/// 包一层 DynamicColorBuilder，统一处理「安卓取壁纸色 / iOS 回退 seed」。
class AppThemeScope extends StatelessWidget {
  const AppThemeScope({super.key, required this.builder});

  final Widget Function(ThemeData light, ThemeData dark) builder;

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) => builder(
        AppTheme.light(lightDynamic),
        AppTheme.dark(darkDynamic),
      ),
    );
  }
}
