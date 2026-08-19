# 直连 HTTP 用量数据源实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 用直连 `GET /backend-api/wham/usage`（~1.3KB/次）替换 fork `codex app-server`（~7MB/次）获取 Codex 用量，消除每分钟刷新带来的 GB 级流量。

**Architecture:** 新增 `WhamUsageProvider`（URLSession 同步请求 + auth.json 只读取凭据）与 `WhamUsageResponseMapper`（snake_case 解码 → 既有 `CodexUsageSnapshot`）；`UsageProviding` 协议改返回 `Result` 以区分 401/网络/解码错误；删除 `CodexAppServerUsageProvider` 与 `CodexRateLimitResponseMapper`。

**Tech Stack:** Swift 6.2 / SwiftUI / AppKit / Swift Package Manager / XCTest。设计依据：`docs/superpowers/specs/2026-08-19-direct-http-usage-provider-design.md`。

## Global Constraints

- 与用户沟通使用中文，称呼"陛下"（AGENTS.md）。
- macOS 14+，Apple Silicon，Swift Package Manager 构建（`swift build` / `swift test`）。
- 提交信息 Conventional Commits 风格：`type(scope): 简明描述`，每提交一个主题。
- 测试夹具不得包含真实 token、user_id、email 或私有用量数据（CONTRIBUTING.md 脱敏要求）。
- 凭据只读：仅读取 `$CODEX_HOME/auth.json`（默认 `~/.codex/auth.json`），绝不写入。
- 不执行登录、token 刷新、购买等写操作。
- 仓库根目录：`/Users/dongx/developer/projects/quota-bar`（下文相对路径均以此为根）。

---

### Task 1: WhamUsageResponseMapper（snake_case 解码与映射）

**Files:**
- Create: `Sources/CodexUsageCore/WhamUsageResponseMapper.swift`
- Test: `Tests/CodexUsageCoreTests/WhamUsageResponseMapperTests.swift`

**Interfaces:**
- Consumes: `CodexUsageSnapshot`、`UsageWindowSnapshot`、`UsageWindowKind`（既有，见 `Sources/CodexUsageCore/UsageModels.swift`）
- Produces: `WhamUsageResponseMapper.map(_ data: Data, now: Date = Date()) -> CodexUsageSnapshot?`（Task 3 的 provider 调用它）

- [ ] **Step 1: 写失败测试**

创建 `Tests/CodexUsageCoreTests/WhamUsageResponseMapperTests.swift`（夹具已脱敏，数值为构造值）：

