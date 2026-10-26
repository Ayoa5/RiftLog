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
| Step 3 | 赛程页 / 比赛详情（局切换）/ 社区页 / 评分页 | ✅ 已完成（三页导航 + 真实赛程） |
| Step 4 | GitHub Actions 无签名 ipa + 本地 `build_ipa.sh` | ✅ 已完成 |

**怎么打包、怎么装到手机** → 见 `docs/IPA打包指南.md`

---

## 二、虎扑接口实测结论（重要）

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
project_21_LoL赛事虎扑评分App/
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
│       │   ├── hupu_models.dart      ← Thread / ThreadDetail / LightReply
│       │   └── rating_models.dart    ← ScoreItem / RatingBundle（评分）
│       ├── services/
│       │   ├── hupu_client.dart      ← dio 封装（UA 伪装/超时/重试/错误抽象）
│       │   ├── hupu_scraper_service.dart  ← 列表 / 详情 / 亮评
│       │   ├── hupu_rating_service.dart   ← 评分（实测可用接口）
│       │   └── rating_provider.dart  ← 正文内嵌评分抽象层（备用）
│       └── pages/
│           ├── schedule_page.dart    ← SliverAppBar.large + Card.filled 列表
│           ├── thread_detail_page.dart ← 正文 + 亮评 + 评分入口
│           └── rating_page.dart      ← 粘贴评分链接 → 全阵容评分
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
