# LoL 赛事 & 虎扑评分 App（Material You / 莫奈风格 · iOS）

> Flutter 单端项目：iOS 打包成**无签名 .ipa**（Sideloadly / AltStore / TrollStore 安装）
> UI 100% Material Design 3，**不使用任何 Cupertino 组件**
> 纯客户端直连虎扑公开数据，无自建后端

---

## 一、当前进度

| 阶段 | 内容 | 状态 |
|---|---|---|
| Step 1 | 项目骨架、pubspec、主题、目录结构 | ✅ 已完成 |
| Step 2 | 虎扑抓取与解析层（列表 / 详情 / 亮评 / **评分**） | ✅ 已完成 |
| Step 3 | 赛程页 / 比赛详情（局切换 + 局况概览）/ 预告页 | ✅ 已完成（**2026-11-15 移除社区，改为两页导航**） |
| Step 4 | GitHub Actions 无签名 ipa + 本地 `build_ipa.sh` | ✅ 已完成 |

**怎么打包、怎么装到手机** → 见 `docs/IPA打包指南.md`

---

## 二、虎扑接口实测结论（重要）

> **2026-11-15**：社区功能已移除，下表的「板块列表 / 帖子详情 / 亮评」三条接口**不再是本 App 的依赖**，
> 仅作历史实测记录保留；当前只使用评分链路（lol_match / lol_bo / lol_item + 评论接口）。

**全部实测可用**（2026-10-26，iOS 移动端 UA，**无需登录**）：

| # | 用途 | 端点 |
|---|---|---|
| 1 | 板块帖子列表 | `GET https://bbs.hupu.com/{zone}` → SSR 的 `__NEXT_DATA__` |
| 2 | 帖子详情 | `GET https://bbs.hupu.com/api/v2/threads?tid={tid}` |
| 3 | **亮评（神评）** | 同上 → `data.lights[]` |
| 4 | **选手评分** | `GET https://games.mobileapi.hupu.com/1/8.2.99/bplcommentapi/bpl/score_tree/getCurAndSubNodeByBizKey` |
| 5 | 单场比赛信息 | 同域 `/bpl/score_tree/getSelfByBizKey?outBizType=lol_match&outBizNo={id}` |
| 6 | 局的选手评分 | 同域 `getCurAndSubNodeByBizKey?relation=CHILD&outBizType=lol_bo&outBizNo={id}` |
| 7 | **未开赛赛程** | `GET https://lpl.qq.com/web201612/data/LOL_MATCH2_MATCH_HOMEPAGE_BMATCH_LIST_246.js`（静态 JSON） |
| 8 | 选手评论 | 同域 `/bpl/comment/list/primarySingleRow`（最晚/最早）与 `.../hottest`（最亮） |

实测样例（局 `lol_bo:7717`，iG vs HLE）：

```
JiaQi 10.0 (112,916) · TheShy 9.8 · Meiko 9.9 · Wei 9.9 · Rookie 9.9 · 教练 Helper 9.8
Gumayusi 2.4 · Zeus 7.6 · Kanavi 4.0 · Delight 3.0 · Zeka 2.8 · 教练 Homme 2.8
```

**完整链路**：评分页 URL → `outBizType/outBizNo` → `getSelfByBizKey` 反查所属「局」
→ `getCurAndSubNodeByBizKey` 取 24 条子节点 → 按 `infoJson.type` 过滤 player/coach
→ 按 `infoJson.teamId` 分阵营。

**赛程怎么来的**：虎扑没有「赛事列表」接口（根节点 `lol:1` 的 subNodeCount=0，
`lol_competition`/`lol_season` 均不存在）。但同一赛事内 `lol_match` 的 bizId **连续**
（实测 4501–4516 连成一片），所以 App 用「锚点 + 向两侧逐号探测，连续 3 次未命中即停」来发现比赛，
结果按 `matchTime` 倒序、按日期分组展示。

**未开赛预告走 LPL 官方**：虎扑只有「已开赛/已结束」的比赛节点，
赛前预告取自腾讯 LPL 官网的**静态 JSON**（无需签名）：



gameId=246 是 2026 全球总决赛，46 场（26 已结束 + 20 未开始，含 10-27 起的对阵）。
App 里「即将开始」用 LPL 数据，「已结束」用 LPL 列表 + 按「队名+日期」匹配虎扑节点挂评分入口。