```swift
import XCTest
@testable import CodexUsageCore

final class WhamUsageResponseMapperTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_787_100_000)

    /// 双窗口完整响应（脱敏夹具，数值为构造值）。
    private let fullResponse = """
    {
      "user_id": "user-fixture000000000000000000",
      "account_id": "",
      "email": "fixture@example.com",
      "plan_type": "plus",
      "rate_limit": {
        "allowed": false,
        "limit_reached": false,
        "primary_window": {
          "used_percent": 40,
          "limit_window_seconds": 18000,
          "reset_after_seconds": 600,
          "reset_at": 1787100600
        },
        "secondary_window": {
          "used_percent": 70,
          "limit_window_seconds": 604800,
          "reset_after_seconds": 300000,
          "reset_at": 1787400000
        }
      },
      "credits": { "has_credits": true, "unlimited": false, "balance": "5" },
      "rate_limit_reset_credits": { "available_count": 2, "applicable_available_count": 2 }
    }
    """

    func testMapsFullResponseIntoDualWindows() {
        let snapshot = WhamUsageResponseMapper.map(Self.data(fullResponse), now: now)

        XCTAssertNotNil(snapshot)
        XCTAssertEqual(snapshot?.planName, "Plus")
        XCTAssertEqual(snapshot?.credits, 5)
        XCTAssertEqual(snapshot?.resetCreditsAvailable, 2)
        XCTAssertEqual(snapshot?.freshness, .live)

        let fiveHour = snapshot?.window(.fiveHour)
        XCTAssertEqual(fiveHour?.remainingPercentage, 60)
        XCTAssertEqual(fiveHour?.resetsIn, 600)
        XCTAssertEqual(fiveHour?.resetsAt, Date(timeIntervalSince1970: 1_787_100_600))

        let sevenDay = snapshot?.window(.sevenDay)
        XCTAssertEqual(sevenDay?.remainingPercentage, 30)
        XCTAssertEqual(sevenDay?.resetsIn, 300_000)
    }

    func testSecondaryWindowNullYieldsSevenDayOnly() {
        let json = """
        {
          "plan_type": "plus",
          "rate_limit": {
            "primary_window": {
              "used_percent": 100,
              "limit_window_seconds": 604800,
              "reset_after_seconds": 101371,
              "reset_at": 1787202167
            },
            "secondary_window": null
          },
          "credits": { "has_credits": false, "unlimited": false, "balance": "0" },
          "rate_limit_reset_credits": { "available_count": 0 }
        }
        """
        let snapshot = WhamUsageResponseMapper.map(Self.data(json), now: now)

        XCTAssertNil(snapshot?.window(.fiveHour))
        XCTAssertNotNil(snapshot?.window(.sevenDay))
        XCTAssertEqual(snapshot?.window(.sevenDay)?.remainingPercentage, 0)
    }

    func testMissingCreditsBalanceMapsToZero() {
        let json = """
        {
          "plan_type": "plus",
          "rate_limit": {
            "primary_window": {
              "used_percent": 10,
              "limit_window_seconds": 18000,
              "reset_after_seconds": 100,
              "reset_at": 1787100100
            },
            "secondary_window": null
          },
          "credits": { "has_credits": false },
          "rate_limit_reset_credits": { "available_count": 0 }
        }
        """
        let snapshot = WhamUsageResponseMapper.map(Self.data(json), now: now)

        XCTAssertEqual(snapshot?.credits, 0)
    }

    func testUnknownWindowSecondsYieldsNoWindow() {
        let json = """
        {
          "plan_type": "plus",
          "rate_limit": {
            "primary_window": {
              "used_percent": 10,
              "limit_window_seconds": 1800,
              "reset_after_seconds": 100,
              "reset_at": 1787100100
            },
            "secondary_window": null
          }
        }
        """
        let snapshot = WhamUsageResponseMapper.map(Self.data(json), now: now)

        XCTAssertNil(snapshot)
    }

    func testUndecodableDataReturnsNil() {
        XCTAssertNil(WhamUsageResponseMapper.map(Data("not json".utf8), now: now))
    }

    private static func data(_ json: String) -> Data {
        Data(json.utf8)
    }
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `cd /Users/dongx/developer/projects/quota-bar && swift test --filter WhamUsageResponseMapperTests 2>&1 | tail -5`
Expected: 编译失败，`cannot find 'WhamUsageResponseMapper' in scope`

- [ ] **Step 3: 实现 mapper**

创建 `Sources/CodexUsageCore/WhamUsageResponseMapper.swift`：

```swift
import Foundation

/// 将 ChatGPT 后端 `/backend-api/wham/usage` 的 snake_case 响应映射为 `CodexUsageSnapshot`。
public enum WhamUsageResponseMapper {
    public static func map(_ data: Data, now: Date = Date()) -> CodexUsageSnapshot? {
        guard let response = try? JSONDecoder().decode(WhamUsageResponse.self, from: data) else {
            return nil
        }

        let windows = [
            window(from: response.rateLimit?.primaryWindow, fallbackKind: .fiveHour, now: now),
            window(from: response.rateLimit?.secondaryWindow, fallbackKind: .sevenDay, now: now),
        ].compactMap { $0 }

        guard !windows.isEmpty else {
            return nil
        }

        return CodexUsageSnapshot(
            windows: windows,
            planName: formatPlanName(response.planType),
            credits: Int(response.credits?.balance ?? "") ?? 0,
            resetCreditsAvailable: response.rateLimitResetCredits?.availableCount ?? 0,
            freshness: .live
        )
    }

    private static func window(
        from limitWindow: WhamRateLimitWindow?,
        fallbackKind: UsageWindowKind,
        now: Date
    ) -> UsageWindowSnapshot? {
        guard let limitWindow else {
            return nil
        }

        let kind: UsageWindowKind
        switch limitWindow.limitWindowSeconds {
        case 18_000:
            kind = .fiveHour
        case 604_800:
            kind = .sevenDay
        case nil:
            kind = fallbackKind
        default:
            return nil
        }

        let resetsIn: TimeInterval?
        if let resetsAt = limitWindow.resetAt {
            resetsIn = max(TimeInterval(resetsAt) - now.timeIntervalSince1970, 0)
        } else {
            resetsIn = nil
        }

        return UsageWindowSnapshot(
            kind: kind,
            remainingPercentage: 100 - (limitWindow.usedPercent ?? 0),
            resetsIn: resetsIn,
            resetsAt: limitWindow.resetAt.map { Date(timeIntervalSince1970: TimeInterval($0)) }
        )
    }

