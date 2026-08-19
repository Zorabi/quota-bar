# 直连 HTTP 用量数据源设计（替代 codex app-server fork）

- 日期：2026-08-19
- 状态：已批准（陛下批准于 2026-08-19 会话）
- 类型：架构变更 / 数据来源变更 / 性能修复

## 背景与问题

QuotaBar 以 `refreshIntervalMinutes = 1` 运行时，8 小时产生近 3GB 流量。

根因（实测确认）：

1. `CodexAppServerUsageProvider` 每次刷新 fork 全新 `codex app-server --stdio` 进程（冷启动，无缓存复用）。
2. codex `0.148.0-alpha.9` 冷启动时存在 GET models 请求风暴：实测 1.2 秒内 189 次 `GET /models`（`refresh_strategy=online`，无 single-flight 合并），叠加 WebSocket、插件目录等启动请求。
3. nettop 实测单次冷启动下载 6.98MB；rateLimits 响应本身仅约 1KB。
4. 8h × 约 400 次冷启动 × 7MB ≈ 2.8GB，与观测吻合。

结论：流量与刷新间隔无关（用户自选间隔含 1 分钟是产品能力，必须保留），必须消除"每次刷新冷启动 codex 进程"这一数据获取方式。

## 目标

- 用量刷新流量从约 7MB/次降至 KB 级（实测直连响应约 1.3KB）。
- 保留用户自选刷新间隔（1/5/15/30 分钟），1 分钟档位下 8 小时流量 < 2MB。
- token 失效时可感知并提示重新登录，token 恢复后自动恢复。
- 删除 fork 路径，不保留会重新引入流量问题的代码。

## 非目标

- 不实现 OAuth refresh token 自动刷新（与 codex CLI 并发写 `auth.json` 有冲突风险）。
- 不改变 UI 呈现、设置项、Widget 扩展与快照存储。
- 不修复 codex 上游的 models 请求风暴（可另行向上游反馈）。

## 数据来源

`GET https://chatgpt.com/backend-api/wham/usage`

- 与 `ResetCreditExpiryProvider` 使用的 `/wham/rate-limit-reset-credits` 同族端点。
- codex 二进制 strings 证实该端点即 `account/rateLimits/read` 的上游数据源（serde 字段同源），不新增对私有 API 的暴露面。
- 请求头：`Authorization: Bearer <access_token>`、`Accept: application/json`、`chatgpt-account-id: <account_id>`、`Origin: https://chatgpt.com`、`Referer: https://chatgpt.com/`。
- 凭据读取：`$CODEX_HOME/auth.json`（默认 `~/.codex/auth.json`）的 `tokens.access_token` 与 `account_id`，复用 `ResetCreditExpiryProvider` 的既有模式，只读。
- 网络：URLSession 遵循系统代理（`ResetCreditExpiryProvider` 已在生产验证此路径）。

## 架构

```
AppModel (不变, 每 N 分钟 refresh)
   │
   ▼
WhamUsageProvider (新增, 实现 UsageProviding)
   │  ① 读 auth.json → access_token + account_id
   │  ② URLSession GET /wham/usage (超时 15s)
   │  ③ 响应 ~1.3KB
   ▼
WhamUsageResponseMapper (新增, snake_case → 模型)
   │
   ▼
CodexUsageSnapshot (完全复用, 下游零改动)
```

### 字段映射

| `/wham/usage`（snake_case） | `CodexUsageSnapshot` |
|---|---|
| `rate_limit.primary_window`（`limit_window_seconds`：18000→5h，604800→7d） | `windows[.fiveHour / .sevenDay]` |
| `used_percent` | `remainingPercentage = 100 - used_percent` |
| `reset_at` / `reset_after_seconds` | `resetsAt` / `resetsIn` |
| `plan_type` | `planName` |
| `credits.balance` | `credits` |
| `rate_limit_reset_credits.available_count` | `resetCreditsAvailable` |

