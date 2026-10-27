#!/usr/bin/env bash
# 本地一键生成无签名 .ipa（在 macOS 上运行）
#
# 用法：
#   chmod +x build_ipa.sh
#   ./build_ipa.sh
#
# 产物：out/HupuLOL_Unsigned.ipa
# 安装：Sideloadly / AltStore / TrollStore（未签名包需自行签名）

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$PROJECT_ROOT/src"
OUT_DIR="$PROJECT_ROOT/out"
IPA_NAME="HupuLOL_Unsigned.ipa"

info() { printf "\033[1;36m▶ %s\033[0m\n" "$1"; }
ok()   { printf "\033[1;32m✓ %s\033[0m\n" "$1"; }
die()  { printf "\033[1;31m✗ %s\033[0m\n" "$1" >&2; exit 1; }

# ── 环境检查 ───────────────────────────────────────────────
command -v flutter >/dev/null 2>&1 || die "未找到 flutter，请先安装 Flutter SDK 并加入 PATH"
command -v xcodebuild >/dev/null 2>&1 || die "未找到 xcodebuild，请安装 Xcode（且已执行 xcode-select --install）"

if ! xcodebuild -version >/dev/null 2>&1; then
  die "Xcode 未就绪：请打开 Xcode 完成首次初始化并同意许可协议（sudo xcodebuild -license accept）"
fi

if ! command -v pod >/dev/null 2>&1; then
  echo "⚠ 未找到 CocoaPods，尝试继续（若 pod install 失败请先安装：sudo gem install cocoapods）"
fi

info "Flutter 版本"
flutter --version | head -3

cd "$SRC_DIR"

# ── iOS 工程 ───────────────────────────────────────────────
if [ ! -d "ios" ]; then
  info "ios/ 不存在，用 flutter create 生成 iOS 工程"
  flutter create --platforms=ios --org com.hupulol .
else
  ok "ios/ 已存在"
fi

# 应用「评」字 AppIcon（Any / Dark / Tinted 三态）
if [ -f "tools/apply_ios_icons.sh" ]; then
  info "应用自定义 AppIcon"
  bash tools/apply_ios_icons.sh
fi

info "拉取依赖"
flutter pub get

# ── 构建 ───────────────────────────────────────────────────
# 注意：flutter create 不生成 Podfile；--config-only 会生成 Podfile 并跑 pod install。
# 必须同时带 --no-codesign，否则 config-only 也会先做证书检查并失败。
info "生成构建配置（config-only）"
flutter build ios --release --config-only --no-codesign

if [ -f "ios/Podfile" ] && command -v pod >/dev/null 2>&1; then
  info "pod install"
  (cd ios && pod install --repo-update)
else
  ok "无 Podfile（可能没有原生插件），将用 Runner.xcodeproj 构建"
fi

# 直接 xcodebuild + 显式关闭签名。
# 原因：flutter build ios --no-codesign 在「无 DEVELOPMENT_TEAM 的工程」上
# 仍会被 Xcode 15+ 的签名校验拦住。
info "Xcode 无签名构建"
(
  cd ios
  for f in Flutter/Release.xcconfig Flutter/Debug.xcconfig; do
    if [ -f "$f" ] && ! grep -q CODE_SIGNING_ALLOWED "$f"; then
      echo 'CODE_SIGNING_ALLOWED=NO' >> "$f"
    fi
  done
  if [ -d Runner.xcworkspace ]; then
    ENTRY="-workspace Runner.xcworkspace"
  else
    ENTRY="-project Runner.xcodeproj"
  fi
  echo "构建入口: $ENTRY"
  # shellcheck disable=SC2086
  xcodebuild $ENTRY \
    -scheme Runner \
    -configuration Release \
    -sdk iphoneos \
    -destination 'generic/platform=iOS' \
    -derivedDataPath ../build/ios_dd \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGN_ENTITLEMENTS="" \
    build | tail -30
)

APP_PATH="build/ios_dd/Build/Products/Release-iphoneos/Runner.app"
[ -d "$APP_PATH" ] || die "构建产物不存在：$APP_PATH"

# ── 打包 ───────────────────────────────────────────────────
info "打包为未签名 .ipa"
rm -rf build/ipa_stage
mkdir -p build/ipa_stage/Payload
cp -R "$APP_PATH" build/ipa_stage/Payload/
# 无签名包不应带 _CodeSignature
rm -rf "build/ipa_stage/Payload/Runner.app/_CodeSignature"

(cd build/ipa_stage && zip -qry "$IPA_NAME" Payload)

mkdir -p "$OUT_DIR"
cp "build/ipa_stage/$IPA_NAME" "$OUT_DIR/$IPA_NAME"

echo
ok "完成：$OUT_DIR/$IPA_NAME"
ls -lh "$OUT_DIR/$IPA_NAME"
echo
echo "SHA256:"
shasum -a 256 "$OUT_DIR/$IPA_NAME"
echo
echo "下一步："
echo "  1) 用 Sideloadly 拖入该 ipa，填 Apple ID 签名后安装"
echo "  2) 或 AltStore：My Apps → + → 选择该 ipa"
echo "  3) TrollStore（仅支持的 iOS 版本）：直接打开 ipa 安装，无需签名"
echo
echo "提示：若安装后闪退，多为签名证书问题，与 ipa 本身无关。"