    private static func formatPlanName(_ planType: String?) -> String {
        guard let planType, !planType.isEmpty else {
            return "--"
        }
        return planType.prefix(1).uppercased() + planType.dropFirst()
    }
}

private struct WhamUsageResponse: Decodable {
    let planType: String?
    let rateLimit: WhamRateLimit?
    let credits: WhamCredits?
    let rateLimitResetCredits: WhamResetCredits?

    private enum CodingKeys: String, CodingKey {
        case planType = "plan_type"
        case rateLimit = "rate_limit"
        case credits
        case rateLimitResetCredits = "rate_limit_reset_credits"
    }
}

private struct WhamRateLimit: Decodable {
    let primaryWindow: WhamRateLimitWindow?
    let secondaryWindow: WhamRateLimitWindow?

    private enum CodingKeys: String, CodingKey {
        case primaryWindow = "primary_window"
        case secondaryWindow = "secondary_window"
    }
}

private struct WhamRateLimitWindow: Decodable {
    let usedPercent: Int?
    let limitWindowSeconds: Int?
    let resetAt: Int?

    private enum CodingKeys: String, CodingKey {
        case usedPercent = "used_percent"
        case limitWindowSeconds = "limit_window_seconds"
        case resetAt = "reset_at"
    }
}

private struct WhamCredits: Decodable {
    let balance: String?
}

private struct WhamResetCredits: Decodable {
    let availableCount: Int

