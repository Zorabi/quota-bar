# QuotaBar Reset Credits 过期时间设置页查询设计

**日期：** 2026-07-03  
**状态：** 待实现  
**目标平台：** macOS 14+  
**关联功能：** QuotaBar 设置页、Codex reset credits 只读查询

## 目标

在 QuotaBar 设置页增加一个手动触发的查询入口，用来查看当前账号全部可用 reset credits 的过期时间。这个信息不进入状态栏、下拉面板主视图、App 内桌面小组件或原生 WidgetKit 组件，只作为设置页里的辅助诊断信息。

用户进入设置页后，可以点击 `查询过期时间`。应用读取本机 Codex 登录凭据中的 access token，调用 ChatGPT 后端只读接口 `https://chatgpt.com/backend-api/wham/rate-limit-reset-credits`，并展示接口返回的 `available_count` 和每条 credit 的 `expires_at`。

## 非目标

- 不自动查询 reset credit 过期时间。
- 不自动刷新或定时刷新这个信息。
- 不持久化过期时间列表、查询结果或额度快照。
- 不把过期时间展示到状态栏、状态栏下拉主视图、桌面小组件或 WidgetKit 组件。
- 不调用重置额度、购买额度、审批、拒绝或修改账号状态的接口。
- 不读取其他应用的私有数据库。
- 不伪造过期时间；查询失败时明确显示失败状态。

## 数据来源

新增只读 provider 从 Codex auth 文件读取 access token：

- 默认路径：`$CODEX_HOME/auth.json`
- 未设置 `CODEX_HOME` 时使用 `~/.codex/auth.json`
- token 路径：`tokens.access_token`

查询请求：

- URL：`https://chatgpt.com/backend-api/wham/rate-limit-reset-credits`
- Method：`GET`
- Header：
  - `Accept: application/json`
  - `Authorization: Bearer <access_token>`
  - `Origin: https://chatgpt.com`
  - `Referer: https://chatgpt.com/`

预期响应字段：

```json
{
  "available_count": 2,
  "credits": [
    {"expires_at": "2026-07-26T23:26:04.000Z"},
    {"expires_at": "2026-07-31T19:02:09.000Z"}
  ]
}
```

实现只依赖 `available_count` 和 `credits[].expires_at`。其他字段若存在则忽略。

## 数据模型

新增 `ResetCreditExpirySnapshot`，表示一次手动查询结果：

- `availableCount: Int`
- `expirations: [Date]`
- `fetchedAt: Date`

新增 `ResetCreditExpiryProvider`，负责只读查询：

- 成功时返回 `ResetCreditExpirySnapshot`
- auth 文件不存在、token 缺失、网络失败、JSON 不合法或日期无法解析时返回明确错误
- 日期解析支持 ISO 8601 的 `Z`/毫秒格式

这个 snapshot 只保存在 `AppModel` 运行时状态中，不写入 `SharedUsageSnapshotStore`，也不进入现有 `CodexUsageSnapshot`。

## 设置页交互

在设置页新增区块：`Reset credits 过期时间`。

默认状态：

```text
按需查询当前账号 reset credits 的过期时间。
[查询过期时间]
```

查询中：

```text
正在查询...
[查询中] disabled
```

查询成功：

```text
可用 Reset credits：2
1. 2026-07-27 07:26:04
2. 2026-08-01 03:02:09
上次查询：13:42
```

查询成功但列表为空：

```text
可用 Reset credits：0
暂无可用 reset credits
上次查询：13:42
```

查询失败：

```text
无法查询过期时间，请确认 Codex 已登录。
```

失败信息可以附带简短技术原因，但不显示 access token、完整 auth 文件路径内容或响应原文。

## UI 呈现

设置页区块复用现有 `SettingsRow`/卡片风格，保持安静、工具化、可扫描：

- 标题：`Reset credits 过期时间`
- 说明：`手动查询当前账号可用 reset credits 的过期时间，不会自动刷新。`
- 右侧主操作按钮：`查询过期时间`
- 查询结果放在该设置项下方的浅色卡片中
- 日期使用当前系统时区格式化为 `yyyy-MM-dd HH:mm:ss`
- 上次查询时间使用 `RefreshScheduleFormatter.clockText`

若过期时间超过 3 条，设置页仍展示全部列表。当前接口返回数量通常较少，暂不增加折叠或滚动容器。

## 错误与降级

- 找不到 auth 文件：显示 `无法查询过期时间，请确认 Codex 已登录。`
- token 缺失：显示同上。
- HTTP 非 2xx：显示查询失败，并可附带状态码。
- JSON 结构不符合预期：显示查询失败。
- 单条 credit 日期解析失败：忽略该条；若全部无法解析但 `available_count > 0`，显示可用数量并提示 `过期时间不可用`。
- 查询失败不会清空上一次成功结果；结果卡片保留，并在错误文本中显示本次查询失败。

## 测试策略

遵循 TDD：

1. 先为 provider 写失败测试，验证 wham JSON 能映射为 `ResetCreditExpirySnapshot`。
2. 写失败测试，验证 `expires_at` 会按时间升序输出，便于设置页稳定展示。
3. 写失败测试，验证 auth/token 缺失和非法 JSON 返回可解释错误。
4. 实现 provider 的 JSON 解析、日期解析和错误类型。
5. 写应用层测试或可测试 helper，验证日期列表和空状态文案格式。
6. 实现设置页状态、按钮和结果卡片。

完成前运行：

- `swift test`
- `swift build`
- `Scripts/build-app.sh`

## 验收标准

- 设置页包含 `Reset credits 过期时间` 区块。
- 用户点击按钮后才发起 wham 查询。
- 查询成功时显示 `available_count` 和全部 `expires_at`。
- 日期按当前系统时区显示为 `yyyy-MM-dd HH:mm:ss`。
- 查询中按钮不可重复触发。
- 查询失败不泄露 access token。
- 查询失败不清空上一次成功结果。
- 状态栏、下拉面板主视图、桌面小组件和 WidgetKit 组件保持现状。
- `swift test`、`swift build`、`Scripts/build-app.sh` 通过。