- `secondary_window` 为 `null` 时仅产出 7 天窗口（与 commit 4dcb0f8 处理"临时停用五小时额度"的兼容行为一致）。
- 窗口时长字段单位为秒（旧 app-server 结构为分钟），映射时按秒判别 18000/604800。
- `rate_limit_upsell`、`promo` 等营销字段不解析。

## 协议与错误处理

`UsageProviding` 协议签名变更：

```swift
func fetchUsage() -> Result<CodexUsageSnapshot, UsageProviderError>

enum UsageProviderError: Error {
    case missingAuth        // auth.json 缺失或 access_token 为空
    case unauthorized       // HTTP 401/403
    case network(String)    // 超时、代理不可达等
    case invalidResponse    // 响应结构无法解码
}
```

- `unauthorized` → AppModel 新增 `usageErrorText` 发布属性（对齐现有 `resetCreditExpiryErrorText` 模式），菜单栏/设置页提示"请打开 Codex 重新登录"；token 被 ChatGPT.app / codex CLI 刷新后下一轮自动恢复。
- `network` / `invalidResponse` → 保留上次快照不更新（现有行为），freshness 由 UI 按 `lastRefreshedAt` 判定 stale（现有逻辑不变）。
- `missingAuth` → 同 unauthorized 提示路径（提示登录）。
- `isRefreshing` 并发保护与调度逻辑沿用现状。
- `MockUsageProvider` 同步适配新返回类型。

## 删除清单

- `Sources/CodexUsageCore/CodexAppServerUsageProvider.swift`
- `Sources/CodexUsageCore/CodexRateLimitResponseMapper.swift`
- 二者现有引用点随迁移更新；如存在专属测试一并删除（git 历史可找回）。

## 文档同步（项目不变量修订）

本设计修订 `AGENTS.md`「数据与安全边界」第一条：

- 原文：常规用量只通过本机 ChatGPT / 旧版 Codex App 内的 `codex app-server --stdio` 获取，使用 `account/rateLimits/read`。
- 修订为：常规用量通过 ChatGPT 后端只读端点 `/backend-api/wham/usage` 获取，凭据只读取本机 Codex 登录态（`auth.json`），不执行登录、刷新、购买等写操作；应用不写入 `auth.json`。

`CONTRIBUTING.md` 中涉及数据来源不变量的表述如有同步需要一并修订。该修订经项目所有者（陛下）于本设计批准时确认。

## 测试计划

- 新增 `WhamUsageResponseMapperTests`：以实测响应为夹具（脱敏 `user_id`、`email` 后入库），覆盖：
  - 双窗口完整响应；
  - `secondary_window` 为 `null`；
  - `credits.balance` 缺失 / 非数字；
  - 未知窗口时长（不产出该窗口）。
- 新增错误映射纯函数测试：HTTP 401/403 → `unauthorized`，5xx/网络错误 → `network`，无法解码 → `invalidResponse`。
- 现有 `UsageModelTests`、`MenuBarUsageFormatterTests` 不受影响，应保持通过。
- 夹具不得包含真实 token、账号标识或私有用量数据（对齐 `CONTRIBUTING.md` 脱敏要求）。

## 风险

| 风险 | 评估 |
|---|---|
| `/wham/usage` 为私有 API，结构可能变化 | 与旧路径数据同源，风险等价；结构变化落入 `invalidResponse` 并提示不可用，不崩溃 |
| access_token 过期且 ChatGPT.app 未运行 | 按批准方案提示重新登录；ChatGPT.app 常驻时其自动刷新可持续供给新鲜 token |
| 代理环境变化导致请求失败 | `network` 错误保留上次快照，与现有降级行为一致 |

## 验收标准

1. `swift test` 全部通过。
2. 以 1 分钟间隔运行 8 小时，QuotaBar 及其子进程总下载量 < 2MB（活动监视器 / nettop 抽查）。
3. 401 场景（构造失效 token）UI 显示重新登录提示，恢复有效 token 后自动恢复 Live。
4. 仓库内不再存在 fork `codex app-server` 的代码路径。
5. `AGENTS.md` 边界条款与实现一致。