    private enum CodingKeys: String, CodingKey {
        case availableCount = "available_count"
    }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `swift test --filter WhamUsageResponseMapperTests 2>&1 | tail -5`
Expected: `Executed 5 tests, with 0 failures`

- [ ] **Step 5: 提交**

```bash
cd /Users/dongx/developer/projects/quota-bar
git add Sources/CodexUsageCore/WhamUsageResponseMapper.swift Tests/CodexUsageCoreTests/WhamUsageResponseMapperTests.swift
git commit -m "feat(core): add wham usage response mapper"
```

---

### Task 2: UsageProviding 协议 Result 化与错误呈现

**Files:**
- Create: `Sources/CodexUsageCore/UsageProviding.swift`
- Modify: `Sources/CodexUsageCore/MockUsageProvider.swift`（移除协议定义、适配 Result）
- Modify: `Sources/CodexUsageCore/CodexAppServerUsageProvider.swift`（临时适配，Task 3 删除）
- Modify: `Sources/CodexUsageWidgetApp/AppModel.swift`（refresh 处理 Result、新增 `usageErrorText`）
- Modify: `Sources/CodexUsageWidgetApp/UsageViews.swift:41-43`（UnavailableBlock 下显示错误文本）

**Interfaces:**
- Consumes: Task 1 无依赖；既有 `AppModel.refresh()` 结构。
- Produces:
  - `protocol UsageProviding { func fetchUsage() -> Result<CodexUsageSnapshot, UsageProviderError> }`
  - `enum UsageProviderError: Error { case missingAuth; case unauthorized; case network(String); case invalidResponse }`
  - `enum UsageProviderErrorDisplayFormatter { static func errorText(_ error: UsageProviderError) -> String }`
  - `AppModel.usageErrorText: String?`（@Published，Task 3 前由 Mock 路径验证）

- [ ] **Step 1: 创建协议与错误类型文件**

创建 `Sources/CodexUsageCore/UsageProviding.swift`：

```swift
import Foundation

public protocol UsageProviding: Sendable {
    func fetchUsage() -> Result<CodexUsageSnapshot, UsageProviderError>
}

public enum UsageProviderError: Error, Equatable, Sendable {
    /// `auth.json` 缺失或 `access_token` 为空。
    case missingAuth
    /// HTTP 401/403，需要重新登录 Codex。
    case unauthorized
    /// 网络不可达、超时或非 2xx 状态码。
    case network(String)
    /// 响应结构无法解码。
    case invalidResponse
}

public enum UsageProviderErrorDisplayFormatter {
    public static func errorText(_ error: UsageProviderError) -> String {
        switch error {
        case .missingAuth, .unauthorized:
            return "无法获取用量，请打开 Codex 重新登录。"
        case .network(let reason):
            return "无法获取用量：\(reason)"
        case .invalidResponse:
            return "无法获取用量，响应格式已变化。"
        }
    }
}
```

- [ ] **Step 2: 适配 Mock 与旧 provider**

`Sources/CodexUsageCore/MockUsageProvider.swift` 整体替换为（协议定义已迁出）：

```swift
public struct MockUsageProvider: UsageProviding {
    public init() {}

    public func fetchUsage() -> Result<CodexUsageSnapshot, UsageProviderError> {
        .success(
            CodexUsageSnapshot(
                windows: [
                    UsageWindowSnapshot(kind: .fiveHour, remainingPercentage: 52, resetsIn: 8_820),
                    UsageWindowSnapshot(kind: .sevenDay, remainingPercentage: 42, resetsIn: 345_600),
                ],
                planName: "Plus",
                credits: 0,
                resetCreditsAvailable: 3,
                freshness: .live
            )
        )
    }
}
```

`Sources/CodexUsageCore/CodexAppServerUsageProvider.swift` 仅改 `fetchUsage` 签名与返回值（第 27-39 行替换为，此文件 Task 3 将整体删除）：

```swift
    public func fetchUsage() -> Result<CodexUsageSnapshot, UsageProviderError> {
        guard FileManager.default.isExecutableFile(atPath: codexExecutablePath) else {
            return .failure(.missingAuth)
        }

        for _ in 0..<maximumAttempts {
            let output = runAppServerRead()
            if let snapshot = Self.extractRateLimitSnapshot(from: output) {
                return .success(snapshot)
            }
        }
        return .failure(.invalidResponse)
    }
```

- [ ] **Step 3: AppModel 处理 Result 并发布错误文本**

`Sources/CodexUsageWidgetApp/AppModel.swift` 两处修改：

第 11 行 `@Published private(set) var resetCreditExpiryErrorText: String?` 之后新增：

```swift
    @Published private(set) var usageErrorText: String?
```

`refresh()`（第 48-66 行）替换为：

```swift
    func refresh() {
        guard !isRefreshing else {
            return
        }
        isRefreshing = true
        let provider = provider
        Task.detached {
            let result = provider.fetchUsage()
            await MainActor.run {
                switch result {
                case .success(let snapshot):
                    self.snapshot = snapshot
                    self.lastRefreshedAt = Date()
                    self.usageErrorText = nil
                    SharedUsageSnapshotStore.save(snapshot)
                case .failure(let error):
                    self.usageErrorText = UsageProviderErrorDisplayFormatter.errorText(error)
                }
                self.isRefreshing = false
                self.restartTimer()
            }
        }
    }
```

- [ ] **Step 4: 下拉面板显示错误文本**

`Sources/CodexUsageWidgetApp/UsageViews.swift` 第 41-43 行的 else 分支：

```swift
            } else {
                UnavailableBlock()
                if let usageErrorText = model.usageErrorText {
                    Text(usageErrorText)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.red)
                }
            }
```

- [ ] **Step 5: 编译与全量测试**

Run: `swift build 2>&1 | tail -3 && swift test 2>&1 | tail -3`
Expected: BUILD SUCCEEDED；全部测试通过（含既有 UsageModelTests、MenuBarUsageFormatterTests、WhamUsageResponseMapperTests）

- [ ] **Step 6: 提交**

```bash
cd /Users/dongx/developer/projects/quota-bar
git add Sources/CodexUsageCore/UsageProviding.swift Sources/CodexUsageCore/MockUsageProvider.swift Sources/CodexUsageCore/CodexAppServerUsageProvider.swift Sources/CodexUsageWidgetApp/AppModel.swift Sources/CodexUsageWidgetApp/UsageViews.swift
git commit -m "refactor(app): usage provider returns result with error text"
```

---

### Task 3: WhamUsageProvider 直连实现与旧路径删除

**Files:**
- Create: `Sources/CodexUsageCore/WhamUsageProvider.swift`
- Test: `Tests/CodexUsageCoreTests/WhamUsageProviderTests.swift`
- Delete: `Sources/CodexUsageCore/CodexAppServerUsageProvider.swift`
- Delete: `Sources/CodexUsageCore/CodexRateLimitResponseMapper.swift`
- Modify: `Sources/CodexUsageWidgetApp/CodexUsageWidgetApp.swift:27`（注入 WhamUsageProvider）

**Interfaces:**
- Consumes: Task 1 `WhamUsageResponseMapper.map(_:)`；Task 2 `UsageProviding`、`UsageProviderError`；`ResetCreditExpiryProvider.defaultAuthFileURL()`（既有 public 静态方法）。
- Produces: `WhamUsageProvider.init(authFileURL:endpoint:timeout:)`、`static func classify(statusCode: Int) -> UsageProviderError?`。

- [ ] **Step 1: 写失败测试（状态码分类纯函数）**

创建 `Tests/CodexUsageCoreTests/WhamUsageProviderTests.swift`：

```swift
import XCTest
@testable import CodexUsageCore

final class WhamUsageProviderTests: XCTestCase {
    func testSuccessStatusCodesReturnNil() {
        XCTAssertNil(WhamUsageProvider.classify(statusCode: 200))
        XCTAssertNil(WhamUsageProvider.classify(statusCode: 204))
    }

    func testUnauthorizedStatusCodes() {
        XCTAssertEqual(WhamUsageProvider.classify(statusCode: 401), .unauthorized)
        XCTAssertEqual(WhamUsageProvider.classify(statusCode: 403), .unauthorized)
    }

    func testOtherStatusCodesMapToNetworkError() {
        XCTAssertEqual(WhamUsageProvider.classify(statusCode: 500), .network("HTTP 500"))
        XCTAssertEqual(WhamUsageProvider.classify(statusCode: 429), .network("HTTP 429"))
    }
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `swift test --filter WhamUsageProviderTests 2>&1 | tail -5`
Expected: 编译失败，`cannot find 'WhamUsageProvider' in scope`

- [ ] **Step 3: 实现 provider**

创建 `Sources/CodexUsageCore/WhamUsageProvider.swift`（同步请求模式与 `ResetCreditExpiryProvider` 对齐）：

```swift
import Foundation

/// 直连 ChatGPT 后端只读端点获取 Codex 用量，凭据只读本机 Codex 登录态。
public struct WhamUsageProvider: UsageProviding {
    private let authFileURL: URL
    private let endpoint: URL
    private let timeout: TimeInterval

