# Reset Credit Expiry Settings Query Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 QuotaBar 设置页增加手动查询 reset credits 全部过期时间的只读入口。

**Architecture:** 可测试逻辑全部放在 `CodexUsageCore`：新增 reset credit 过期时间 snapshot、查询错误、provider、JSON mapper 和日期格式化 helper。`CodexUsageWidgetApp` 只持有手动查询状态，并在设置页新增一个结果区块；查询结果不进入现有 `CodexUsageSnapshot`，也不写入共享快照。

**Tech Stack:** Swift 6.2、Swift Package Manager、Foundation、SwiftUI、XCTest、macOS 14+。

## Global Constraints

- 全部沟通、文档和新增代码注释使用中文。
- 用户可见文案默认使用中文；协议字段、URL、Header 名称保持原样。
- 遵循 TDD：先写失败测试，确认失败原因，再实现最小代码使其通过。
- 不自动查询 reset credit 过期时间。
- 不自动刷新或定时刷新这个信息。
- 不持久化过期时间列表、查询结果或额度快照。
- 不把过期时间展示到状态栏、状态栏下拉主视图、桌面小组件或 WidgetKit 组件。
- 不调用重置额度、购买额度、审批、拒绝或修改账号状态的接口。
- 不读取其他应用的私有数据库。
- 不伪造过期时间；查询失败时明确显示失败状态。

---

## File Structure

- Create `Sources/CodexUsageCore/ResetCreditExpiryProvider.swift`
  - 定义 `ResetCreditExpirySnapshot`、`ResetCreditExpiryQueryError`、`ResetCreditExpiryProviding`、`ResetCreditExpiryProvider`、`ResetCreditExpiryResponseMapper`、`ResetCreditExpiryDisplayFormatter`。
  - 负责读取 Codex auth token、发起 wham 只读 GET 请求、解析 `available_count` 和 `credits[].expires_at`。
- Modify `Tests/CodexUsageCoreTests/UsageModelTests.swift`
  - 增加 mapper、排序、token 缺失、非法 JSON、日期格式化测试。
- Modify `Sources/CodexUsageWidgetApp/AppModel.swift`
  - 注入 `ResetCreditExpiryProviding`，新增手动查询状态和 `queryResetCreditExpirations()`。
- Modify `Sources/CodexUsageWidgetApp/UsageViews.swift`
  - 设置页新增 `ResetCreditExpirySettingsSection`，只在设置页展示查询按钮和结果。

---

### Task 1: Core Reset Credit Expiry Provider

**Files:**
- Create: `Sources/CodexUsageCore/ResetCreditExpiryProvider.swift`
- Modify: `Tests/CodexUsageCoreTests/UsageModelTests.swift`

**Interfaces:**
- Produces: `public struct ResetCreditExpirySnapshot: Equatable, Sendable`
- Produces: `public enum ResetCreditExpiryQueryError: Error, Equatable, Sendable`
- Produces: `public protocol ResetCreditExpiryProviding: Sendable`
- Produces: `public struct ResetCreditExpiryProvider: ResetCreditExpiryProviding`
- Produces: `public enum ResetCreditExpiryResponseMapper`

- [ ] **Step 1: Write the failing mapper test**

Append this test to `Tests/CodexUsageCoreTests/UsageModelTests.swift`:

```swift
func testResetCreditExpiryMapperParsesWhamPayload() throws {
    let json = """
    {
      "available_count": 2,
      "credits": [
        {"expires_at": "2026-08-01T19:02:09.000Z"},
        {"expires_at": "2026-07-26T23:26:04.000Z"}
      ]
    }
    """

    let snapshot = try ResetCreditExpiryResponseMapper.map(
        Data(json.utf8),
        fetchedAt: Date(timeIntervalSince1970: 1_783_080_000)
    )

    XCTAssertEqual(snapshot.availableCount, 2)
    XCTAssertEqual(snapshot.expirations, [
        ISO8601DateFormatter().date(from: "2026-07-26T23:26:04.000Z")!,
        ISO8601DateFormatter().date(from: "2026-08-01T19:02:09.000Z")!,
    ])
    XCTAssertEqual(snapshot.fetchedAt, Date(timeIntervalSince1970: 1_783_080_000))
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter UsageModelTests/testResetCreditExpiryMapperParsesWhamPayload
```

