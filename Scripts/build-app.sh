#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="QuotaBar"
APP="$ROOT/.build/$APP_NAME.app"
EXECUTABLE="$ROOT/.build/arm64-apple-macosx/release/CodexUsageWidgetApp"
WIDGET_EXECUTABLE="$ROOT/.build/arm64-apple-macosx/release/CodexUsageNativeWidgetExtension"
WIDGET="$APP/Contents/PlugIns/CodexUsageNativeWidgetExtension.appex"
ICON_SOURCE="$ROOT/Resources/QuotaBar.svg"
ICONSET="$ROOT/.build/QuotaBar.iconset"
ICON_FILE="$APP/Contents/Resources/QuotaBar.icns"

cd "$ROOT"
swift build -c release --arch arm64

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$WIDGET/Contents/MacOS"
cp "$EXECUTABLE" "$APP/Contents/MacOS/CodexUsageWidgetApp"
cp "$WIDGET_EXECUTABLE" "$WIDGET/Contents/MacOS/CodexUsageNativeWidgetExtension"

if [[ ! -f "$ICON_SOURCE" ]]; then
  echo "Missing icon source: $ICON_SOURCE" >&2
  exit 1
fi
if ! command -v magick >/dev/null 2>&1; then
  echo "ImageMagick 'magick' is required to build the app icon." >&2
  exit 1
fi
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
magick -background none "$ICON_SOURCE" -resize 16x16 "$ICONSET/icon_16x16.png"
magick -background none "$ICON_SOURCE" -resize 32x32 "$ICONSET/icon_16x16@2x.png"
magick -background none "$ICON_SOURCE" -resize 32x32 "$ICONSET/icon_32x32.png"
magick -background none "$ICON_SOURCE" -resize 64x64 "$ICONSET/icon_32x32@2x.png"
magick -background none "$ICON_SOURCE" -resize 128x128 "$ICONSET/icon_128x128.png"
magick -background none "$ICON_SOURCE" -resize 256x256 "$ICONSET/icon_128x128@2x.png"
magick -background none "$ICON_SOURCE" -resize 256x256 "$ICONSET/icon_256x256.png"
magick -background none "$ICON_SOURCE" -resize 512x512 "$ICONSET/icon_256x256@2x.png"
magick -background none "$ICON_SOURCE" -resize 512x512 "$ICONSET/icon_512x512.png"
magick -background none "$ICON_SOURCE" -resize 1024x1024 "$ICONSET/icon_512x512@2x.png"
iconutil -c icns "$ICONSET" -o "$ICON_FILE"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>zh_CN</string>
  <key>CFBundleDisplayName</key>
  <string>QuotaBar</string>
  <key>CFBundleExecutable</key>
  <string>CodexUsageWidgetApp</string>
  <key>CFBundleIdentifier</key>
  <string>org.dongx.quota.bar</string>
  <key>CFBundleIconFile</key>
  <string>QuotaBar</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>QuotaBar</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>CFBundleSupportedPlatforms</key>
  <array>
    <string>MacOSX</string>
  </array>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHumanReadableCopyright</key>
  <string>Copyright © 2026 QuotaBar contributors.</string>
</dict>
</plist>
PLIST

cat > "$WIDGET/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>zh_CN</string>
  <key>CFBundleDisplayName</key>
  <string>QuotaBar</string>
  <key>CFBundleExecutable</key>
  <string>CodexUsageNativeWidgetExtension</string>
  <key>CFBundleIdentifier</key>
  <string>org.dongx.quota.bar.native-widget</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>QuotaBar Widget</string>
  <key>CFBundlePackageType</key>
  <string>XPC!</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>CFBundleSupportedPlatforms</key>
  <array>
    <string>MacOSX</string>
  </array>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHumanReadableCopyright</key>
  <string>Copyright © 2026 QuotaBar contributors.</string>
  <key>NSExtension</key>
  <dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.widgetkit-extension</string>
  </dict>
</dict>
</plist>
PLIST

plutil -lint "$APP/Contents/Info.plist"
plutil -lint "$WIDGET/Contents/Info.plist"
codesign --force --sign - "$WIDGET" >/dev/null 2>&1 || true
codesign --force --sign - "$APP" >/dev/null 2>&1 || true
echo "$APP"