    public init(
        authFileURL: URL = ResetCreditExpiryProvider.defaultAuthFileURL(),
        endpoint: URL = URL(string: "https://chatgpt.com/backend-api/wham/usage")!,
        timeout: TimeInterval = 15
    ) {
        self.authFileURL = authFileURL
        self.endpoint = endpoint
        self.timeout = timeout
    }

    public func fetchUsage() -> Result<CodexUsageSnapshot, UsageProviderError> {
        guard
            let credentials = Self.readCredentials(authFileURL: authFileURL)
        else {
            return .failure(.missingAuth)
        }

        var request = URLRequest(url: endpoint, timeoutInterval: timeout)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(credentials.accountId, forHTTPHeaderField: "chatgpt-account-id")
        request.setValue("https://chatgpt.com", forHTTPHeaderField: "Origin")
        request.setValue("https://chatgpt.com/", forHTTPHeaderField: "Referer")

        let semaphore = DispatchSemaphore(value: 0)
        let box = LockedBox<Result<CodexUsageSnapshot, UsageProviderError>?>(nil)
        URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            if let error {
                box.value = .failure(.network(error.localizedDescription))
                return
            }
            if let http = response as? HTTPURLResponse,
               let classified = Self.classify(statusCode: http.statusCode) {
                box.value = .failure(classified)
                return
            }
            guard let data, let snapshot = WhamUsageResponseMapper.map(data) else {
                box.value = .failure(.invalidResponse)
                return
            }
            box.value = .success(snapshot)
        }.resume()
        _ = semaphore.wait(timeout: .now() + timeout)

        return box.value ?? .failure(.network("请求超时"))
    }

    /// HTTP 状态码到错误的分类；2xx 返回 nil。
    static func classify(statusCode: Int) -> UsageProviderError? {
        switch statusCode {
        case 200...299:
            return nil
        case 401, 403:
            return .unauthorized
        default:
            return .network("HTTP \(statusCode)")
        }
    }

    struct Credentials: Equatable {
        let accessToken: String
        let accountId: String
    }

    /// 只读解析 `auth.json` 中的 `tokens.access_token` 与顶层 `account_id`。
    static func readCredentials(authFileURL: URL) -> Credentials? {
        guard FileManager.default.fileExists(atPath: authFileURL.path) else {
            return nil
        }
        guard
            let data = try? Data(contentsOf: authFileURL),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let tokens = object["tokens"] as? [String: Any],
            let accessToken = tokens["access_token"] as? String,
            !accessToken.isEmpty
        else {
            return nil
        }
        let accountId = object["account_id"] as? String ?? ""
        return Credentials(accessToken: accessToken, accountId: accountId)
    }
}

