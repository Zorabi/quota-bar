# Codex 用量小组件原型

这是一个全新的 macOS 菜单栏与桌面小组件原型，用来查看 Codex 剩余用量。

## 当前能力

- 菜单栏紧凑显示：`5h 52% | 7d 42%`
- 菜单栏不显示应用图标
- 桌面浮动小组件显示 5h 主百分比、7d、重置倒计时
- 菜单栏展开面板显示进度条、套餐、Credits、刷新间隔和信息丰富度
- 支持刷新间隔：1、5、15、30 分钟
- 支持菜单栏密度：极简、紧凑、详细
- 当前使用模拟数据源，不读取 Codex Desktop 私有数据库

## 运行

```bash
swift run CodexUsageWidgetApp
```

## 构建 App

```bash
Scripts/build-app.sh
open .build/CodexUsageWidget.app
```

## 验证

```bash
swift test
swift build
```

