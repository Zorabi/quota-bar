# QuotaBar Codex 用量组件 Implementation Record

**状态：** 已实现并合并到 `main`  
**最终提交：** `89d6f8f Add QuotaBar Codex usage widget`  
**Goal:** 构建一个 macOS 菜单栏工具 QuotaBar，用于查看当前 Codex 账号剩余用量，并提供状态栏下拉、App 内桌面小组件和实验性原生 WidgetKit 扩展。  
**Architecture:** SwiftPM 包含可测试的 `CodexUsageCore` library、`CodexUsageWidgetApp` executable 和 `CodexUsageNativeWidgetExtension` executable。核心层负责快照、设置、真实数据映射和格式化；应用层用 SwiftUI/AppKit 展示菜单栏文本、状态栏下拉、设置页和桌面浮窗；构建脚本打包 `.app`、`.appex` 和 `.icns`。  
**Tech Stack:** Swift 6.2、Swift Package Manager、SwiftUI、AppKit、WidgetKit、XCTest、macOS 14+。

## Global Constraints

- 全部沟通、文档和新增代码注释使用中文。
- 状态栏默认文本必须是 `5h 52% | 7d 42%` 这种竖线分隔格式。
- 状态栏不显示应用图标。
- 不读取 Codex Desktop 私有数据库。
- 使用 Codex app-server 只读接口读取真实用量；不可用时显示不可用或保留上次快照。
- 不伪造进度、来源、额度或能力。
- 实现遵循 TDD，核心格式化、映射和模型行为由 XCTest 覆盖。

## Final File Map

```text
Package.swift
README.md
Resources/
  QuotaBar.svg
Scripts/
  build-app.sh
Sources/
  CodexUsageCore/
    CodexAppServerUsageProvider.swift
    CodexRateLimitResponseMapper.swift
    MenuBarUsageFormatter.swift
    MockUsageProvider.swift
    Module.swift
    RefreshScheduleFormatter.swift
    SharedUsageSnapshotStore.swift
    UsageModels.swift
  CodexUsageNativeWidgetExtension/
    CodexUsageNativeWidget.swift
  CodexUsageWidgetApp/
    AppModel.swift
    CodexUsageWidgetApp.swift
    DesktopWidgetController.swift
    SettingsWindowController.swift
    StatusItemController.swift
    UsageViews.swift
Tests/
  CodexUsageCoreTests/
    MenuBarUsageFormatterTests.swift
    UsageModelTests.swift
docs/
  superpowers/
    plans/2026-07-02-codex-usage-widget.md
    specs/2026-07-02-codex-usage-widget-design.md
```

## Task 1: 核心模型与菜单栏格式化

**Files:**
- `Package.swift`
- `Tests/CodexUsageCoreTests/MenuBarUsageFormatterTests.swift`
- `Tests/CodexUsageCoreTests/UsageModelTests.swift`
- `Sources/CodexUsageCore/UsageModels.swift`
- `Sources/CodexUsageCore/MenuBarUsageFormatter.swift`

**Interfaces:**
- Produces: `UsageWindowKind`、`UsageWindowSnapshot`、`CodexUsageSnapshot`、`WidgetSettings`、`MenuBarUsageFormatter.format(_:settings:)`。

- [x] **Step 1: 写失败测试**
- [x] **Step 2: 运行测试确认缺少类型失败**
- [x] **Step 3: 实现核心模型和格式化器**
- [x] **Step 4: 运行核心测试确认通过**

## Task 2: 数据源、映射与共享快照

**Files:**
- `Sources/CodexUsageCore/CodexAppServerUsageProvider.swift`
- `Sources/CodexUsageCore/CodexRateLimitResponseMapper.swift`
- `Sources/CodexUsageCore/MockUsageProvider.swift`
- `Sources/CodexUsageCore/SharedUsageSnapshotStore.swift`
- `Sources/CodexUsageCore/RefreshScheduleFormatter.swift`
- `Tests/CodexUsageCoreTests/UsageModelTests.swift`

