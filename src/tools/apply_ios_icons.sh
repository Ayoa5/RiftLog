#!/usr/bin/env bash
# 把 assets/icon 下的「评」字图标应用为 iOS AppIcon（含 iOS 18 的深色 / 着色态）
#
# 用法（在 Flutter 工程根目录执行）：
#   bash tools/apply_ios_icons.sh
#
# 前置：ios/ 目录已存在（flutter create 或已 clone 的工程）
#
# 说明：
#   · 采用 Xcode 15+ 的「单尺寸 + 外观变体」格式，只需 3 张 1024 图，
#     其余尺寸由 actool 自动生成，不再维护一长串 png。
#   · AppIcon-1024.png（Any）必须**不带透明通道**，否则 App Store 校验会拒。
#   · Dark / Tinted 两态由系统在深色模式 / 着色模式下自动选用。

set -euo pipefail

SRC_DIR="${1:-assets/icon}"
DEST="${2:-ios/Runner/Assets.xcassets/AppIcon.appiconset}"

if [ ! -d "$SRC_DIR" ]; then
  echo "❌ 找不到图标目录：$SRC_DIR" >&2
  exit 1
fi
if [ ! -d "$DEST" ]; then
  echo "❌ 找不到 $DEST（iOS 工程还没生成？）" >&2
  exit 1
fi

for f in icon_light_1024.png icon_dark_1024.png icon_tinted_1024.png; do
  if [ ! -f "$SRC_DIR/$f" ]; then
    echo "❌ 缺少 $SRC_DIR/$f" >&2
    exit 1
  fi
done

mkdir -p "$DEST"

# 1) 清掉模板自带的旧尺寸图，避免 actool 因缺图报错
find "$DEST" -maxdepth 1 -name '*.png' -delete

# 2) 放三态图
cp -f "$SRC_DIR/icon_light_1024.png"  "$DEST/AppIcon-1024.png"
cp -f "$SRC_DIR/icon_dark_1024.png"   "$DEST/AppIcon-1024-dark.png"
cp -f "$SRC_DIR/icon_tinted_1024.png" "$DEST/AppIcon-1024-tinted.png"

# 3) 写单尺寸 + 外观变体的 Contents.json
cat > "$DEST/Contents.json" <<'JSON'
{
  "images" : [
    {
      "filename" : "AppIcon-1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "filename" : "AppIcon-1024-dark.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "tinted"
        }
      ],
      "filename" : "AppIcon-1024-tinted.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON

echo "✅ 已应用 AppIcon（Any / Dark / Tinted）→ $DEST"
ls -1 "$DEST"
