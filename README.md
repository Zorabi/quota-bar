# QuotaBar

QuotaBar 是一个 macOS 菜单栏工具，用来查看当前 Codex 账号剩余用量。

## 当前能力

- 状态栏紧凑显示：`5h 52% | 7d 42%`
- 状态栏默认不显示应用图标，可选择是否显示 `Codex` 前缀
- 状态栏下拉面板显示 5h、7d、重置时间、Plan、Credits、Reset credits 和刷新状态
- App 内桌面小组件显示 5h 主百分比、7d、Plan、Credits 和 Reset credits
- App 内桌面小组件支持显示/隐藏和吸附桌面
- 设置页支持刷新间隔、信息丰富度、状态栏密度、Codex 前缀、桌面小组件、吸附桌面和退出应用
- 通过 Codex app-server 只读接口读取真实账号用量
- 包含实验性 WidgetKit 原生小组件扩展；未签名构建可能无法被 macOS 小组件库收录

## 运行

```bash
swift run CodexUsageWidgetApp
```

## 构建 App

```bash
Scripts/build-app.sh
open .build/QuotaBar.app
```

构建脚本会生成：

- `.build/QuotaBar.app`
- `QuotaBar.icns`
- 嵌入式 `CodexUsageNativeWidgetExtension.appex`

## 验证

```bash
swift test
swift build
Scripts/build-app.sh
```

## 真实数据来源

QuotaBar 会自动查找 ChatGPT 新版与 Codex 旧版 App 内的 `codex` 可执行文件，再通过 `app-server --stdio` 调用 `account/rateLimits/read`。系统级和用户级 `Applications` 目录均受支持。

它只读取账户额度，不读取 Codex Desktop 私有数据库，不调用额度重置接口，也不修改账号状态。
