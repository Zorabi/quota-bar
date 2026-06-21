# Perch 产品架构设计

**日期：** 2026-06-21  
**状态：** 已批准，待实现计划  
**目标平台：** macOS 14+、Apple Silicon  
**分发方式：** 开源源码与未签名构建产物；未来可增加 Developer ID 签名与公证版本

## 1. 目标

Perch 是面向 macOS 开发者的原生 HUD 应用。产品先解决一个明确问题：用户把工作交给 Claude Code、Codex CLI 或 Codex Desktop 后，能够在不切换窗口的情况下知道任务是否运行、是否需要处理以及是否完成。

产品使用三层渐进式界面：

1. Ambient HUD 在刘海或屏幕顶部安静地显示环境状态。
2. Land 在任务完成、失败或等待用户时短暂出现。
3. Task Center 提供只读详情、订阅额度和返回原工具的深链。

Perch 后续扩展系统 HUD、媒体与实时活动，但 AI 任务监控是首个 Alpha 的价值验证点。

## 2. 设计约束

- 首个版本支持 macOS 14+ 与 Apple Silicon。
- 支持有刘海、无刘海和外接显示器。
- 首期从源码构建，同时可发布未签名 ZIP 或 DMG。
- 不受 Mac App Store 沙盒约束。
- 默认不保存 prompt、工具输入输出或任务历史。
- Perch 只观察、提醒和跳转，不在自身界面中批准、拒绝或修改 AI 任务。
- 三类 AI 工具采用分级能力；UI 只展示适配器明确声明的数据，不伪造百分比。
- 内置适配器使用插件协议隔离运行，但首期不开放第三方插件安装。

## 3. 范围与非目标

### 3.1 Alpha 范围

- Claude Code、Codex CLI、Codex Desktop 实时监控。
- 任务运行、当前活动、等待用户、完成、失败和失联状态。
- Ambient HUD、Land 与 Task Center。
- Claude 与 Codex 订阅额度展示。
- 安装向导、卸载恢复与 Doctor 诊断。
- 多显示器、Focus 抑制和 Reduced Motion。

### 3.2 Alpha 非目标

- 第三方插件市场或任意可执行插件安装。
- Perch 内联审批或向 AI 工具发送指令。
- 读取 Codex Desktop 内部数据库、抓取其他应用通知或依赖辅助功能读取 UI。
- 完整任务历史、跨设备同步或云端服务。
- 系统 HUD、Now Playing、日历和锁屏覆盖。
- 依赖私有 API 的能力作为发布承诺。

## 4. 总体架构

```text
Claude Adapter ─┐
Codex Adapter  ─┼─ NDJSON plugin protocol ─> Perch Core ─> Ambient HUD
System Adapter ─┘                              │          ├> Land Queue
                                              │          └> Task Center
                                              └> Settings / Doctor
```

Perch Core 是唯一状态权威。适配器负责把工具私有事件转换为统一协议；UI 只消费 Core 生成的快照，不直接理解 Claude 或 Codex 的事件格式。

### 4.1 Perch Core

Core 由以下边界清晰的模块组成：

- `PluginSupervisor`：启动、握手、监控和重启内置适配器。
- `EventGateway`：校验协议版本、帧大小、来源与字段。
- `TaskReducer`：去重、排序并将事件归并为任务快照。
- `UsageCenter`：维护 Claude 与 Codex 的账户额度快照。
- `NotificationPolicy`：计算优先级、合并窗口和 Focus 抑制。
- `DisplayCoordinator`：选择目标屏幕和展示形态。
- `SettingsStore`：保存非敏感配置和适配器健康状态。
- `DiagnosticsCenter`：提供本地健康计数器，不记录任务内容。

Core 首期位于主应用进程中。协议和状态边界应允许后续把 Core 迁移至独立 LaunchAgent，而不改变适配器或 UI 契约。

### 4.2 内置适配器进程

每个适配器 executable 支持两种运行方式：

- `serve`：由 `PluginSupervisor` 启动，完成握手、事件归一和能力声明。
- `emit`：由生命周期 Hook 短暂调用，读取 stdin 并把原始事件投递给对应 `serve` 进程。

适配器崩溃不得影响 Perch Core 或其他适配器。首期适配器与应用一同构建和发布，不实现外部插件发现、签名或权限系统。

