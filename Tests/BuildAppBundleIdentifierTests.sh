#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_SCRIPT="$ROOT/Scripts/build-app.sh"
APP_SOURCE="$ROOT/Sources/CodexUsageWidgetApp/UsageViews.swift"

grep -Fq '<string>org.dongx.quota.bar</string>' "$BUILD_SCRIPT"
grep -Fq '<string>org.dongx.quota.bar.native-widget</string>' "$BUILD_SCRIPT"
grep -Fq '"org.dongx.quota.bar.native-widget"' "$APP_SOURCE"