**Interfaces:**
- Produces: `UsageProviding`、`CodexAppServerUsageProvider.fetchUsage()`、`CodexRateLimitResponseMapper.map(_:now:)`、`SharedUsageSnapshotStore`、`RefreshScheduleFormatter`。

- [x] **Step 1: 写测试，验证模拟数据包含 5h、7d、Reset credits**
- [x] **Step 2: 写测试，验证 Codex app-server payload 映射真实字段**
- [x] **Step 3: 写测试，验证重置日期和刷新倒计时格式**
- [x] **Step 4: 实现真实 provider、JSON 映射和共享快照存储**
- [x] **Step 5: 运行核心测试确认通过**

## Task 3: macOS 菜单栏、下拉面板与设置页

**Files:**
- `Sources/CodexUsageWidgetApp/CodexUsageWidgetApp.swift`
- `Sources/CodexUsageWidgetApp/AppModel.swift`
- `Sources/CodexUsageWidgetApp/StatusItemController.swift`
- `Sources/CodexUsageWidgetApp/SettingsWindowController.swift`
- `Sources/CodexUsageWidgetApp/UsageViews.swift`

**Interfaces:**
- Consumes: `CodexUsageSnapshot`、`WidgetSettings`、`MenuBarUsageFormatter`、`CodexAppServerUsageProvider`。
- Produces: 可构建的 macOS 菜单栏应用、状态栏下拉面板和设置窗口。

- [x] **Step 1: 添加应用入口和 `AppModel`**
- [x] **Step 2: 添加无图标状态栏文本**
- [x] **Step 3: 添加状态栏下拉面板**
- [x] **Step 4: 添加设置页，包含刷新、丰富度、状态栏、Codex 前缀、桌面小组件、吸附桌面、原生小组件和退出应用**
- [x] **Step 5: 修复下拉按钮命中区域和 macOS 焦点环误高亮**
- [x] **Step 6: 运行 `swift build` 确认通过**

## Task 4: App 内桌面小组件

**Files:**
- `Sources/CodexUsageWidgetApp/DesktopWidgetController.swift`
- `Sources/CodexUsageWidgetApp/UsageViews.swift`

**Interfaces:**
- Produces: 可显示、隐藏、自适应高度并支持吸附桌面的 App 内浮动小组件。

- [x] **Step 1: 添加 `NSPanel` 浮窗控制器**
- [x] **Step 2: 添加桌面小组件 SwiftUI 视图**
- [x] **Step 3: 去掉固定高度，按内容自适应**
- [x] **Step 4: 增加吸附桌面开关，与原生小组件共存**

## Task 5: 原生 WidgetKit 扩展

**Files:**
- `Sources/CodexUsageNativeWidgetExtension/CodexUsageNativeWidget.swift`
- `Sources/CodexUsageCore/SharedUsageSnapshotStore.swift`
- `Scripts/build-app.sh`

**Interfaces:**
- Produces: 从共享快照读取数据的 WidgetKit 扩展。

- [x] **Step 1: 添加 WidgetKit timeline provider**
- [x] **Step 2: 读取共享快照展示小号组件**
- [x] **Step 3: 在构建脚本中嵌入 `.appex`**
- [x] **Step 4: 在设置页提供安装和位置入口**
- [x] **Step 5: 记录 ad-hoc 签名无法保证系统小组件库收录的限制**

## Task 6: 构建脚本、图标与说明

**Files:**
- `Resources/QuotaBar.svg`
- `Scripts/build-app.sh`
- `README.md`

**Interfaces:**
- Produces: `.build/QuotaBar.app`、`QuotaBar.icns` 和使用说明。

- [x] **Step 1: 添加 QuotaBar SVG 图标源文件**
- [x] **Step 2: 构建时生成 `.icns` 并写入 app bundle**
- [x] **Step 3: 打包主 app 和 WidgetKit appex**
- [x] **Step 4: 添加 README 使用说明**
- [x] **Step 5: 运行 `swift test`、`swift build` 和 `Scripts/build-app.sh`**

## Task 7: 设置窗口唯一入口与呈现开关