Expected: FAIL because `ResetCreditExpiryResponseMapper` is not defined.

- [ ] **Step 3: Write the failing error tests**

Append these tests to `Tests/CodexUsageCoreTests/UsageModelTests.swift`:

```swift
func testResetCreditExpiryMapperRejectsInvalidJSON() {
    XCTAssertThrowsError(try ResetCreditExpiryResponseMapper.map(Data("not json".utf8))) { error in
        XCTAssertEqual(error as? ResetCreditExpiryQueryError, .invalidResponse)
    }
}

func testResetCreditExpiryProviderReportsMissingToken() {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let authURL = directory.appendingPathComponent("auth.json")
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try? Data(#"{"tokens":{}}"#.utf8).write(to: authURL)

    let provider = ResetCreditExpiryProvider(authFileURL: authURL)
    let result = provider.fetchExpirySnapshot()

    XCTAssertEqual(result, .failure(.missingAccessToken))
    try? FileManager.default.removeItem(at: directory)
}
```

- [ ] **Step 4: Run tests to verify they fail**

Run:

```bash
swift test --filter UsageModelTests/testResetCreditExpiry
```

Expected: FAIL because the new provider and error types are not defined.

- [ ] **Step 5: Write minimal implementation**

Create `Sources/CodexUsageCore/ResetCreditExpiryProvider.swift`:

