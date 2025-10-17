#!/usr/bin/env bash
set -euo pipefail

PRODUCT="MacSweeperApp"
APP_NAME="Mac 清风"
BUNDLE_ID="com.macsweeper.app"

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
BUILD_DIR="$ROOT_DIR/.build/release"
EXEC_PATH="$BUILD_DIR/$PRODUCT"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/MacSweeper.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RES="$CONTENTS/Resources"

echo "[1/4] 构建 Release 可执行文件..."
swift build -c release --product "$PRODUCT"

echo "[2/4] 组装 .app Bundle..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RES"
cp "$ROOT_DIR/Distribution/Info.plist" "$CONTENTS/Info.plist"
cp "$EXEC_PATH" "$MACOS/$PRODUCT"

# 可选：复制图标（如有）到 Resources 并在 plist 中配置 CFBundleIconFile
# cp "$ROOT_DIR/Distribution/AppIcon.icns" "$RES/AppIcon.icns" || true

echo "[3/4] 创建 DMG 包..."
mkdir -p "$DIST_DIR"
DMG_PATH="$DIST_DIR/MacSweeper.dmg"
rm -f "$DMG_PATH"
hdiutil create -volname "$APP_NAME" -srcfolder "$APP_DIR" -ov -format UDZO "$DMG_PATH"

echo "[4/4] 完成 ✅"
echo "DMG 路径：$DMG_PATH"