**Files:**
- `Sources/CodexUsageCore/UsageModels.swift`
- `Tests/CodexUsageCoreTests/UsageModelTests.swift`
- `Sources/CodexUsageWidgetApp/AppModel.swift`
- `Sources/CodexUsageWidgetApp/CodexUsageWidgetApp.swift`
- `Sources/CodexUsageWidgetApp/StatusItemController.swift`
- `Sources/CodexUsageWidgetApp/UsageViews.swift`

**Interfaces:**
- Produces: `WidgetSettings.showsStatusItem`、`WidgetSettings.showsDockIcon`、`WidgetSettings.normalizedForPresentation()`。
- Produces: 统一的 `Cmd + ,` 设置入口、可动态隐藏或显示的状态栏项、可动态切换的 Dock 图标。

- [x] **Step 1: 写失败测试，验证新增设置可持久化、旧配置可兼容解码、关闭状态栏时保留 Dock 入口**
- [x] **Step 2: 运行目标测试确认缺少字段和方法失败**
- [x] **Step 3: 实现 `WidgetSettings` 新字段、旧配置默认值和呈现归一化**
- [x] **Step 4: 将 `Cmd + ,` 替换为自建 `SettingsWindowController` 入口**
- [x] **Step 5: 让 `StatusItemController` 根据设置创建或移除 `NSStatusItem`**
- [x] **Step 6: 在设置页增加“状态栏显示”和“Dock 图标”开关**
- [x] **Step 7: 运行 `swift test` 确认通过**

## Task 8: 修复呈现开关崩溃与设置菜单栏归属

**Files:**
- `Sources/CodexUsageCore/UsageModels.swift`
- `Tests/CodexUsageCoreTests/UsageModelTests.swift`
- `Sources/CodexUsageWidgetApp/AppModel.swift`
- `Sources/CodexUsageWidgetApp/CodexUsageWidgetApp.swift`
- `Sources/CodexUsageWidgetApp/SettingsWindowController.swift`
- `Scripts/build-app.sh`

**Interfaces:**
- Produces: `WidgetSettings.needsPresentationNormalization`。
- Produces: 设置窗口可见期间的临时 `.regular` 激活策略，关闭窗口后恢复用户的 Dock 图标设置。
- Removes: app bundle 中的 `LSUIElement` 声明。

- [x] **Step 1: 读取崩溃日志，确认 `AppModel.settings.didSet` 递归 setter 导致栈溢出**
- [x] **Step 2: 写失败测试，验证只有状态栏和 Dock 都关闭时才需要呈现归一化**
- [x] **Step 3: 将 `AppModel.settings.didSet` 改为仅在必要时归一化，避免 `@Published` setter 无限递归**
- [x] **Step 4: 设置窗口打开时临时切到 `.regular`，关闭后按设置恢复 `.regular` 或 `.accessory`**
- [x] **Step 5: 从打包脚本生成的 `Info.plist` 删除 `LSUIElement`**
- [x] **Step 6: 运行 `swift test`、`swift build`、`Scripts/build-app.sh`，并确认打包产物不含 `LSUIElement`**

## Task 9: 修复 Dock 与状态栏开关即时生效

**Files:**
- `Sources/CodexUsageWidgetApp/AppModel.swift`
- `Sources/CodexUsageWidgetApp/CodexUsageWidgetApp.swift`
- `Sources/CodexUsageWidgetApp/StatusItemController.swift`
- `Sources/CodexUsageWidgetApp/UsageViews.swift`

**Interfaces:**
- Produces: `AppModel.updateSettings(_:)`，作为设置页写入 `WidgetSettings` 的唯一入口。
- Produces: 状态栏设置入口统一走 `AppCoordinator.openSettings()`。
- Produces: Dock 激活策略只在 Dock 图标设置实际变化、打开设置窗口或关闭设置窗口时应用。