```swift
import Foundation

public struct ResetCreditExpirySnapshot: Equatable, Sendable {
    public let availableCount: Int
    public let expirations: [Date]
    public let fetchedAt: Date

    public init(availableCount: Int, expirations: [Date], fetchedAt: Date = Date()) {
        self.availableCount = availableCount
        self.expirations = expirations.sorted()
        self.fetchedAt = fetchedAt
    }
}

public enum ResetCreditExpiryQueryError: Error, Equatable, Sendable {
    case missingAuthFile
    case missingAccessToken
    case requestFailed(String)
    case invalidResponse
}

public protocol ResetCreditExpiryProviding: Sendable {
    func fetchExpirySnapshot() -> Result<ResetCreditExpirySnapshot, ResetCreditExpiryQueryError>
}

public struct ResetCreditExpiryProvider: ResetCreditExpiryProviding {
    private let authFileURL: URL
    private let endpoint: URL
    private let timeout: TimeInterval

    public init(
        authFileURL: URL = ResetCreditExpiryProvider.defaultAuthFileURL(),
        endpoint: URL = URL(string: "https://chatgpt.com/backend-api/wham/rate-limit-reset-credits")!,
        timeout: TimeInterval = 20
    ) {
        self.authFileURL = authFileURL
        self.endpoint = endpoint
        self.timeout = timeout
    }

    public func fetchExpirySnapshot() -> Result<ResetCreditExpirySnapshot, ResetCreditExpiryQueryError> {
        let tokenResult = accessToken()
        guard case let .success(token) = tokenResult else {
            return .failure(tokenResult.failure ?? .missingAccessToken)
        }

        var request = URLRequest(url: endpoint, timeoutInterval: timeout)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("https://chatgpt.com", forHTTPHeaderField: "Origin")
        request.setValue("https://chatgpt.com/", forHTTPHeaderField: "Referer")

        let semaphore = DispatchSemaphore(value: 0)
        let box = LockedBox<Result<ResetCreditExpirySnapshot, ResetCreditExpiryQueryError>?>(nil)
        URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            if let error {
                box.value = .failure(.requestFailed(error.localizedDescription))
                return
            }
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                box.value = .failure(.requestFailed("HTTP \(http.statusCode)"))
                return
            }
            guard let data else {
                box.value = .failure(.invalidResponse)
                return
            }
            do {
                box.value = .success(try ResetCreditExpiryResponseMapper.map(data))
            } catch let queryError as ResetCreditExpiryQueryError {
                box.value = .failure(queryError)
            } catch {
                box.value = .failure(.invalidResponse)
            }
        }.resume()
        _ = semaphore.wait(timeout: .now() + timeout)
        return box.value ?? .failure(.requestFailed("请求超时"))
    }

    public static func defaultAuthFileURL() -> URL {
        let base = ProcessInfo.processInfo.environment["CODEX_HOME"].map(URL.init(fileURLWithPath:))
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex", isDirectory: true)
        return base.appendingPathComponent("auth.json")
    }

    private func accessToken() -> Result<String, ResetCreditExpiryQueryError> {
        guard FileManager.default.fileExists(atPath: authFileURL.path) else {
            return .failure(.missingAuthFile)
        }
        guard
            let data = try? Data(contentsOf: authFileURL),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let tokens = object["tokens"] as? [String: Any],
            let token = tokens["access_token"] as? String,
            !token.isEmpty
        else {
            return .failure(.missingAccessToken)
        }
        return .success(token)
    }
}

public enum ResetCreditExpiryResponseMapper {
    public static func map(_ data: Data, fetchedAt: Date = Date()) throws -> ResetCreditExpirySnapshot {
        let response: WhamResetCreditResponse
        do {
            response = try JSONDecoder().decode(WhamResetCreditResponse.self, from: data)
        } catch {
            throw ResetCreditExpiryQueryError.invalidResponse
        }
        let expirations = response.credits.compactMap { parseDate($0.expiresAt) }.sorted()
        return ResetCreditExpirySnapshot(
            availableCount: response.availableCount,
            expirations: expirations,
            fetchedAt: fetchedAt
        )
    }

    private static func parseDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}

private struct WhamResetCreditResponse: Decodable {
    let availableCount: Int
    let credits: [WhamResetCredit]

    private enum CodingKeys: String, CodingKey {
        case availableCount = "available_count"
        case credits
    }
}

private struct WhamResetCredit: Decodable {
    let expiresAt: String

    private enum CodingKeys: String, CodingKey {
        case expiresAt = "expires_at"
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

private extension Result {
    var failure: Failure? {
        if case let .failure(error) = self {
            return error
        }
        return nil
    }
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run:

```bash
swift test --filter UsageModelTests/testResetCreditExpiry
```

Expected: PASS.

- [ ] **Step 7: Commit**

Run:

```bash
git add Sources/CodexUsageCore/ResetCreditExpiryProvider.swift Tests/CodexUsageCoreTests/UsageModelTests.swift
git commit -m "feat: add reset credit expiry provider"
```

---

### Task 2: Reset Credit Expiry Display Formatting

**Files:**
- Modify: `Sources/CodexUsageCore/ResetCreditExpiryProvider.swift`
- Modify: `Tests/CodexUsageCoreTests/UsageModelTests.swift`

**Interfaces:**
- Consumes: `ResetCreditExpirySnapshot`
- Produces: `public enum ResetCreditExpiryDisplayFormatter`
- Produces: `ResetCreditExpiryDisplayFormatter.expirationText(_:timeZone:) -> String`
- Produces: `ResetCreditExpiryDisplayFormatter.fetchedAtText(_:timeZone:) -> String`
- Produces: `ResetCreditExpiryDisplayFormatter.errorText(_:) -> String`

- [ ] **Step 1: Write the failing formatter test**

Append this test to `Tests/CodexUsageCoreTests/UsageModelTests.swift`:

```swift
func testResetCreditExpiryDisplayFormatterUsesLocalDateAndClockText() {
    let date = ISO8601DateFormatter().date(from: "2026-07-26T23:26:04.000Z")!
    let fetchedAt = Date(timeIntervalSince1970: 1_783_080_120)
    let timeZone = TimeZone(secondsFromGMT: 8 * 3600)!

    XCTAssertEqual(
        ResetCreditExpiryDisplayFormatter.expirationText(date, timeZone: timeZone),
        "2026-07-27 07:26:04"
    )
    XCTAssertEqual(
        ResetCreditExpiryDisplayFormatter.fetchedAtText(fetchedAt, timeZone: timeZone),
        RefreshScheduleFormatter.clockText(fetchedAt, timeZone: timeZone)
    )
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter UsageModelTests/testResetCreditExpiryDisplayFormatterUsesLocalDateAndClockText
```

Expected: FAIL because `ResetCreditExpiryDisplayFormatter` is not defined.

- [ ] **Step 3: Write the failing error text test**

Append this test to `Tests/CodexUsageCoreTests/UsageModelTests.swift`:

```swift
func testResetCreditExpiryDisplayFormatterShowsSafeErrorText() {
    XCTAssertEqual(
        ResetCreditExpiryDisplayFormatter.errorText(.missingAuthFile),
        "无法查询过期时间，请确认 Codex 已登录。"
    )
    XCTAssertEqual(
        ResetCreditExpiryDisplayFormatter.errorText(.requestFailed("HTTP 401")),
        "无法查询过期时间：HTTP 401"
    )
}
```

- [ ] **Step 4: Run tests to verify they fail**

Run:

```bash
swift test --filter UsageModelTests/testResetCreditExpiryDisplayFormatter
```

Expected: FAIL because formatter is not defined.

- [ ] **Step 5: Write minimal implementation**

Append this enum to `Sources/CodexUsageCore/ResetCreditExpiryProvider.swift`:

```swift
public enum ResetCreditExpiryDisplayFormatter {
    public static func expirationText(_ date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    public static func fetchedAtText(_ date: Date, timeZone: TimeZone = .current) -> String {
        RefreshScheduleFormatter.clockText(date, timeZone: timeZone)
    }

    public static func errorText(_ error: ResetCreditExpiryQueryError) -> String {
        switch error {
        case .missingAuthFile, .missingAccessToken, .invalidResponse:
            return "无法查询过期时间，请确认 Codex 已登录。"
        case .requestFailed(let reason):
            return "无法查询过期时间：\(reason)"
        }
    }
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run:

```bash
swift test --filter UsageModelTests/testResetCreditExpiryDisplayFormatter
```

Expected: PASS.

- [ ] **Step 7: Commit**

Run:

```bash
git add Sources/CodexUsageCore/ResetCreditExpiryProvider.swift Tests/CodexUsageCoreTests/UsageModelTests.swift
git commit -m "feat: format reset credit expiry display"
```

---

### Task 3: Settings Page Manual Query UI

**Files:**
- Modify: `Sources/CodexUsageWidgetApp/AppModel.swift`
- Modify: `Sources/CodexUsageWidgetApp/UsageViews.swift`

**Interfaces:**
- Consumes: `ResetCreditExpiryProviding.fetchExpirySnapshot() -> Result<ResetCreditExpirySnapshot, ResetCreditExpiryQueryError>`
- Consumes: `ResetCreditExpiryDisplayFormatter`
- Produces: `AppModel.resetCreditExpirySnapshot: ResetCreditExpirySnapshot?`
- Produces: `AppModel.resetCreditExpiryErrorText: String?`
- Produces: `AppModel.isQueryingResetCreditExpirations: Bool`
- Produces: `AppModel.queryResetCreditExpirations()`
- Produces: `ResetCreditExpirySettingsSection`

- [ ] **Step 1: Modify AppModel initializer and state**

In `Sources/CodexUsageWidgetApp/AppModel.swift`, add the new published properties and provider injection:

```swift
@Published private(set) var resetCreditExpirySnapshot: ResetCreditExpirySnapshot?
@Published private(set) var resetCreditExpiryErrorText: String?
@Published private(set) var isQueryingResetCreditExpirations = false
```

Add the provider property:

```swift
private let resetCreditExpiryProvider: ResetCreditExpiryProviding
```

Change the initializer signature to:

```swift
init(
    provider: UsageProviding = MockUsageProvider(),
    resetCreditExpiryProvider: ResetCreditExpiryProviding = ResetCreditExpiryProvider(),
    settingsStore: WidgetSettingsStore = WidgetSettingsStore()
) {
    self.provider = provider
    self.resetCreditExpiryProvider = resetCreditExpiryProvider
    self.settingsStore = settingsStore
    self.settings = (settingsStore.load() ?? WidgetSettings()).normalizedForPresentation()
    self.snapshot = nil
    refresh()
}
```

- [ ] **Step 2: Add the manual query method**

Append this method inside `AppModel`:

```swift
func queryResetCreditExpirations() {
    guard !isQueryingResetCreditExpirations else {
        return
    }
    isQueryingResetCreditExpirations = true
    resetCreditExpiryErrorText = nil
    let provider = resetCreditExpiryProvider
    Task.detached {
        let result = provider.fetchExpirySnapshot()
        await MainActor.run {
            switch result {
            case .success(let snapshot):
                self.resetCreditExpirySnapshot = snapshot
                self.resetCreditExpiryErrorText = nil
            case .failure(let error):
                self.resetCreditExpiryErrorText = ResetCreditExpiryDisplayFormatter.errorText(error)
            }
            self.isQueryingResetCreditExpirations = false
        }
    }
}
```

- [ ] **Step 3: Build to catch AppModel integration errors**

Run:

```bash
swift build
```

Expected: PASS.

- [ ] **Step 4: Add the settings section call site**

In `Sources/CodexUsageWidgetApp/UsageViews.swift`, place this below `SettingsActionStrip(model: model)`:

```swift
ResetCreditExpirySettingsSection(model: model)
```

- [ ] **Step 5: Add the settings section view**

Append this view near other settings helper views in `Sources/CodexUsageWidgetApp/UsageViews.swift`:

```swift
private struct ResetCreditExpirySettingsSection: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsRow(
                title: "Reset credits 过期时间",
                detail: "手动查询当前账号可用 reset credits 的过期时间，不会自动刷新。"
            ) {
                Button(model.isQueryingResetCreditExpirations ? "查询中" : "查询过期时间") {
                    model.queryResetCreditExpirations()
                }
                .disabled(model.isQueryingResetCreditExpirations)
            }

            if model.isQueryingResetCreditExpirations || model.resetCreditExpirySnapshot != nil || model.resetCreditExpiryErrorText != nil {
                ResetCreditExpiryResultCard(model: model)
            }
        }
    }
}

private struct ResetCreditExpiryResultCard: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if model.isQueryingResetCreditExpirations {
                Text("正在查询...")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.quotaSecondaryText)
            }

            if let snapshot = model.resetCreditExpirySnapshot {
                Text("可用 Reset credits：\(snapshot.availableCount)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))

                if snapshot.expirations.isEmpty {
                    Text(snapshot.availableCount > 0 ? "过期时间不可用" : "暂无可用 reset credits")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.quotaSecondaryText)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(snapshot.expirations.enumerated()), id: \.offset) { index, date in
                            Text("\(index + 1). \(ResetCreditExpiryDisplayFormatter.expirationText(date))")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .monospacedDigit()
                        }
                    }
                }

                Text("上次查询：\(ResetCreditExpiryDisplayFormatter.fetchedAtText(snapshot.fetchedAt))")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.quotaSecondaryText)
            }

            if let errorText = model.resetCreditExpiryErrorText {
                Text(errorText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.red)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.quotaCardBackground.opacity(0.76), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
```

- [ ] **Step 6: Build to verify UI compiles**

Run:

```bash
swift build
```

Expected: PASS.

- [ ] **Step 7: Commit**

Run:

```bash
git add Sources/CodexUsageWidgetApp/AppModel.swift Sources/CodexUsageWidgetApp/UsageViews.swift
git commit -m "feat: show reset credit expiry query in settings"
```

---

### Task 4: Full Verification And Packaging

**Files:**
- Verify: all files changed by Tasks 1-3

**Interfaces:**
- Consumes: completed implementation from Tasks 1-3
- Produces: verified app build and package output

- [ ] **Step 1: Run full tests**

Run:

```bash
swift test
```

Expected: PASS.

- [ ] **Step 2: Run full build**

Run:

```bash
swift build
```

Expected: PASS.

- [ ] **Step 3: Run app packaging script**

Run:

```bash
Scripts/build-app.sh
```

Expected: completes successfully and generates `.build/QuotaBar.app`.

- [ ] **Step 4: Confirm only intended files changed**

Run:

```bash
git status --short
```

Expected: only intended implementation files are modified, or clean if all implementation commits were made.

- [ ] **Step 5: Commit verification fixes if needed**

If verification required fixes, run:

```bash
git add Sources/CodexUsageCore/ResetCreditExpiryProvider.swift Tests/CodexUsageCoreTests/UsageModelTests.swift Sources/CodexUsageWidgetApp/AppModel.swift Sources/CodexUsageWidgetApp/UsageViews.swift
git commit -m "fix: stabilize reset credit expiry settings query"
```

If no fixes were required, do not create an empty commit.