## 5. 插件协议

Core 通过 stdin 向适配器发送握手和控制消息；适配器通过 stdout 输出版本化 NDJSON；stderr 只用于无敏感内容的诊断日志。

握手必须包含：

```text
protocolVersion
adapterId
adapterVersion
supportedSources
capabilities
minimumToolVersions
```

能力包括：

- `taskTree`
- `toolActivity`
- `approvalAttention`
- `progressEstimate`
- `accountUsage`
- `deepLink`

Core 拒绝不兼容的主版本。次版本新增字段必须可被旧消费者忽略。事件帧有固定大小上限；超过上限、无法解码或包含未知必需字段时丢弃并增加诊断计数器。

## 6. 统一事件与状态模型

### 6.1 事件信封

```text
EventEnvelope
├── schemaVersion
├── eventId
├── emittedAt
├── source: claude | codex
├── surface: cli | desktop | unknown
├── sessionId
├── turnId?
├── taskId?
├── type
└── sanitizedPayload
```

统一事件类型：

- `session.started`
- `turn.started`
- `activity.changed`
- `task.changed`
- `attention.required`
- `turn.completed`
- `turn.failed`
- `session.ended`

### 6.2 归并规则

Core 使用 `(source, surface, sessionId, turnId)` 作为任务关联主键，并用 `eventId` 与状态版本去重。适配器无法可靠区分 CLI 与 Desktop 时必须上报 `unknown`，不得猜测来源；后续事件确认来源后可提升精度。每个任务的归并串行执行，避免多适配器事件竞争。

状态机：

```text
discovered -> running <-> waitingForUser -> succeeded
     |             |                    -> failed
     |             |                    -> interrupted
     └-------------┴---------------------> stale
```

终态不可回退。`stale` 只表示长时间没有可验证事件，不等同于失败或完成。普通工具活动只更新 Ambient HUD；只有终态和 `waitingForUser` 可触发 Land。

## 7. AI 工具适配器

### 7.1 Claude Code

主数据源为官方 Hooks：

- `SessionStart`、`SessionEnd`
- `UserPromptSubmit`
- `PreToolUse`、`PostToolUse`、`PostToolUseFailure`
- `PermissionRequest`、`Notification`
- `SubagentStart`、`SubagentStop`
- `TaskCreated`、`TaskCompleted`
- `Stop`、`StopFailure`

Hook bridge 只做有界读取、脱敏与本地投递。投递失败时静默退出，不改变 Claude 的控制流。

### 7.2 Codex CLI

主数据源为 Codex 生命周期 Hooks，覆盖会话、工具、审批、子 Agent 与 Stop 事件。

`codex exec --json` 是可选增强数据源，用于获得 `item.*`、计划更新和 token 信息。用户不需要替换全局 `codex` alias；仅在明确使用 Perch 提供的启动入口时启用增强数据。

### 7.3 Codex Desktop

主数据源同样是 Codex 生命周期 Hooks，完成事件可由 `notify` 配置兜底。

Perch 不启动第二个 App Server 来旁观 Desktop 线程，因为独立 App Server 连接不是全局线程事件监听器。Perch 也不使用 `UNUserNotificationCenterDelegate` 捕获其他应用通知；该 API 只处理 Perch 自身的通知。

### 7.4 能力降级

适配器启动时探测工具版本和实际事件能力。缺少任务树时仍可显示会话状态；缺少工具事件时仍可显示等待用户与终态；只存在完成事件时 UI 明确标为“完成提醒”，而不是“实时监控”。

## 8. 订阅额度

### 8.1 数据模型

```text
UsageSnapshot
├── provider: claude | codex
├── windows[]
│   ├── kind: fiveHour | sevenDay | providerSpecific
│   ├── usedPercentage
│   └── resetsAt
├── fetchedAt
└── freshness: live | stale | unavailable
```

### 8.2 Claude 额度

Claude Code Status Line 输入为订阅用户提供 `rate_limits.five_hour` 与 `rate_limits.seven_day`，包含已用百分比和重置时间。

Perch 安装可逆的 Status Line Tap：