- [x] **Step 1: 确认设置窗口可见时持续强制 `.regular` 会压住 Dock 开关**
- [x] **Step 2: 将设置页控件从 `$model.settings.xxx` 改为通过 `AppModel.updateSettings(_:)` 写入最终设置**
- [x] **Step 3: 让状态栏“设置”按钮复用 `AppCoordinator.openSettings()`，避免绕过统一激活策略**
- [x] **Step 4: 只在 `showsDockIcon` 实际变化时即时切换 `.regular` 或 `.accessory`**
- [x] **Step 5: 运行 `swift test`、`swift build`、`Scripts/build-app.sh`，并确认打包产物不含 `LSUIElement`**

## Task 10: 修复刷新、预览与呈现开关稳定性

**Files:**
- `Sources/CodexUsageCore/CodexAppServerUsageProvider.swift`
- `Sources/CodexUsageCore/MenuBarUsageFormatter.swift`
- `Tests/CodexUsageCoreTests/MenuBarUsageFormatterTests.swift`
- `Tests/CodexUsageCoreTests/UsageModelTests.swift`
- `Sources/CodexUsageWidgetApp/CodexUsageWidgetApp.swift`
- `Sources/CodexUsageWidgetApp/StatusItemController.swift`
- `Sources/CodexUsageWidgetApp/UsageViews.swift`

**Interfaces:**
- Produces: `CodexAppServerUsageProvider.extractRateLimitSnapshot(from:now:)`，用于测试混合日志和 JSON-RPC 输出解析。
- Produces: 无快照时也尊重 `showsCodexPrefix` 的菜单栏占位格式。
- Produces: 状态栏项创建一次后通过 `NSStatusItem.isVisible` 隐藏或显示。
- Produces: 状态栏预览在无真实快照时使用本地样例快照，保证 Codex 前缀开关可见。

- [x] **Step 1: 外部复现 app-server 握手太快导致只收到 `id:1`，收不到 `id:2` 用量响应**
- [x] **Step 2: 写失败测试，验证无快照时关闭 Codex 前缀应显示 `--`**
- [x] **Step 3: 写失败测试，验证 provider 能从包含日志、`id:1` 和 `id:2` 的混合输出解析快照**
- [x] **Step 4: 将 app-server 初始化等待调为 1 秒，`initialized` 后等待 0.5 秒，读取等待默认 4 秒**
- [x] **Step 5: 将状态栏隐藏/显示从移除重建改为固定 `NSStatusItem` 的 `isVisible` 切换**
- [x] **Step 6: Dock 切到 `.regular` 时调用 `NSApp.activate(ignoringOtherApps:)` 刷新 Dock 和菜单栏**
- [x] **Step 7: 状态栏预览使用真实快照或本地样例快照格式化**
- [x] **Step 8: 运行 `swift test`、`swift build`、`Scripts/build-app.sh`，并确认打包产物不含 `LSUIElement`**

## Task 11: 修复设置窗口被 Dock 切换关闭与状态栏重排

**Files:**
- `Sources/CodexUsageWidgetApp/CodexUsageWidgetApp.swift`
- `Sources/CodexUsageWidgetApp/StatusItemController.swift`
- `Sources/CodexUsageWidgetApp/UsageViews.swift`

**Interfaces:**
- Produces: Dock 图标设置在设置窗口关闭后应用，避免设置窗口打开时切 `.accessory`。
- Produces: 状态栏隐藏保留同一个 `NSStatusItem`，通过清空标题和设置长度为 0 隐藏。

- [x] **Step 1: 确认设置窗口打开时即时切 `.accessory` 会导致窗口被系统收起**
- [x] **Step 2: 移除 Dock 设置变化订阅，改为打开设置时保持 `.regular`，关闭设置时按保存值恢复**
- [x] **Step 3: 将状态栏隐藏从 `item.isVisible = false` 改为 `item.length = 0` 且清空标题**
- [x] **Step 4: 更新设置页文案说明 Dock 关闭设置后生效，状态栏隐藏会尽量保持状态栏顺序稳定**
- [x] **Step 5: 运行 `swift test`、`swift build`、`Scripts/build-app.sh`，并确认打包产物不含 `LSUIElement`**
- [x] **Step 6: 修正设置窗口关闭回调，显式以 `keepsSettingsVisible: false` 恢复 Dock 激活策略，避免 `windowWillClose` 阶段仍被判定为可见**