private final class LockedBox<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Value

    init(_ value: Value) {
        self.storage = value
    }

    var value: Value {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storage
        }
        set {
            lock.lock()
            storage = newValue
            lock.unlock()
        }
    }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `swift test --filter WhamUsageProviderTests 2>&1 | tail -5`
Expected: `Executed 3 tests, with 0 failures`

- [ ] **Step 5: 删除旧路径并切换注入**

```bash
cd /Users/dongx/developer/projects/quota-bar
git rm Sources/CodexUsageCore/CodexAppServerUsageProvider.swift Sources/CodexUsageCore/CodexRateLimitResponseMapper.swift
```

`Sources/CodexUsageWidgetApp/CodexUsageWidgetApp.swift` 第 27 行：

```swift
    let model = AppModel(provider: WhamUsageProvider())
```

- [ ] **Step 6: 全量编译与测试**

Run: `swift build 2>&1 | tail -3 && swift test 2>&1 | tail -3`
Expected: BUILD SUCCEEDED；全部测试通过（无对已删除类型的残留引用）

- [ ] **Step 7: 提交**

```bash
cd /Users/dongx/developer/projects/quota-bar
git add Sources/CodexUsageCore/WhamUsageProvider.swift Tests/CodexUsageCoreTests/WhamUsageProviderTests.swift Sources/CodexUsageWidgetApp/CodexUsageWidgetApp.swift
git commit -m "feat(core): fetch usage via wham endpoint"
```

---

### Task 4: AGENTS.md 边界修订与端到端验证

**Files:**
- Modify: `AGENTS.md`（「数据与安全边界」第一条）

**Interfaces:**
- Consumes: Task 1-3 全部产出。
- Produces: 与实现一致的文档；可分发的 `.app`。

- [ ] **Step 1: 修订 AGENTS.md 数据边界条款**

`AGENTS.md`「数据与安全边界」中这一行：

```
- 常规用量只通过本机 ChatGPT / 旧版 Codex App 内的 `codex app-server --stdio` 获取，使用 `account/rateLimits/read`。
```

替换为：

```
- 常规用量通过 ChatGPT 后端只读端点 `/backend-api/wham/usage` 获取；凭据只读取本机 Codex 登录态（`auth.json`），应用不写入该文件。
```

- [ ] **Step 2: 真机冒烟验证（网络路径）**

构建并运行 debug 可执行文件，观察菜单栏数据（需要本机已登录 Codex）：

```bash
cd /Users/dongx/developer/projects/quota-bar
swift build 2>&1 | tail -2
.build/debug/CodexUsageWidgetApp & sleep 12
ps aux | grep -i "[C]odexUsageWidgetApp" && echo "running"
```

Expected: 进程存在；约 15 秒内菜单栏出现用量（本机 auth.json 有效时）。随后终止进程：`pkill -f CodexUsageWidgetApp`。

若验证环境无法登录或无代理，可跳过运行观察，但必须完成 Step 3 的全量测试。

- [ ] **Step 3: 全量测试**

Run: `swift test 2>&1 | tail -3`
Expected: 全部通过，0 failures。

- [ ] **Step 4: 提交**

```bash
cd /Users/dongx/developer/projects/quota-bar
git add AGENTS.md
git commit -m "docs: update data source boundary in agents guide"
```

- [ ] **Step 5: 汇报**

向陛下汇报：变更摘要、测试结果、冒烟验证结论（含菜单栏截图说明或跳过原因）、建议后续（发布新版本 + 向 codex 上游反馈 models 请求风暴）。

---

## 自审记录

- **Spec 覆盖**：字段映射（Task 1）、协议与错误（Task 2）、provider 与删除（Task 3）、AGENTS.md 修订与验证（Task 4）、验收标准 1/4/5 由 Task 3-4 覆盖；验收标准 2（8 小时流量）与 3（401 提示）属运行期验证，Task 4 Step 2 冒烟覆盖 3 的前提路径，2 建议发布后抽查。
- **占位符**：无 TBD/TODO，所有步骤含完整代码或精确命令。
- **类型一致性**：`WhamUsageResponseMapper.map(_:)`、`UsageProviding.fetchUsage() -> Result`、`UsageProviderError` 四个 case、`classify(statusCode:)`、`AppModel.usageErrorText` 在各 Task 间引用一致。
