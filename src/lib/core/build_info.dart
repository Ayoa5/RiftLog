// 构建标识：用于在设备上快速确认装的是哪一版
//
// 为什么要硬编码：工程没有引入 package_info_plus（沙箱装包不稳），
// 而 iOS 桌面又看不到版本号。每个改动阶段递增 [_buildStage]，打包后
// 在「关于」页顶部就能一眼确认是不是新包。

const String kAppVersion = '1.2.0';

/// 界面改造阶段标识 —— 每次大改动就改这里，并在关于页展示
const String kBuildStage = 'iOS 风格 · 第 2 轮（大标题 + 白卡）';

/// 与 commit 对齐，便于回溯
const String kBuildDate = '2026-10-31';
const String kBuildCommit = '3db243c';
