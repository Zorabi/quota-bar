# QuotaBar 项目协作规则

本文件适用于仓库根目录及其全部子目录，所有参与本项目的智能体都必须遵守。开始工作前应先检查当前代码、工作区状态，以及 `docs/superpowers/` 中已批准的设计和实施记录，不能仅凭历史描述判断实现状态。

## 沟通规范

- 与用户的全部沟通使用中文。
- 每次回复用户时，必须称呼用户为“陛下”。
- 代理之间的任务说明、进度报告和审查结论使用中文。

## 项目概述

- 产品名称：`QuotaBar`。
- 产品形态：macOS 14+ 菜单栏应用，当前构建目标为 Apple Silicon。
- 主要技术：Swift 6.2、SwiftUI、AppKit、WidgetKit、Swift Package Manager。
- 核心能力：只读展示 Codex 5 小时与 7 天用量、重置时间、Plan、Credits 和 Reset credits，并提供菜单栏面板、App 内桌面小组件、设置页和实验性 WidgetKit 扩展。
- 主应用 Bundle ID：`org.dongx.quota.bar`。
- Widget 扩展 Bundle ID：`org.dongx.quota.bar.native-widget`。
- 开源协议：GNU Affero General Public License v3.0（`AGPL-3.0-only`）。

## 目录与架构

- `Sources/CodexUsageCore/`：数据模型、格式化、设置存储、共享快照和只读数据源。
- `Sources/CodexUsageWidgetApp/`：SwiftUI / AppKit 菜单栏应用、设置窗口和 App 内桌面小组件。
- `Sources/CodexUsageNativeWidgetExtension/`：实验性 WidgetKit 扩展。
- `Tests/CodexUsageCoreTests/`：核心逻辑单元测试。
- `Tests/BuildAppBundleIdentifierTests.sh`：打包 Bundle ID 回归测试。
- `Scripts/build-app.sh`：Release 构建、`.app` / `.appex` 组装、Info.plist 生成、图标打包和 ad-hoc 签名。
- `Resources/`：应用图标源文件。
- `docs/superpowers/specs/`：已批准的产品与技术设计。
- `docs/superpowers/plans/`：对应的实施记录。

## 数据与安全边界

- 常规用量只通过本机 ChatGPT / 旧版 Codex App 内的 `codex app-server --stdio` 获取，使用 `account/rateLimits/read`。
- Reset credits 过期时间只在用户手动触发时查询，并且只读取完成该请求所需的本机 Codex 登录凭据。
- 不读取 ChatGPT 或 Codex Desktop 的私有数据库。
- 不提供或代替用户执行登录、购买、批准、拒绝、额度重置等写操作。
- 不持久化任务内容；应用设置和供 WidgetKit 展示的最近一次用量快照可写入 `Application Support/QuotaBar`。
- Reset credits 过期时间结果只保留在当前运行会话中。
- 无法确定额度、来源或能力时，明确显示未知、不可用或降级，不得伪造数据。

## 代码与文案规范

- 所有新增或修改的代码注释、文档注释使用中文。
- 不翻译编程语言关键字、公开 API 名称、协议字段、命令、路径及第三方产品名称。
- 优先写清晰的代码；不要为了满足“中文注释”而添加重复代码含义的无效注释。
- 用户可见文案默认使用中文；协议规定、测试夹具或英文 README 要求的固定字符串保持原样。
- 修改共享模型、设置或快照结构时，必须考虑旧版本数据的兼容解码。
- 修改主应用 Bundle ID 时，必须同步更新 Widget 扩展 Bundle ID，并维护 Bundle ID 回归测试。

## 工作方式

- 实现功能和修复缺陷时遵循测试驱动开发：先写失败测试，确认失败原因，再实现最小代码使其通过。
- 严格遵循 `docs/superpowers/specs/` 中已批准的设计和 `docs/superpowers/plans/` 中的实施记录；如当前需求与其冲突，应先向陛下说明。
- 工作区已有改动默认属于陛下；检查、暂存和提交时使用明确文件清单，不得回滚或提交无关改动。
- 不因常规验证自动打开或安装 `.app`；需要启动应用、复制到 `/Applications` 或访问真实账号数据时，必须确认任务确有需要。
- 每项任务完成后运行对应测试；声称完成前必须运行完整验证。

## 开发与验证命令

```bash
# 核心逻辑测试
swift test

# Bundle ID 回归测试
zsh Tests/BuildAppBundleIdentifierTests.sh

# Debug 构建
swift build

# Release 打包；需要 ImageMagick
Scripts/build-app.sh

# 提交前检查格式问题
git diff --check
```

完整验证至少包括 Bundle ID 回归测试、`swift test`、`swift build`、`Scripts/build-app.sh` 和 `git diff --check`。打包完成后应确认主应用与 Widget 扩展 Info.plist 中的 Bundle ID 分别为 `org.dongx.quota.bar` 和 `org.dongx.quota.bar.native-widget`。