## Task 12: 增加开机启动并提高用量读取稳定性

**Files:**
- `Sources/CodexUsageCore/UsageModels.swift`
- `Sources/CodexUsageCore/CodexAppServerUsageProvider.swift`
- `Tests/CodexUsageCoreTests/UsageModelTests.swift`
- `Sources/CodexUsageWidgetApp/LaunchAtLoginController.swift`
- `Sources/CodexUsageWidgetApp/CodexUsageWidgetApp.swift`
- `Sources/CodexUsageWidgetApp/UsageViews.swift`

**Interfaces:**
- Produces: `WidgetSettings.launchesAtLogin`。
- Produces: `LaunchAtLoginController`，通过 `SMAppService.mainApp` 注册、取消和读取主 App 登录项状态。
- Produces: app-server 读取默认 10 秒窗口，最多 2 次重启 app-server 重试。

- [x] **Step 1: 写失败测试，验证 `launchesAtLogin` 可持久化，旧设置默认关闭**
- [x] **Step 2: 实现 `WidgetSettings.launchesAtLogin` 编解码兼容**
- [x] **Step 3: 添加 `LaunchAtLoginController`，使用 macOS `SMAppService.mainApp.register()` 和 `unregister()`**
- [x] **Step 4: 设置页增加“开机启动”开关，切换失败时显示错误并同步系统真实状态**
- [x] **Step 5: 应用启动时同步系统登录项状态到设置模型**
- [x] **Step 6: 将 app-server 单次读取窗口从 4 秒调到 10 秒，并保留最多 2 次重启重试**
- [x] **Step 7: 用真实 Codex app-server 验证 10 秒读取窗口能拿到 `id:2` 用量响应**
- [x] **Step 8: 运行 `swift test`、`swift build`、`Scripts/build-app.sh`，并确认打包产物不含 `LSUIElement`**

## Task 13: 兼容 ChatGPT 更新后的 Codex 可执行文件路径

**Files:**
- `Sources/CodexUsageCore/CodexAppServerUsageProvider.swift`
- `Tests/CodexUsageCoreTests/UsageModelTests.swift`
- `README.md`
- `docs/superpowers/specs/2026-07-02-codex-usage-widget-design.md`

**Interfaces:**
- Produces: `CodexAppServerUsageProvider.resolveCodexExecutablePath(from:isExecutable:)`。
- Produces: 自动发现 ChatGPT 新版与 Codex 旧版 App 内 `codex` 可执行文件的默认初始化行为。

- [x] **Step 1: 复现新版 ChatGPT 安装后旧版硬编码路径不存在，导致用量读取直接返回不可用**
- [x] **Step 2: 写失败测试，验证优先发现 ChatGPT 新路径，并在需要时回退 Codex 旧路径**
- [x] **Step 3: 实现系统级和用户级 `Applications` 目录的兼容路径发现**
- [x] **Step 4: 使用新版 ChatGPT 内的真实 app-server 验证 `account/rateLimits/read` 仍返回当前额度**
- [x] **Step 5: 运行完整验证**

## Verification

已在功能分支和合并后的 `main` 上运行：

```bash
swift test
swift build
Scripts/build-app.sh
```

测试覆盖：

- 菜单栏紧凑、详细、Codex 前缀和不可用格式。
- 百分比 clamp。
- 重置倒计时和具体重置日期格式。
- Mock provider 数据。
- app-server 当前 payload 映射。
- Reset credits 读取。
- 刷新倒计时格式。

## Known Limitations

- 原生 WidgetKit 扩展在 ad-hoc 签名或未受系统信任的构建下可能无法出现在 macOS 小组件库。
- ChatGPT 新版和 Codex 旧版 App 内的 `codex app-server --stdio` 均不可用或未登录时，真实用量读取会降级为不可用。
- 当前 UI 是 macOS 菜单栏工具，不是完整偏好设置应用或 App Store 发布包。