详见 `docs/虎扑接口实测记录_20261026.md` 第五、六、七、九节。

---

## 三、目录结构

```
project_20_LoL赛事虎扑评分App/
├── README.md
├── build_ipa.sh                      ← 本地一键打包（macOS）
├── .github/workflows/build_ipa.yml   ← 云端无签名打包
├── src/                              ← Flutter 工程根
│   ├── pubspec.yaml
│   ├── analysis_options.yaml
│   └── lib/
│       ├── main.dart                 ← 入口 + MaterialApp（M3 + Monet）
│       ├── core/
│       │   └── theme.dart            ← ColorScheme.fromSeed / dynamic_color / 深浅色
│       ├── models/
│       │   ├── hupu_models.dart      ← PlayerRating（社区相关模型已删）
│       │   └── rating_models.dart    ← ScoreItem / RatingBundle（评分）
│       ├── services/
│       │   ├── hupu_client.dart      ← dio 封装（UA 伪装/超时/重试/错误抽象）
│       │   ├── hupu_scraper_service.dart  ← 只剩评论 HTML→纯文本
│       │   ├── hupu_rating_service.dart   ← 评分（实测可用接口）
│       │   └── rating_provider.dart  ← 正文内嵌评分抽象层（备用）
│       └── pages/
│           ├── schedule_page.dart    ← 赛程（已结束战报，带评分入口）
│           ├── upcoming_page.dart    ← 预告（未开赛，来自 LPL 官方赛程）
│           ├── rating_page.dart      ← 粘贴评分链接 → 全阵容评分
│           ├── match_detail_page.dart ← 比赛详情（局切换 + 评分 + 评论楼中楼）
│           └── about_page.dart       ← 关于（右上角入口）
├── tools/
│   └── probe_hupu.py                 ← 接口探针（列表/详情/评分三模式）
└── docs/
    ├── 虎扑接口实测记录_20261026.md
    └── IPA打包指南.md                 ← 触发打包 / 下载 / 安装 / 排错
```

---

## 四、本地运行 / 打包

**前提**：Flutter SDK ≥ 3.24（Dart ≥ 3.5）。

```bash
cd src
flutter pub get
flutter run            # iOS 真机需签名；模拟器可直接跑
```

**导出无签名 ipa**（macOS）：

```bash
cd ..
chmod +x build_ipa.sh
./build_ipa.sh         # 产物：out/HupuLOL_Unsigned.ipa
```

**云端打包**（无需 Mac）：

1. 推到 GitHub → 仓库 **Actions** 页
2. 选 **Build Unsigned IPA** → **Run workflow**
3. 约 5–10 分钟后，页面底部 **Artifacts → HupuLOL_Unsigned** 下载
4. 解压得到 `.ipa`，用 Sideloadly / AltStore / TrollStore 安装

> 详细步骤、Bundle ID 修改、常见报错处理见 `docs/IPA打包指南.md`。
>
> ⚠️ 本机未安装 Flutter，代码未经本地编译验证；首次 `flutter pub get` / `flutter analyze`
> 若有报错，按提示修即可（CI 里 `analyze` 设为不阻断，保证仍能出包）。

---

## 五、设计约定（别破坏）

1. **零 Cupertino**：不用 `CupertinoPageRoute` / `CupertinoSwitch` / `CupertinoButton`。
   页面切换用 `PageRouteBuilder` 或 Material 默认转场。
2. **颜色全部来自 `ColorScheme`**：不写死 `Colors.red` 之类，用 `colorScheme.error` /
   `colorScheme.primaryContainer`，否则深色模式和 Monet 取色会崩。
3. **圆角 24**：卡片统一 `BorderRadius.circular(24)`，用 `Card.filled` / `Card.outlined`，
   不用 elevation 阴影做层级（改用 `surfaceContainerLow` → `surfaceContainerHigh` 色阶）。
4. **请求必须带移动端 UA**：虎扑对桌面 UA 返回不同结构（实测 `bbs.hupu.com/lol`
   在桌面 UA 下不含 `__NEXT_DATA__`）。

---

## 六、2026-11-15 变更（v1.4.0）

### 1. 移除社区（彻底删除）
- 底部导航由 3 页改为 **2 页**：赛程 / 预告
- 删除文件：`pages/community_page.dart`、`pages/thread_detail_page.dart`
- 删除代码：`providers.dart` 的 `scraperProvider` / `zoneThreadsProvider`；
  `hupu_scraper_service.dart` 的 `fetchZoneThreads` / `postMatchOnly` / `fetchThreadBundle` / 亮评解析；
  `hupu_models.dart` 的 `HupuThread` / `ThreadDetail` / `LightReply` / `ThreadBundle`
