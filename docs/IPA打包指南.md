# 无签名 .ipa 打包指南

> 目标：生成 `HupuLOL_Unsigned.ipa`，用 Sideloadly / AltStore / TrollStore 装到 iPhone。

---

## 前提

| 项 | 说明 |
|---|---|
| iOS 工程 | **仓库里没有 `ios/` 目录**（只提交了 `lib/` 与 `pubspec.yaml`）。脚本会自动 `flutter create --platforms=ios` 生成，不需要你手动建。 |
| Bundle ID | 默认 `com.hupulol.hupu_lol`。若与他人冲突，在 `src/ios/Runner.xcodeproj` 里改，或改 `--org`。 |
| 网络 | 构建时需访问 `pub.dev` 与 CocoaPods 仓库；构建后的 App 运行时只访问 `bbs.hupu.com` 与 `games.mobileapi.hupu.com`。 |
| ATS | 全部接口都是 HTTPS，**无需**改 `Info.plist` 的 `NSAppTransportSecurity`。 |

---

## 方式 A：GitHub Actions 云端打包（推荐，无需 Mac）

### 1. 推到 GitHub

项目不是 git 仓库，先初始化（在 `project_21_LoL赛事虎扑评分App/` 目录下）：

```bash
git init
git add .
git commit -m "feat: LoL 赛事与虎扑评分 App（Material 3）"
git branch -M main
git remote add origin https://github.com/<你的用户名>/<仓库名>.git
git push -u origin main
```

### 2. 触发打包

1. 打开仓库页面 → **Actions** 标签
2. 左侧选 **Build Unsigned IPA**
3. 右上角 **Run workflow** → 分支选 `main` → 点绿色按钮
4. 等 **5–10 分钟**（首次要下载 Flutter SDK，之后有缓存会快些）

也可以用 tag 触发：

```bash
git tag v1.0.0 && git push --tags
```

### 3. 下载 ipa

运行结束后：

1. 点进那次运行记录
2. 页面底部 **Artifacts** 区域
3. 下载 **HupuLOL_Unsigned**（是一个 zip）
4. 解压得到 `HupuLOL_Unsigned.ipa`

> Artifact 保留 30 天。

---

## 方式 B：本地 macOS 打包

```bash
cd project_21_LoL赛事虎扑评分App
chmod +x build_ipa.sh
./build_ipa.sh
```

产物：`out/HupuLOL_Unsigned.ipa`，脚本会打印体积与 SHA256。

脚本做的事（和 CI 完全一致）：

```
检查 flutter / xcodebuild
  → 缺 ios/ 就 flutter create --platforms=ios
  → flutter pub get + pod install
  → flutter build ios --release --no-codesign
  → Payload/Runner.app → 去掉 _CodeSignature → zip 成 ipa
```

---

## 安装到 iPhone

| 工具 | 适用 | 说明 |
|---|---|---|
| **Sideloadly** | 通用（Windows/macOS） | 拖入 ipa → 填 Apple ID → 签名安装。免费账号 **7 天**需重签 |
| **AltStore** | 通用 | My Apps → `+` → 选 ipa。同样 7 天限制，需 AltServer 在局域网 |
| **TrollStore** | **仅特定 iOS 版本**（有 CoreTrust 漏洞的版本） | 直接打开 ipa 安装，**永久有效、无需签名** |

> 未签名包本身不能直接在普通设备上运行，必须经上述工具签名/安装。

---

## 常见问题

**Q：Actions 报 `flutter create` 之后 pubspec 被改？**
A：`flutter create` 只补缺失的平台目录，不会改 `lib/`。若 pubspec 被格式化，提交回去即可。

**Q：`pod install` 失败**
A：
```bash
cd src/ios && rm -rf Pods Podfile.lock && pod repo update && pod install
```

**Q：`Runner.app` 不存在**
A：上一步 `flutter build ios` 失败了，往下翻日志找第一条 error。最常见是 Dart 编译错误（本项目未经本地编译验证，若有报错贴出来改）。

**Q：装上去闪退**
A：签名问题（证书/描述文件不匹配），与 ipa 内容无关。换 Sideloadly 重签，或确认设备已信任证书（设置 → 通用 → VPN与设备管理）。

**Q：图标是 Flutter 默认图标**
A：本项目暂未放自定义图标资源。要换的话，准备 1024×1024 的 PNG，用 `flutter_launcher_icons` 生成，或直接替换 `ios/Runner/Assets.xcassets/AppIcon.appiconset/` 下各尺寸。

**Q：想改 Bundle ID 避免冲突**
A：`src/ios/Runner.xcodeproj/project.pbxproj` 里搜 `PRODUCT_BUNDLE_IDENTIFIER`，或在 Xcode 里改 Signing & Capabilities。CI 打包路径下改文本也行。

---

## 说明

- 本项目产出的是**未签名包**，仅供自己设备安装调试，**不用于分发**。
- 应用只读虎扑公开页面/接口，不采集、不上传任何用户数据。