- Tap 读取额度字段并把脱敏快照发送给 Claude Adapter。
- 用户没有状态行时，Tap 不输出额外文本。
- 用户已有状态行时，Tap 将同一 stdin 原样交给原命令并透传 stdout、stderr 与退出状态。
- 安装前保存原配置，卸载时精确恢复。
- Tap 失败不得阻塞或改变 Claude Code 状态行。

### 8.3 Codex 额度

Codex Adapter 使用 App Server 账户接口：

- `account/rateLimits/read` 获取完整快照。
- `account/rateLimits/updated` 合并增量更新。

该连接只读取账户额度，不旁观线程，不调用额度重置接口，也不读取或复制认证文件。Perch 使用 Codex 进程自身的现有认证环境。

### 8.4 展示

- Ambient 常态不显示额度。
- 悬停 Peek 在任务摘要下显示紧凑用量条。
- Task Center 顶部显示所有可用窗口、已用比例、重置时间与新鲜度。
- 可选 80% 和 95% 静默提醒默认关闭；启用后归类为账户提示，不显示成任务失败。
- 不估算“还能运行多少任务”，也不推测套餐价格。
- 快照只保存在内存，过期后显示 `stale`。

## 9. UI 与通知策略

### 9.1 Ambient HUD

常态只显示活动任务数和最高优先级状态。悬停后展示最近任务、等待用户提示和订阅额度。普通活动更新不得自动撑开 HUD。

### 9.2 Land

Land 仅由以下事件触发：

- P0：等待用户、失败。
- P1：任务完成。

P0 可替换正在展示的普通系统 HUD。P1 进入队列，并在两秒窗口内合并同来源的并发完成事件。Land 默认静音，悬停暂停收回计时。

操作只包括：打开原工具、查看任务、忽略。审批必须回到原工具完成。

### 9.3 Task Center

Task Center 提供 `All`、`Active`、`Needs You` 三种过滤，展示来源、项目名、状态、运行时间、最后活动与深链。它不显示完整 prompt 或工具输出。

### 9.4 多显示器

Land 默认出现在当前活跃屏。内屏有刘海时贴合刘海；无刘海或外接屏使用顶部悬浮胶囊。用户可以指定固定通知屏。系统 HUD 与 AI HUD 共享 `DisplayCoordinator`，避免窗口互相覆盖。

## 10. 安装、卸载与分发

安装向导采用“预览、备份、合并、验证”流程：

1. 把稳定事件桥安装到 `~/Library/Application Support/Perch/bin/`。
2. 展示 Claude 与 Codex 配置差异。
3. 备份原配置。
4. 只追加带 Perch 所有权标识的 Hook 或 Status Line Tap。
5. 验证事件投递。
6. 引导用户在 Codex 官方 Hook 界面完成信任审核。

所有配置更新使用原文件指纹校验与原子替换；检测到用户或其他进程并发修改时中止并重新生成差异，不覆盖新内容。安装器不得修改 shell alias，不向 `/usr/local/bin` 写文件。卸载器只删除当前仍匹配 Perch 所有权标识的配置项与文件；若用户在安装后修改了状态行，卸载器不恢复整份旧备份，而是展示差异并保留用户的新配置。

首期发布源码和未签名产物，并解释 Gatekeeper 放行步骤。自动更新延后到稳定发布签名链建立后；首期只检查更新并打开 GitHub Release 页面。

## 11. 安全与隐私

- Alpha 不申请 Accessibility、Input Monitoring 或全磁盘访问。
- Socket 位于 macOS 用户专属临时目录，父目录权限为 `0700`、Socket 为 `0600`。
- Hook 输入在进入 Core 前移除完整 prompt、工具输入输出、绝对路径与疑似凭据。
- 默认持久化任务内容和额度为零字节。
- 可保存的运行元数据仅限适配器版本、健康状态和短期去重键。
- 原始事件不会上传网络。
- Doctor 日志只记录计数、错误类别和版本，不记录任务文本。

## 12. 故障恢复

- 适配器崩溃：指数退避重启，并把能力标为降级。
- Hook 投递失败：静默退出，不阻塞 AI 工具。
- 重复或乱序：通过事件 ID、时间和状态版本处理。
- 长时间无事件：标记 `stale`，不产生完成或失败 Land。
- Perch 重启：不补发旧 Land；下一条有效事件可恢复活动任务。
- 工具版本不兼容：关闭不支持的高粒度能力，保留可验证的低粒度能力。
- 额度字段缺失：显示 `unavailable`；快照过期显示 `stale`，不自行估算。