- `hupu_scraper_service.dart` 只保留评论 HTML→纯文本（评论区仍在用）

### 2. 逐局胜负序列（核心诉求）

用户要的是**每一小局谁赢、以及整场 BO 的胜负走势**，不是系列赛最终谁赢。
虎扑接口没有单局胜负字段（实测局节点 / 局详情 / 选手节点 / LPL 官方赛程 / 局配图都没有），
但每局选手节点带**完整 KDA 与评分**，可据此严谨推导：

实测 `BLG 3-1 T1`（match 4616）四局：

| 局 | 主队击杀 | 客队击杀 | 击杀判胜 | 评分判胜 | 均分 |
|---|---|---|---|---|---|
| 第1局 | 18 | 6 | BLG | BLG | 9.9 : 4.8 |
| 第2局 | 10 | 22 | T1 | T1 | 7.1 : 8.6 |
| 第3局 | 19 | 10 | BLG | BLG | 9.8 : 5.6 |
| 第4局 | 21 | 9 | BLG | BLG | 10.0 : 6.0 |

两个独立信号 4/4 一致，推导序列 `BLG / T1 / BLG / BLG` 正好 3:1。

实现（`models/game_outcome.dart` + `HupuMatchService.fetchGameOutcomes`）：
1. 并发拉取各局评分，按 `teamId` 累加选手击杀，多者判为本局胜方；
2. 用两队**平均评分**交叉验证（不一致 → `reliable=false`）；
3. 全部局算完后用**胜场数 == 系列赛大比分**自校验（`seriesConsistent`）；
   系列赛未打完时改用宽松校验（胜场数不超过当前比分）；
4. 任一队无数据 / 击杀相同 → 退回评分判定，仍无则判「未知」。

UI：
- **`_SeriesStrip` 小局胜负序列条**：一整行格子，每格 = 一局，蓝=主队胜 / 灰=客队胜，
  格内直接写「BLG 胜」；右上角显示「与比分吻合 / 判定存疑」；点击切局。
- **局列表按局号升序重排**（虎扑 CHILD 实测是倒序 4→1，顺手修好了「进行中自动跳当前局」跳错的 bug）
- `_GameBanner`：`本局 X 获胜`，结论不可靠时降级为「本局 X 领先（待确认）」，
  并注明依据「本局击杀 21:9，评分交叉验证且与系列赛比分吻合」
- 队伍分组：按**本局**胜负显示绿色「胜」/灰色「负」徽章 + `本局击杀 N`
- 评论弹层标题副行：`{队伍名} · {选手/教练} · 本局 KDA x/y/z`
- 比赛头：系列赛胜方队名加粗 + 绿色高亮

> 判定依据全部是虎扑真实对局数据（击杀/评分），三重校验通过才标「获胜」；
> 校验不通过时明确标「待确认」，不冒充官方赛果。若个别翻盘局出现击杀多却输，
> 序列条会用「判定存疑」提示，可再考虑接入第三方赛果源做权威覆盖。

---

## 七、评论弹层交互（v1.4.0 补充）

痛点：爬楼爬太深后，要一路滑回顶部才能关闭评论区 / 换排序。
只加「回顶部」其实没解决「想随时关掉」这个真实目的，所以做了组合方案：

1. **固定头部**：选手名 + 本局结果 + 队伍 +「共 N 条」+ **关闭 ✕** + 排序 chips 常驻顶部
   （`Stack` + `Positioned` 固定 112px，ListView 顶部留出同样空间），滚到多深都能一键关闭。
2. **悬浮「顶部」按钮**：滚动超过 600px 才淡入右下角，点击 280ms 平滑回顶；不挡阅读。
3. **切换排序自动回顶**：最亮 / 最晚 / 最早 切换会重置列表，顺带 `animateTo(0)`。
4. 列表底部留 80px，避免最后一条评论被悬浮按钮盖住。

实现要点：`NotificationListener<ScrollNotification>` 监听 `metrics.pixels` 控制按钮显隐；
`_sheetController` 复用 `DraggableScrollableSheet` 传入的 `ScrollController`，不额外创建滚动控制器。