## 13. 产品路线

### Phase 0：Foundation

- Plugin Supervisor
- Event Protocol
- Task Reducer
- Window Host
- Settings 与 Doctor

退出标准：模拟适配器能够驱动所有 UI 状态。

### Phase 1：AI Alpha

- Claude、Codex CLI、Codex Desktop Adapter
- Ambient、Land、Task Center
- 订阅额度
- 安装、卸载、诊断和多屏支持

退出标准：三类工具端到端监控与额度展示通过验收。

### Phase 2：System HUD Beta

- 音量与输出设备
- 屏幕亮度
- 键盘背光
- 多显示器主题策略
- Focus 抑制

首期只实现一种主题。完全隐藏原生系统 HUD 在技术验证完成前不作承诺。

### Phase 3+：Media 与 Activities

- Now Playing
- 电池与设备连接活动
- 日历 Widget
- 主题扩展
- 第三方插件 SDK

Now Playing 全应用兼容先验证公开 API 覆盖。依赖私有 MediaRemote 的实现必须隔离在实验适配器中。锁屏持续覆盖属于 R&D，不进入确定性发布计划。Liquid Glass 作为 macOS 26 条件能力，不提升全应用最低系统要求。

## 14. 测试策略

### 14.1 单元与属性测试

- 各工具事件映射与脱敏。
- 状态归并、终态不可回退和通知优先级。
- 随机重复、乱序和丢失事件。
- Land 合并窗口和 Focus 抑制。

### 14.2 契约与集成测试

- 适配器握手、版本协商和能力声明。
- Hook 安装、升级、卸载幂等性。
- 伪适配器崩溃、无响应和畸形输出。
- Socket 权限与帧大小限制。
- Claude Status Line Tap 的 stdin、stdout、stderr 与退出状态透传。
- Codex 额度读取不调用任何写操作或额度重置接口。

### 14.3 UI 与端到端测试

- 有刘海、无刘海和外接屏。
- Reduced Motion 与 Focus 模式。
- 三类真实工具冒烟测试。
- 缺字段、窗口变化、版本不兼容和 stale 额度状态。

## 15. Alpha 验收标准

| 指标 | 标准 |
|---|---:|
| 三类工具终态送达 | 每个支持版本连续 100 次无丢失 |
| Hook 到 Land 延迟 | 本机 p95 < 250 ms |
| Hook bridge 执行时间 | p95 < 50 ms |
| 重复 Land | 0 |
| 适配器异常恢复 | 5 秒内开始重启 |
| 活跃时额度更新延迟 | < 60 秒 |
| 空闲 CPU | < 0.5% |
| 总空闲内存 | < 100 MB |
| 默认持久化任务内容与额度 | 0 字节 |

Alpha 完成还必须满足：

1. macOS 14+ Apple Silicon 能从源码构建。
2. 三类 AI 工具均按实际能力显示运行、等待用户和终态。
3. 三层 UI 在目标显示器组合正常工作。
4. 安装和卸载不破坏已有配置。
5. Perch 或适配器崩溃不阻塞 AI 工具。
6. Doctor 能解释未安装、未信任、版本不兼容和连接中断。

## 16. 技术依据

- [Codex App Server](https://developers.openai.com/codex/app-server/)
- [Codex Hooks](https://developers.openai.com/codex/hooks/)
- [Codex Non-interactive mode](https://developers.openai.com/codex/noninteractive/)
- [Claude Code Hooks reference](https://code.claude.com/docs/en/hooks)
- [Claude Code Status line](https://code.claude.com/docs/en/statusline)
- [Claude Code cost and usage](https://code.claude.com/docs/en/costs)

## 17. 已确认决策

- 开源未签名分发，未来可增加签名与公证。
- macOS 14+、Apple Silicon。
- AI 监控优先，三类工具首期覆盖。
- 能力分级，不使用脆弱 UI 抓取。
- 默认隐私优先，不保存任务内容。
- 三层渐进式界面。
- Perch 只读观察，审批返回原工具。
- 插件化多进程，但首期仅内置适配器。
- 额度使用 Peek 与 Task Center 布局。
