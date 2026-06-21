# Perch AI Alpha Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a source-distributed macOS application that monitors Claude Code, Codex CLI, and Codex Desktop, then presents trustworthy task state and subscription usage through Ambient HUD, Land, and Task Center surfaces.

**Architecture:** A SwiftUI/AppKit host owns the canonical task and usage state. Bundled adapter executables convert tool-specific hooks into a versioned NDJSON protocol and communicate over a per-user Unix socket; the host supervises adapters and never interprets private tool payloads in UI code. This plan implements the approved Foundation and AI Alpha phases only; System HUD, Media, Calendar, lock-screen work, and a third-party plugin SDK require separate specs and plans.

**Tech Stack:** Swift 6.2, Swift Package Manager, SwiftUI, AppKit, Foundation, Network/Darwin Unix sockets, XCTest, macOS 14+ on Apple Silicon.

## Global Constraints

- Deployment target is macOS 14.0; supported CPU architecture is Apple Silicon (`arm64`).
- Distribution is source-first plus optional unsigned ZIP/DMG artifacts; do not add App Store entitlements.
- Do not request Accessibility, Input Monitoring, Full Disk Access, or Calendar permission in this plan.
- Perch is read-only: it may notify and deep-link, but must not approve, deny, reset quota, or steer AI tasks.
- Default persisted task content and usage snapshots must remain exactly zero bytes.
- Do not read Codex Desktop databases, scrape another app's UI, or observe another app's notifications.
- Built-in adapters use the plugin protocol, but external plugin discovery and installation are out of scope.
- Missing capability must render as unavailable or degraded; never fabricate progress, source surface, or remaining task count.
- Hook and status-line helpers must fail open and must not block Claude Code or Codex.
- All configuration edits require preview, backup, ownership markers, fingerprint checks, atomic replacement, and reversible uninstall.

---

## Scope Decomposition

This plan delivers one independently testable product slice: Foundation plus AI Alpha. The following approved roadmap items intentionally remain outside this plan:

- System HUD Beta: volume, display brightness, keyboard backlight, output devices, and native HUD suppression research.
- Media and Activities: Now Playing, battery/device activities, Calendar, lock screen, Liquid Glass, and themes beyond the Alpha appearance.
- Third-party plugin SDK, signing/notarization, Sparkle updates, and release automation beyond unsigned artifacts.

Each excluded area needs its own design review after the Alpha validates the window host and event pipeline.

## Final File Map

```text
Package.swift                                  SwiftPM products, targets, resources
Sources/
  PerchProtocol/                               Cross-process Codable contracts only
    JSONValue.swift
    EventEnvelope.swift
    PluginMessages.swift
    NDJSONCodec.swift
    UsageSnapshot.swift
  PerchTransport/                              Unix socket framing and permissions
    UnixSocketAddress.swift
    UnixSocketClient.swift
    UnixSocketServer.swift
  PerchCore/                                    Pure state and policies
    Tasks/TaskSnapshot.swift
    Tasks/TaskReducer.swift
    Tasks/EventDeduplicator.swift
    Tasks/TaskStore.swift
    Notifications/LandNotification.swift
    Notifications/NotificationPolicy.swift
    Notifications/LandBatcher.swift
    Plugins/AdapterProcessSpec.swift
    Plugins/PluginSupervisor.swift
    Plugins/ProcessAdapterLauncher.swift
    Plugins/RestartBackoff.swift
    Usage/UsageCenter.swift
    Usage/UsageAlertPolicy.swift
    Diagnostics/DoctorReport.swift
    Notifications/PresentationPolicy.swift
  AdapterSupport/                               Shared adapter CLI/runtime
    AdapterCommand.swift
    AdapterOutputWriter.swift
    AdapterRuntime.swift
    HookEmitter.swift
    Sanitizer.swift
  ClaudeAdapter/
    ClaudeAdapterMain.swift
    ClaudeEventMapper.swift
    ClaudeUsageMapper.swift
  CodexAdapter/
    CodexAdapterMain.swift
    CodexEventMapper.swift
    CodexAppServerTransport.swift
    CodexRateLimitClient.swift
  PerchStatusLineTap/
    StatusLineTapMain.swift
    PassthroughCommand.swift
  PerchInstaller/
    ConfigurationFingerprint.swift
    AtomicFileEditor.swift
    OwnershipManifest.swift
    ClaudeConfigurationInstaller.swift
    CodexConfigurationInstaller.swift
    CodexNotifyPatcher.swift
    InstallationService.swift
  PerchUI/
    AppModel.swift
    Actions/DeepLinkService.swift
    Ambient/AmbientHUDView.swift
    Land/LandNotificationView.swift
    Tasks/TaskCenterView.swift
    Usage/UsageBarsView.swift
    Settings/SettingsView.swift
    Settings/DoctorView.swift
    Windows/DisplayCoordinator.swift
    Windows/WindowPlacement.swift
    Windows/PerchPanel.swift
    Windows/WindowHost.swift
  PerchApp/
    PerchApp.swift
    AppComposition.swift
    Resources/Info.plist
Tests/
  PerchProtocolTests/
  PerchTransportTests/
  PerchCoreTests/
  AdapterSupportTests/
  ClaudeAdapterTests/Fixtures/
  CodexAdapterTests/Fixtures/
  PerchInstallerTests/Fixtures/
  PerchStatusLineTapTests/
  PerchUITests/
Scripts/
  build-app.sh
  package-unsigned.sh
  run-alpha-smoke.sh
README.md
docs/alpha-testing.md
```

Responsibility rule: protocol files contain no process, filesystem, UI, or vendor logic; adapters contain vendor mapping but no UI; Core contains deterministic state; UI consumes immutable snapshots; installer code is the only code allowed to modify user configuration.

---

### Task 1: Bootstrap the Swift package and app bundle

**Files:**
- Create: `Package.swift`
- Create: `Sources/PerchCore/BuildMetadata.swift`
- Create: `Sources/PerchApp/PerchApp.swift`
- Create: `Sources/PerchApp/Resources/Info.plist`
- Create: `Scripts/build-app.sh`
- Create: `Tests/PerchCoreTests/BuildMetadataTests.swift`

**Interfaces:**
- Produces: `BuildMetadata.minimumMacOS: String`, `BuildMetadata.supportedArchitecture: String`, the `PerchApp` SwiftPM executable, and `Scripts/build-app.sh` that creates `.build/Perch.app`.
- Consumes: none.

- [ ] **Step 1: Create the package manifest and failing platform metadata test**

```swift
// Package.swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Perch",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PerchCore", targets: ["PerchCore"]),
        .executable(name: "PerchApp", targets: ["PerchApp"]),
    ],
    targets: [
        .target(name: "PerchCore"),
        .executableTarget(
            name: "PerchApp",
            dependencies: ["PerchCore"],
            resources: [.copy("Resources/Info.plist")]
        ),
        .testTarget(name: "PerchCoreTests", dependencies: ["PerchCore"]),
    ]
)
```

```swift
// Tests/PerchCoreTests/BuildMetadataTests.swift
import XCTest
@testable import PerchCore

final class BuildMetadataTests: XCTestCase {
    func testAlphaPlatformContract() {
        XCTAssertEqual(BuildMetadata.minimumMacOS, "14.0")
        XCTAssertEqual(BuildMetadata.supportedArchitecture, "arm64")
    }
}
```

- [ ] **Step 2: Run the test and verify the missing type failure**

Run: `swift test --filter BuildMetadataTests`

Expected: FAIL with `cannot find 'BuildMetadata' in scope`.

- [ ] **Step 3: Add the minimal metadata, SwiftUI entry point, Info.plist, and bundle script**

```swift
// Sources/PerchCore/BuildMetadata.swift
public enum BuildMetadata {
    public static let minimumMacOS = "14.0"
    public static let supportedArchitecture = "arm64"
}
```

```swift
// Sources/PerchApp/PerchApp.swift
import SwiftUI

@main
struct PerchApp: App {
    var body: some Scene {
        MenuBarExtra("Perch", systemImage: "bird") {
            Text("Perch Alpha")
        }
        Settings { Text("Perch Settings") }
    }
}
```

```xml
<!-- Sources/PerchApp/Resources/Info.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>dev.perch.app</string>
  <key>CFBundleName</key><string>Perch</string>
  <key>CFBundleExecutable</key><string>PerchApp</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
</dict></plist>
```

```bash
#!/bin/zsh
# Scripts/build-app.sh
set -euo pipefail
swift build -c release --arch arm64
APP="$PWD/.build/Perch.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/arm64-apple-macosx/release/PerchApp "$APP/Contents/MacOS/PerchApp"
cp Sources/PerchApp/Resources/Info.plist "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist"
echo "$APP"
```

Run: `chmod +x Scripts/build-app.sh`

- [ ] **Step 4: Verify tests and bundle creation**

Run: `swift test && Scripts/build-app.sh && test -x .build/Perch.app/Contents/MacOS/PerchApp`

Expected: all tests PASS, `plutil` reports `OK`, and the final `test` exits 0.

- [ ] **Step 5: Commit the bootstrap**

```bash
git add Package.swift Sources/PerchCore Sources/PerchApp Scripts/build-app.sh Tests/PerchCoreTests
git commit -m "build: bootstrap Perch macOS app"
```

---

### Task 2: Define the versioned event and plugin protocol

**Files:**
- Modify: `Package.swift`
- Create: `Sources/PerchProtocol/JSONValue.swift`
- Create: `Sources/PerchProtocol/EventEnvelope.swift`
- Create: `Sources/PerchProtocol/PluginMessages.swift`
- Create: `Sources/PerchProtocol/NDJSONCodec.swift`
- Create: `Sources/PerchProtocol/UsageSnapshot.swift`
- Create: `Tests/PerchProtocolTests/ProtocolRoundTripTests.swift`

**Interfaces:**
- Produces: `EventEnvelope`, `EventType`, `EventSource`, `EventSurface`, `JSONValue`, `PluginHello`, `PluginReady`, `AdapterOutput`, `AdapterCapability`, `UsageSnapshot`, and `NDJSONCodec`.
- Consumes: none.

- [ ] **Step 1: Add `PerchProtocol` targets and a failing round-trip test**

Add to `Package.swift` products and targets:

```swift
.library(name: "PerchProtocol", targets: ["PerchProtocol"]),
// targets:
.target(name: "PerchProtocol"),
.testTarget(name: "PerchProtocolTests", dependencies: ["PerchProtocol"]),
```

```swift
// Tests/PerchProtocolTests/ProtocolRoundTripTests.swift
import XCTest
@testable import PerchProtocol

final class ProtocolRoundTripTests: XCTestCase {
    func testEventRoundTripPreservesUnknownSurface() throws {
        let event = EventEnvelope(
            eventId: "evt-1",
            emittedAt: Date(timeIntervalSince1970: 1_700_000_000),
            source: .codex,
            surface: .unknown,
            sessionId: "session-1",
            turnId: "turn-1",
            taskId: nil,
            type: .turnStarted,
            payload: ["summary": .string("safe summary")]
        )
        let line = try NDJSONCodec.encode(event)
        XCTAssertEqual(try NDJSONCodec.decode(EventEnvelope.self, from: line), event)
        XCTAssertTrue(line.hasSuffix("\n"))
    }
}
```

- [ ] **Step 2: Run the test and verify protocol types are missing**

Run: `swift test --filter ProtocolRoundTripTests`

Expected: FAIL with missing `EventEnvelope` and `NDJSONCodec` symbols.

- [ ] **Step 3: Implement the protocol contracts**

```swift
// Sources/PerchProtocol/JSONValue.swift
import Foundation

public enum JSONValue: Codable, Equatable, Sendable {
    case string(String), number(Double), bool(Bool), object([String: JSONValue])
    case array([JSONValue]), null

    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        if value.decodeNil() { self = .null }
        else if let v = try? value.decode(Bool.self) { self = .bool(v) }
        else if let v = try? value.decode(Double.self) { self = .number(v) }
        else if let v = try? value.decode(String.self) { self = .string(v) }
        else if let v = try? value.decode([String: JSONValue].self) { self = .object(v) }
        else { self = .array(try value.decode([JSONValue].self)) }
    }

    public func encode(to encoder: Encoder) throws {
        var value = encoder.singleValueContainer()
        switch self {
        case .string(let v): try value.encode(v)
        case .number(let v): try value.encode(v)
        case .bool(let v): try value.encode(v)
        case .object(let v): try value.encode(v)
        case .array(let v): try value.encode(v)
        case .null: try value.encodeNil()
        }
    }
}

public extension Dictionary where Key == String, Value == JSONValue {
    func string(_ key: String) -> String? {
        guard case .string(let value) = self[key] else { return nil }
        return value
    }
}
```

```swift
// Sources/PerchProtocol/EventEnvelope.swift
import Foundation

public enum EventSource: String, Codable, Hashable, Sendable { case claude, codex }
public enum EventSurface: String, Codable, Hashable, Sendable { case cli, desktop, unknown }
public enum EventType: String, Codable, Sendable {
    case sessionStarted = "session.started"
    case turnStarted = "turn.started"
    case activityChanged = "activity.changed"
    case taskChanged = "task.changed"
    case attentionRequired = "attention.required"
    case turnCompleted = "turn.completed"
    case turnFailed = "turn.failed"
    case sessionEnded = "session.ended"
}

public struct EventEnvelope: Codable, Equatable, Sendable {
    public let schemaVersion = 1
    public let eventId: String
    public let emittedAt: Date
    public let source: EventSource
    public let surface: EventSurface
    public let sessionId: String
    public let turnId: String?
    public let taskId: String?
    public let type: EventType
    public let payload: [String: JSONValue]

    public init(eventId: String, emittedAt: Date, source: EventSource,
                surface: EventSurface, sessionId: String, turnId: String?,
                taskId: String?, type: EventType, payload: [String: JSONValue]) {
        self.eventId = eventId; self.emittedAt = emittedAt; self.source = source
        self.surface = surface; self.sessionId = sessionId; self.turnId = turnId
        self.taskId = taskId; self.type = type; self.payload = payload
    }
}
```

```swift
// Sources/PerchProtocol/PluginMessages.swift
public enum AdapterCapability: String, Codable, Sendable, CaseIterable {
    case taskTree, toolActivity, approvalAttention, progressEstimate, accountUsage, deepLink
}
public struct PluginHello: Codable, Equatable, Sendable {
    public let protocolVersion: Int
    public let hostVersion: String
    public init(protocolVersion: Int, hostVersion: String) {
        self.protocolVersion = protocolVersion; self.hostVersion = hostVersion
    }
}
public struct PluginReady: Codable, Equatable, Sendable {
    public let protocolVersion: Int
    public let adapterId: String
    public let adapterVersion: String
    public let supportedSources: [EventSource]
    public let capabilities: Set<AdapterCapability>
    public let minimumToolVersions: [String: String]
    public init(protocolVersion: Int, adapterId: String, adapterVersion: String,
                supportedSources: [EventSource], capabilities: Set<AdapterCapability>,
                minimumToolVersions: [String: String]) {
        self.protocolVersion = protocolVersion; self.adapterId = adapterId
        self.adapterVersion = adapterVersion; self.supportedSources = supportedSources
        self.capabilities = capabilities; self.minimumToolVersions = minimumToolVersions
    }
}
public enum AdapterOutputKind: String, Codable, Sendable { case event, usage }
public struct AdapterOutput: Codable, Equatable, Sendable {
    public let kind: AdapterOutputKind
    public let event: EventEnvelope?
    public let usage: UsageSnapshot?
    public static func event(_ value: EventEnvelope) -> Self { .init(kind: .event, event: value, usage: nil) }
    public static func usage(_ value: UsageSnapshot) -> Self { .init(kind: .usage, event: nil, usage: value) }
}
```

```swift
// Sources/PerchProtocol/UsageSnapshot.swift
import Foundation
public enum UsageProvider: String, Codable, Hashable, Sendable { case claude, codex }
public enum UsageFreshness: String, Codable, Sendable { case live, stale, unavailable }
public struct UsageWindow: Codable, Equatable, Sendable {
    public let kind: String
    public let usedPercentage: Double
    public let resetsAt: Date?
    public init(kind: String, usedPercentage: Double, resetsAt: Date?) {
        self.kind = kind; self.usedPercentage = usedPercentage; self.resetsAt = resetsAt
    }
}
public struct UsageSnapshot: Codable, Equatable, Sendable {
    public let provider: UsageProvider
    public let windows: [UsageWindow]
    public let fetchedAt: Date
    public let freshness: UsageFreshness
    public init(provider: UsageProvider, windows: [UsageWindow], fetchedAt: Date,
                freshness: UsageFreshness) {
        self.provider = provider; self.windows = windows
        self.fetchedAt = fetchedAt; self.freshness = freshness
    }
}
```

```swift
// Sources/PerchProtocol/NDJSONCodec.swift
import Foundation
public enum NDJSONCodec {
    private static let encoder: JSONEncoder = { let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e }()
    private static let decoder: JSONDecoder = { let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d }()
    public static func encode<T: Encodable>(_ value: T) throws -> String {
        String(decoding: try encoder.encode(value), as: UTF8.self) + "\n"
    }
    public static func decode<T: Decodable>(_ type: T.Type, from line: String) throws -> T {
        try decoder.decode(type, from: Data(line.trimmingCharacters(in: .newlines).utf8))
    }
}
```

- [ ] **Step 4: Run protocol tests**

Run: `swift test --filter PerchProtocolTests`

Expected: PASS.

- [ ] **Step 5: Commit the protocol**

```bash
git add Package.swift Sources/PerchProtocol Tests/PerchProtocolTests
git commit -m "feat: define Perch adapter protocol"
```

---

### Task 3: Implement deterministic task reduction and deduplication

**Files:**
- Modify: `Package.swift`
- Create: `Sources/PerchCore/Tasks/TaskSnapshot.swift`
- Create: `Sources/PerchCore/Tasks/EventDeduplicator.swift`
- Create: `Sources/PerchCore/Tasks/TaskReducer.swift`
- Create: `Tests/PerchCoreTests/TaskReducerTests.swift`

**Interfaces:**
- Consumes: `EventEnvelope` and `EventType` from Task 2.
- Produces: `TaskKey`, `TaskStatus`, `TaskSnapshot`, `EventDeduplicator.accepts(_:)`, and `TaskReducer.reduce(_:into:)`.

- [ ] **Step 1: Add the protocol dependency and failing terminal-state tests**

Update the `PerchCore` target to `dependencies: ["PerchProtocol"]`, then add:

```swift
// Tests/PerchCoreTests/TaskReducerTests.swift
import XCTest
import PerchProtocol
@testable import PerchCore

final class TaskReducerTests: XCTestCase {
    func testTerminalStateNeverRegresses() {
        var snapshot = TaskSnapshot.make(for: event(.turnStarted, id: "1"))
        TaskReducer.reduce(event(.turnCompleted, id: "2"), into: &snapshot)
        TaskReducer.reduce(event(.activityChanged, id: "3"), into: &snapshot)
        XCTAssertEqual(snapshot.status, .succeeded)
    }

    func testDuplicateEventIsRejected() {
        var deduplicator = EventDeduplicator(capacity: 10)
        XCTAssertTrue(deduplicator.accepts("same"))
        XCTAssertFalse(deduplicator.accepts("same"))
    }

    private func event(_ type: EventType, id: String) -> EventEnvelope {
        EventEnvelope(eventId: id, emittedAt: .now, source: .codex, surface: .unknown,
                      sessionId: "s", turnId: "t", taskId: nil, type: type,
                      payload: ["summary": .string("safe")])
    }
}
```

- [ ] **Step 2: Verify the reducer types do not exist**

Run: `swift test --filter TaskReducerTests`

Expected: FAIL with missing `TaskSnapshot`, `TaskReducer`, and `EventDeduplicator`.

- [ ] **Step 3: Implement snapshots, bounded deduplication, and terminal guards**

```swift
// Sources/PerchCore/Tasks/TaskSnapshot.swift
import Foundation
import PerchProtocol

public struct TaskKey: Hashable, Sendable {
    public let source: EventSource; public let surface: EventSurface
    public let sessionId: String; public let turnId: String?
    public init(source: EventSource, surface: EventSurface, sessionId: String, turnId: String?) {
        self.source = source; self.surface = surface; self.sessionId = sessionId; self.turnId = turnId
    }
}
public enum TaskStatus: Equatable, Sendable {
    case discovered, running, waitingForUser, succeeded, failed, interrupted, stale
    public var isTerminal: Bool { [.succeeded, .failed, .interrupted].contains(self) }
}
public struct TaskSnapshot: Equatable, Sendable {
    public let key: TaskKey
    public var status: TaskStatus
    public var projectName: String?
    public var summary: String?
    public var lastActivity: String?
    public let startedAt: Date
    public var updatedAt: Date
    public init(key: TaskKey, status: TaskStatus, projectName: String? = nil,
                summary: String?, lastActivity: String?, startedAt: Date? = nil,
                updatedAt: Date) {
        self.key = key; self.status = status; self.projectName = projectName
        self.summary = summary; self.lastActivity = lastActivity
        self.startedAt = startedAt ?? updatedAt; self.updatedAt = updatedAt
    }
    public static func make(for event: EventEnvelope) -> Self {
        .init(key: .init(source: event.source, surface: event.surface,
                         sessionId: event.sessionId, turnId: event.turnId),
              status: .discovered, projectName: event.payload.string("project"),
              summary: event.payload.string("summary"), lastActivity: nil,
              startedAt: event.emittedAt, updatedAt: event.emittedAt)
    }
}
```

```swift
// Sources/PerchCore/Tasks/EventDeduplicator.swift
public struct EventDeduplicator: Sendable {
    private let capacity: Int
    private var order: [String] = []
    private var values: Set<String> = []
    public init(capacity: Int = 2_048) { self.capacity = capacity }
    public mutating func accepts(_ id: String) -> Bool {
        guard values.insert(id).inserted else { return false }
        order.append(id)
        if order.count > capacity { values.remove(order.removeFirst()) }
        return true
    }
}
```

```swift
// Sources/PerchCore/Tasks/TaskReducer.swift
import PerchProtocol
public enum TaskReducer {
    public static func reduce(_ event: EventEnvelope, into state: inout TaskSnapshot) {
        guard !state.status.isTerminal else { return }
        state.updatedAt = max(state.updatedAt, event.emittedAt)
        switch event.type {
        case .sessionStarted: state.status = .discovered
        case .turnStarted: state.status = .running
        case .activityChanged:
            state.status = .running; state.lastActivity = event.payload.string("activity")
        case .taskChanged: state.status = .running
        case .attentionRequired: state.status = .waitingForUser
        case .turnCompleted: state.status = .succeeded
        case .turnFailed: state.status = .failed
        case .sessionEnded: state.status = .interrupted
        }
        state.summary = event.payload.string("summary") ?? state.summary
        state.projectName = event.payload.string("project") ?? state.projectName
    }
}
```

- [ ] **Step 4: Run reducer tests and the full suite**

Run: `swift test --filter TaskReducerTests && swift test`

Expected: PASS.

- [ ] **Step 5: Commit the deterministic task core**

```bash
git add Package.swift Sources/PerchCore/Tasks Tests/PerchCoreTests/TaskReducerTests.swift
git commit -m "feat: reduce adapter events into task state"
```

---

### Task 4: Add Land notification policy and two-second batching

**Files:**
- Create: `Sources/PerchCore/Notifications/LandNotification.swift`
- Create: `Sources/PerchCore/Notifications/NotificationPolicy.swift`
- Create: `Sources/PerchCore/Notifications/LandBatcher.swift`
- Create: `Tests/PerchCoreTests/NotificationPolicyTests.swift`

**Interfaces:**
- Consumes: `TaskSnapshot`, `TaskStatus`, and `TaskKey` from Task 3.
- Produces: `LandNotification`, `LandPriority`, `NotificationDecision`, `NotificationPolicy.decision(for:previous:)`, and `LandBatcher.insert(_:)`.

- [ ] **Step 1: Write failing policy and batching tests**

```swift
// Tests/PerchCoreTests/NotificationPolicyTests.swift
import XCTest
import PerchProtocol
@testable import PerchCore

final class NotificationPolicyTests: XCTestCase {
    func testWaitingForUserIsP0() {
        let snapshot = fixture(status: .waitingForUser)
        XCTAssertEqual(NotificationPolicy().decision(for: snapshot, previous: .running).priority, .p0)
    }
    func testRunningDoesNotProduceLand() {
        XCTAssertEqual(NotificationPolicy().decision(for: fixture(status: .running), previous: .discovered), .none)
    }
    func testCompletionsFromSameSourceBatchWithinTwoSeconds() {
        var batcher = LandBatcher(window: 2)
        XCTAssertEqual(batcher.insert(notification(id: "1", at: 10)).count, 1)
        XCTAssertEqual(batcher.insert(notification(id: "2", at: 11)).count, 2)
    }
    private func fixture(status: TaskStatus) -> TaskSnapshot {
        .init(key: .init(source: .codex, surface: .unknown, sessionId: "s", turnId: "t"),
              status: status, projectName: "perch", summary: "safe", lastActivity: nil,
              startedAt: Date(timeIntervalSince1970: 5),
              updatedAt: Date(timeIntervalSince1970: 10))
    }
    private func notification(id: String, at: TimeInterval) -> LandNotification {
        .init(id: id, source: .codex, priority: .p1, status: .succeeded,
              projectName: "perch", summary: "safe", duration: 5,
              createdAt: Date(timeIntervalSince1970: at))
    }
}
```

- [ ] **Step 2: Verify notification symbols are missing**

Run: `swift test --filter NotificationPolicyTests`

Expected: FAIL with missing `NotificationPolicy` and `LandBatcher`.

- [ ] **Step 3: Implement minimal policy and batcher**

```swift
// Sources/PerchCore/Notifications/LandNotification.swift
import Foundation
import PerchProtocol
public enum LandPriority: Int, Codable, Sendable { case p0 = 0, p1 = 1 }
public struct LandNotification: Equatable, Sendable, Identifiable {
    public let id: String
    public let source: EventSource
    public let priority: LandPriority
    public let status: TaskStatus
    public let projectName: String?
    public let summary: String?
    public let duration: TimeInterval
    public let createdAt: Date
    public let batchCount: Int
    public init(id: String, source: EventSource, priority: LandPriority,
                status: TaskStatus, projectName: String?, summary: String?,
                duration: TimeInterval, createdAt: Date, batchCount: Int = 1) {
        self.id = id; self.source = source; self.priority = priority
        self.status = status; self.projectName = projectName; self.summary = summary
        self.duration = duration; self.createdAt = createdAt; self.batchCount = batchCount
    }
    public func batched(count: Int) -> Self {
        .init(id: id, source: source, priority: priority, status: status,
              projectName: projectName, summary: summary, duration: duration,
              createdAt: createdAt, batchCount: count)
    }
}
public enum NotificationDecision: Equatable, Sendable {
    case none, enqueue(LandNotification)
    public var priority: LandPriority? {
        guard case .enqueue(let value) = self else { return nil }; return value.priority
    }
}
```

```swift
// Sources/PerchCore/Notifications/NotificationPolicy.swift
public struct NotificationPolicy: Sendable {
    public init() {}
    public func decision(for task: TaskSnapshot, previous: TaskStatus) -> NotificationDecision {
        guard task.status != previous else { return .none }
        let priority: LandPriority
        switch task.status {
        case .waitingForUser, .failed: priority = .p0
        case .succeeded: priority = .p1
        default: return .none
        }
        return .enqueue(.init(id: "\(task.key.sessionId):\(task.updatedAt.timeIntervalSince1970)",
                              source: task.key.source, priority: priority, status: task.status,
                              projectName: task.projectName, summary: task.summary,
                              duration: max(0, task.updatedAt.timeIntervalSince(task.startedAt)),
                              createdAt: task.updatedAt))
    }
}
```

```swift
// Sources/PerchCore/Notifications/LandBatcher.swift
public struct LandBatcher: Sendable {
    private let window: TimeInterval
    private var batch: [LandNotification] = []
    public init(window: TimeInterval = 2) { self.window = window }
    public mutating func insert(_ value: LandNotification) -> [LandNotification] {
        if let first = batch.first,
           first.source != value.source || first.status != .succeeded || value.status != .succeeded ||
           value.createdAt.timeIntervalSince(first.createdAt) > window {
            batch = []
        }
        batch.append(value)
        return batch
    }
}
```

- [ ] **Step 4: Run policy tests**

Run: `swift test --filter NotificationPolicyTests`

Expected: PASS, including P0, no-Land, and batching cases.

- [ ] **Step 5: Commit notification behavior**

```bash
git add Sources/PerchCore/Notifications Tests/PerchCoreTests/NotificationPolicyTests.swift
git commit -m "feat: add Land notification policy"
```

---

### Task 5: Supervise adapter processes with version checks and backoff

**Files:**
- Modify: `Package.swift`
- Create: `Sources/PerchCore/Plugins/AdapterProcessSpec.swift`
- Create: `Sources/PerchCore/Plugins/RestartBackoff.swift`
- Create: `Sources/PerchCore/Plugins/PluginSupervisor.swift`
- Create: `Tests/PerchCoreTests/PluginSupervisorTests.swift`

**Interfaces:**
- Consumes: `PluginReady`, `PluginHello`, and `AdapterCapability` from Task 2.
- Produces: `AdapterProcessSpec`, `AdapterHealth`, `AdapterLaunching`, `RestartBackoff.delay(forAttempt:)`, and actor `PluginSupervisor`.

- [ ] **Step 1: Write failing compatibility and restart tests**

```swift
// Tests/PerchCoreTests/PluginSupervisorTests.swift
import XCTest
import PerchProtocol
@testable import PerchCore

final class PluginSupervisorTests: XCTestCase {
    func testRejectsDifferentProtocolMajor() async throws {
        let launcher = FakeAdapterLauncher(readyVersion: 2)
        let supervisor = PluginSupervisor(protocolVersion: 1, launcher: launcher)
        await supervisor.start(.fixture)
        XCTAssertEqual(await supervisor.health(for: "fixture"), .incompatible)
    }
    func testBackoffStartsBelowFiveSeconds() {
        XCTAssertEqual(RestartBackoff().delay(forAttempt: 0), 0.25)
        XCTAssertLessThan(RestartBackoff().delay(forAttempt: 4), 5)
    }
}

private struct FakeAdapterLauncher: AdapterLaunching {
    let readyVersion: Int
    func launch(_ spec: AdapterProcessSpec, hello: PluginHello,
                onOutput: @escaping @Sendable (AdapterOutput) async -> Void,
                onTermination: @escaping @Sendable () async -> Void) async throws -> PluginReady {
        .init(protocolVersion: readyVersion, adapterId: spec.id, adapterVersion: "test",
              supportedSources: [.codex], capabilities: [], minimumToolVersions: [:])
    }
    func stop(id: String) async {}
}
```

- [ ] **Step 2: Verify supervisor types are missing**

Run: `swift test --filter PluginSupervisorTests`

Expected: FAIL with missing `PluginSupervisor` and `RestartBackoff`.

- [ ] **Step 3: Implement the launch boundary and state machine**

```swift
// Sources/PerchCore/Plugins/AdapterProcessSpec.swift
import Foundation
public struct AdapterProcessSpec: Sendable {
    public let id: String
    public let executable: URL
    public let arguments: [String]
    public init(id: String, executable: URL, arguments: [String]) {
        self.id = id; self.executable = executable; self.arguments = arguments
    }
}
public extension AdapterProcessSpec {
    static var fixture: Self { .init(id: "fixture", executable: URL(fileURLWithPath: "/usr/bin/true"), arguments: []) }
}
public enum AdapterHealth: Equatable, Sendable { case stopped, starting, healthy, degraded, incompatible }
```

```swift
// Sources/PerchCore/Plugins/RestartBackoff.swift
import Foundation
public struct RestartBackoff: Sendable {
    public init() {}
    public func delay(forAttempt attempt: Int) -> TimeInterval {
        min(4.0, 0.25 * pow(2.0, Double(max(0, attempt))))
    }
}
```

```swift
// Sources/PerchCore/Plugins/PluginSupervisor.swift
import PerchProtocol
public protocol AdapterLaunching: Sendable {
    func launch(_ spec: AdapterProcessSpec, hello: PluginHello,
                onOutput: @escaping @Sendable (AdapterOutput) async -> Void,
                onTermination: @escaping @Sendable () async -> Void) async throws -> PluginReady
    func stop(id: String) async
}
public actor PluginSupervisor {
    private let protocolVersion: Int
    private let launcher: AdapterLaunching
    private let onOutput: @Sendable (AdapterOutput) async -> Void
    private var healthByID: [String: AdapterHealth] = [:]
    public init(protocolVersion: Int, launcher: AdapterLaunching,
                onOutput: @escaping @Sendable (AdapterOutput) async -> Void = { _ in }) {
        self.protocolVersion = protocolVersion; self.launcher = launcher; self.onOutput = onOutput
    }
    public func start(_ spec: AdapterProcessSpec) async {
        await launch(spec, attempt: 0)
    }
    private func launch(_ spec: AdapterProcessSpec, attempt: Int) async {
        healthByID[spec.id] = .starting
        do {
            let ready = try await launcher.launch(spec,
                hello: .init(protocolVersion: protocolVersion, hostVersion: "0.1.0"),
                onOutput: onOutput,
                onTermination: { await self.adapterDidTerminate(spec, attempt: 0) })
            healthByID[spec.id] = ready.protocolVersion == protocolVersion ? .healthy : .incompatible
        } catch {
            healthByID[spec.id] = .degraded
            scheduleRestart(spec, attempt: attempt)
        }
    }
    public func health(for id: String) -> AdapterHealth { healthByID[id] ?? .stopped }
    public func adapterDidTerminate(_ spec: AdapterProcessSpec, attempt: Int) {
        healthByID[spec.id] = .degraded
        scheduleRestart(spec, attempt: attempt)
    }
    private func scheduleRestart(_ spec: AdapterProcessSpec, attempt: Int) {
        let delay = RestartBackoff().delay(forAttempt: attempt)
        Task {
            try? await Task.sleep(for: .seconds(delay))
            await self.launch(spec, attempt: attempt + 1)
        }
    }
}
```

- [ ] **Step 4: Run supervisor tests and Swift concurrency checks**

Run: `swift test --filter PluginSupervisorTests && swift build -Xswiftc -strict-concurrency=complete`

Expected: PASS with no concurrency errors.

- [ ] **Step 5: Commit process supervision**

```bash
git add Package.swift Sources/PerchCore/Plugins Tests/PerchCoreTests/PluginSupervisorTests.swift
git commit -m "feat: supervise built-in adapters"
```

---

### Task 6: Add the per-user Unix socket transport

**Files:**
- Modify: `Package.swift`
- Create: `Sources/PerchTransport/UnixSocketAddress.swift`
- Create: `Sources/PerchTransport/UnixSocketClient.swift`
- Create: `Sources/PerchTransport/UnixSocketServer.swift`
- Create: `Tests/PerchTransportTests/UnixSocketTransportTests.swift`

**Interfaces:**
- Produces: `UnixSocketAddress.make(adapterID:fileManager:)`, `UnixSocketClient.send(_:to:)`, and actor `UnixSocketServer.start(on:handler:)` / `stop()`.
- Consumes: NDJSON `Data` created by Task 2; does not decode vendor or Core models.

- [ ] **Step 1: Add transport targets and failing permission/round-trip tests**

Add to `Package.swift`:

```swift
.library(name: "PerchTransport", targets: ["PerchTransport"]),
// targets:
.target(name: "PerchTransport"),
.testTarget(name: "PerchTransportTests", dependencies: ["PerchTransport"]),
```

```swift
// Tests/PerchTransportTests/UnixSocketTransportTests.swift
import Darwin
import XCTest
@testable import PerchTransport

final class UnixSocketTransportTests: XCTestCase {
    func testAddressCreatesPrivateDirectory() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let address = try UnixSocketAddress.make(adapterID: "claude", baseDirectory: root)
        var statBuffer = stat()
        XCTAssertEqual(stat(root.path, &statBuffer), 0)
        XCTAssertEqual(statBuffer.st_mode & 0o777, 0o700)
        XCTAssertLessThan(address.path.utf8.count, 104)
    }

    func testClientServerRoundTrip() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let address = try UnixSocketAddress.make(adapterID: "codex", baseDirectory: root)
        let received = expectation(description: "frame")
        let server = UnixSocketServer(maxFrameBytes: 1_048_576)
        try await server.start(on: address) { data in
            XCTAssertEqual(String(decoding: data, as: UTF8.self), "{\"ok\":true}\n")
            received.fulfill()
        }
        try UnixSocketClient().send(Data("{\"ok\":true}\n".utf8), to: address)
        await fulfillment(of: [received], timeout: 1)
        await server.stop()
    }
}
```

- [ ] **Step 2: Verify transport symbols are missing**

Run: `swift test --filter UnixSocketTransportTests`

Expected: FAIL with missing `UnixSocketAddress` and `UnixSocketServer`.

- [ ] **Step 3: Implement private paths and bounded stream sockets**

```swift
// Sources/PerchTransport/UnixSocketAddress.swift
import Darwin
import Foundation
public struct UnixSocketAddress: Equatable, Sendable {
    public let path: String
    public init(path: String) { self.path = path }
    public static func make(adapterID: String,
                            baseDirectory: URL? = nil,
                            fileManager: FileManager = .default) throws -> Self {
        let root = baseDirectory ?? URL(fileURLWithPath: NSTemporaryDirectory()).appending(path: "perch-\(getuid())")
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true,
                                        attributes: [.posixPermissions: 0o700])
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path)
        let path = root.appending(path: "\(adapterID).sock").path
        guard path.utf8.count < MemoryLayout.size(ofValue: sockaddr_un().sun_path) else {
            throw POSIXError(.ENAMETOOLONG)
        }
        return .init(path: path)
    }
}
```

```swift
// Sources/PerchTransport/UnixSocketClient.swift
import Darwin
import Foundation

public struct UnixSocketClient: Sendable {
    public init() {}
    public func send(_ data: Data, to address: UnixSocketAddress) throws {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno)!) }
        defer { close(fd) }
        try withUnixSockAddr(path: address.path) { pointer, length in
            guard connect(fd, pointer, length) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno)!) }
        }
        try data.withUnsafeBytes { bytes in
            var offset = 0
            while offset < bytes.count {
                let count = write(fd, bytes.baseAddress!.advanced(by: offset), bytes.count - offset)
                guard count > 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno)!) }
                offset += count
            }
        }
    }
}

func withUnixSockAddr<T>(path: String,
                         _ body: (UnsafePointer<sockaddr>, socklen_t) throws -> T) throws -> T {
    var address = sockaddr_un()
    address.sun_family = sa_family_t(AF_UNIX)
    let bytes = Array(path.utf8CString)
    withUnsafeMutableBytes(of: &address.sun_path) { raw in raw.copyBytes(from: bytes) }
    let length = socklen_t(MemoryLayout<sa_family_t>.size + bytes.count)
    return try withUnsafePointer(to: &address) {
        try $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { try body($0, length) }
    }
}
```

```swift
// Sources/PerchTransport/UnixSocketServer.swift
import Darwin
import Foundation

public actor UnixSocketServer {
    private let maxFrameBytes: Int
    private var descriptor: Int32 = -1
    private var source: DispatchSourceRead?
    public init(maxFrameBytes: Int) { self.maxFrameBytes = maxFrameBytes }

    public func start(on address: UnixSocketAddress,
                      handler: @escaping @Sendable (Data) -> Void) throws {
        unlink(address.path)
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno)!) }
        try withUnixSockAddr(path: address.path) { pointer, length in
            guard bind(fd, pointer, length) == 0, listen(fd, 16) == 0 else {
                close(fd); throw POSIXError(POSIXErrorCode(rawValue: errno)!)
            }
        }
        chmod(address.path, 0o600)
        descriptor = fd
        let readSource = DispatchSource.makeReadSource(fileDescriptor: fd, queue: .global(qos: .utility))
        readSource.setEventHandler { [maxFrameBytes] in
            let client = accept(fd, nil, nil)
            guard client >= 0 else { return }
            defer { close(client) }
            var frame = Data(); var chunk = [UInt8](repeating: 0, count: 4_096)
            while true {
                let count = read(client, &chunk, chunk.count)
                guard count >= 0 else { return }
                if count == 0 { break }
                frame.append(contentsOf: chunk.prefix(count))
                guard frame.count <= maxFrameBytes else { return }
                if let newline = frame.firstIndex(of: 0x0A) {
                    frame = Data(frame.prefix(through: newline))
                    break
                }
            }
            guard !frame.isEmpty else { return }
            handler(frame)
        }
        readSource.setCancelHandler { close(fd) }
        source = readSource
        readSource.resume()
    }

    public func stop() {
        source?.cancel(); source = nil; descriptor = -1
    }
}
```

- [ ] **Step 4: Run transport tests repeatedly to expose races**

Run: `for i in {1..20}; do swift test --filter UnixSocketTransportTests || exit 1; done`

Expected: all 20 runs PASS; the socket directory remains `0700` and each socket `0600`.

- [ ] **Step 5: Commit the transport**

```bash
git add Package.swift Sources/PerchTransport Tests/PerchTransportTests
git commit -m "feat: add private Unix socket transport"
```

---

### Task 7: Build the shared adapter runtime and fail-open hook emitter

**Files:**
- Modify: `Package.swift`
- Create: `Sources/AdapterSupport/AdapterCommand.swift`
- Create: `Sources/AdapterSupport/AdapterRuntime.swift`
- Create: `Sources/AdapterSupport/AdapterOutputWriter.swift`
- Create: `Sources/AdapterSupport/HookEmitter.swift`
- Create: `Sources/AdapterSupport/Sanitizer.swift`
- Create: `Tests/AdapterSupportTests/SanitizerTests.swift`
- Create: `Tests/AdapterSupportTests/HookEmitterTests.swift`

**Interfaces:**
- Consumes: `EventEnvelope`, `NDJSONCodec`, `UnixSocketAddress`, `UnixSocketClient`, and `UnixSocketServer`.
- Produces: `AdapterCommand`, `Sanitizer.sanitize(_:allowing:)`, `HookEmitter.emit(stdin:to:)`, and `AdapterRuntime.run(mapper:)`.

- [ ] **Step 1: Add targets and failing sanitizer/emitter tests**

Add to `Package.swift`:

```swift
.library(name: "AdapterSupport", targets: ["AdapterSupport"]),
// targets:
.target(name: "AdapterSupport", dependencies: ["PerchProtocol", "PerchTransport"]),
.testTarget(name: "AdapterSupportTests", dependencies: ["AdapterSupport"]),
```

```swift
// Tests/AdapterSupportTests/SanitizerTests.swift
import XCTest
@testable import AdapterSupport

final class SanitizerTests: XCTestCase {
    func testKeepsOnlyAllowedKeysAndRedactsAbsolutePaths() throws {
        let input: [String: Any] = ["session_id": "s", "cwd": "/Users/me/secret", "prompt": "token"]
        let output = Sanitizer.sanitize(input, allowing: ["session_id", "cwd"])
        XCTAssertEqual(output["session_id"] as? String, "s")
        XCTAssertEqual(output["cwd"] as? String, "secret")
        XCTAssertNil(output["prompt"])
    }
}
```

```swift
// Tests/AdapterSupportTests/HookEmitterTests.swift
import XCTest
@testable import AdapterSupport

final class HookEmitterTests: XCTestCase {
    func testConnectionFailureIsReportedWithoutThrowingFromFailOpenEntryPoint() {
        let result = HookEmitter.emitFailOpen(stdin: Data("{}".utf8),
                                              socketPath: "/tmp/does-not-exist/perch.sock")
        XCTAssertEqual(result, .deliverySkipped)
    }
}
```

- [ ] **Step 2: Verify shared runtime symbols are missing**

Run: `swift test --filter AdapterSupportTests`

Expected: FAIL with missing `Sanitizer` and `HookEmitter`.

- [ ] **Step 3: Implement allow-list sanitization and fail-open delivery**

```swift
// Sources/AdapterSupport/AdapterCommand.swift
public enum AdapterCommand: Equatable { case serve, emit, notify }
public extension AdapterCommand {
    static func parse(_ arguments: [String]) -> Self? {
        switch arguments.dropFirst().first {
        case "serve": .serve
        case "emit": .emit
        case "notify": .notify
        default: nil
        }
    }
}
```

```swift
// Sources/AdapterSupport/Sanitizer.swift
import Foundation
public enum Sanitizer {
    public static func sanitize(_ input: [String: Any], allowing keys: Set<String>) -> [String: Any] {
        input.reduce(into: [:]) { result, item in
            guard keys.contains(item.key) else { return }
            if item.key == "cwd", let path = item.value as? String {
                result[item.key] = URL(fileURLWithPath: path).lastPathComponent
            } else { result[item.key] = item.value }
        }
    }
}
```

```swift
// Sources/AdapterSupport/HookEmitter.swift
import Foundation
import PerchTransport
public enum HookEmitResult: Equatable { case delivered, deliverySkipped }
public enum HookEmitter {
    public static func emitFailOpen(stdin: Data, socketPath: String) -> HookEmitResult {
        do {
            try UnixSocketClient().send(stdin + Data("\n".utf8), to: .init(path: socketPath))
            return .delivered
        } catch { return .deliverySkipped }
    }
}
```

```swift
// Sources/AdapterSupport/AdapterOutputWriter.swift
import Foundation
import PerchProtocol
public actor AdapterOutputWriter {
    public init() {}
    public func write<T: Encodable>(_ output: T) {
        guard let line = try? NDJSONCodec.encode(output) else { return }
        FileHandle.standardOutput.write(Data(line.utf8))
    }
}
```

```swift
// Sources/AdapterSupport/AdapterRuntime.swift
import Foundation
import PerchProtocol
import PerchTransport

public struct AdapterRuntime: Sendable {
    public let address: UnixSocketAddress
    public let writer: AdapterOutputWriter
    public init(address: UnixSocketAddress, writer: AdapterOutputWriter) {
        self.address = address; self.writer = writer
    }
    public func run(ready: PluginReady,
                    mapper: @escaping @Sendable (Data) throws -> [AdapterOutput]) async throws {
        let helloLine = try Self.readLine(from: .standardInput)
        let hello = try NDJSONCodec.decode(PluginHello.self, from: helloLine)
        guard hello.protocolVersion == ready.protocolVersion else { return }
        await writer.write(ready)
        let server = UnixSocketServer(maxFrameBytes: 1_048_576)
        try await server.start(on: address) { data in
            guard let events = try? mapper(data) else { return }
            for output in events {
                Task { await writer.write(output) }
            }
        }
        _ = await Task.detached {
            FileHandle.standardInput.readDataToEndOfFile()
        }.value
        await server.stop()
    }
    private static func readLine(from handle: FileHandle) throws -> String {
        var data = Data()
        while let byte = try handle.read(upToCount: 1), !byte.isEmpty {
            if byte == Data("\n".utf8) { return String(decoding: data, as: UTF8.self) }
            data.append(byte)
        }
        throw CocoaError(.fileReadUnexpectedFileSize)
    }
}
```

- [ ] **Step 4: Run shared adapter tests and time fail-open delivery**

Run: `swift test --filter AdapterSupportTests && /usr/bin/time -p swift test --filter HookEmitterTests`

Expected: PASS; `HookEmitter` returns `deliverySkipped` instead of throwing. The test command's startup time is not the bridge target; bridge timing is measured from a release binary in Task 14.

- [ ] **Step 5: Commit shared adapter support**

```bash
git add Package.swift Sources/AdapterSupport Tests/AdapterSupportTests
git commit -m "feat: add adapter runtime and fail-open emitter"
```

---

### Task 8: Implement the Claude Code adapter

**Files:**
- Modify: `Package.swift`
- Create: `Sources/ClaudeAdapter/ClaudeAdapterMain.swift`
- Create: `Sources/ClaudeAdapter/ClaudeEventMapper.swift`
- Create: `Tests/ClaudeAdapterTests/ClaudeEventMapperTests.swift`
- Create: `Tests/ClaudeAdapterTests/Fixtures/session-start.json`
- Create: `Tests/ClaudeAdapterTests/Fixtures/permission-request.json`
- Create: `Tests/ClaudeAdapterTests/Fixtures/stop.json`
- Create: `Tests/ClaudeAdapterTests/Fixtures/stop-failure.json`

**Interfaces:**
- Consumes: `AdapterRuntime`, `HookEmitter`, `Sanitizer`, and protocol event types.
- Produces: executable `perch-adapter-claude` and `ClaudeEventMapper.map(_:) -> [EventEnvelope]`.

- [ ] **Step 1: Add the executable/test targets and fixture-driven failing tests**

Add the executable product to `products` and the executable/test targets to `targets`:

```swift
.executable(name: "perch-adapter-claude", targets: ["ClaudeAdapter"]), // products
.executableTarget(name: "ClaudeAdapter", dependencies: ["AdapterSupport", "PerchProtocol", "PerchTransport"]),
.testTarget(name: "ClaudeAdapterTests", dependencies: ["ClaudeAdapter"], resources: [.copy("Fixtures")]),
```

```swift
// Tests/ClaudeAdapterTests/ClaudeEventMapperTests.swift
import XCTest
import PerchProtocol
@testable import ClaudeAdapter

final class ClaudeEventMapperTests: XCTestCase {
    func testPermissionBecomesAttentionWithoutToolInput() throws {
        let event = try XCTUnwrap(ClaudeEventMapper.map(fixture("permission-request")).first)
        XCTAssertEqual(event.type, .attentionRequired)
        XCTAssertNil(event.payload["tool_input"])
    }
    func testStopAndFailureMapToDifferentTerminals() throws {
        XCTAssertEqual(try XCTUnwrap(ClaudeEventMapper.map(fixture("stop")).first).type, .turnCompleted)
        XCTAssertEqual(try XCTUnwrap(ClaudeEventMapper.map(fixture("stop-failure")).first).type, .turnFailed)
    }
    private func fixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }
}
```

```json
// Tests/ClaudeAdapterTests/Fixtures/session-start.json
{"session_id":"claude-s1","hook_event_name":"SessionStart","cwd":"/Users/test/perch"}
```

```json
// Tests/ClaudeAdapterTests/Fixtures/permission-request.json
{"session_id":"claude-s1","hook_event_name":"PermissionRequest","cwd":"/Users/test/perch","tool_name":"Bash","tool_input":{"command":"cat /Users/test/secret"}}
```

```json
// Tests/ClaudeAdapterTests/Fixtures/stop.json
{"session_id":"claude-s1","hook_event_name":"Stop","cwd":"/Users/test/perch","last_assistant_message":"private output"}
```

```json
// Tests/ClaudeAdapterTests/Fixtures/stop-failure.json
{"session_id":"claude-s1","hook_event_name":"StopFailure","cwd":"/Users/test/perch","error":"rate_limit","last_assistant_message":"private error"}
```

- [ ] **Step 2: Verify Claude mapper is missing**

Run: `swift test --filter ClaudeEventMapperTests`

Expected: FAIL with missing `ClaudeEventMapper`.

- [ ] **Step 3: Implement explicit hook mappings and the adapter CLI**

```swift
// Sources/ClaudeAdapter/ClaudeEventMapper.swift
import Foundation
import PerchProtocol

public enum ClaudeEventMapper {
    public static func map(_ data: Data) throws -> [EventEnvelope] {
        let raw = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        guard let session = raw["session_id"] as? String,
              let hook = raw["hook_event_name"] as? String else { return [] }
        let type: EventType
        switch hook {
        case "SessionStart": type = .sessionStarted
        case "UserPromptSubmit": type = .turnStarted
        case "PermissionRequest", "Notification": type = .attentionRequired
        case "Stop": type = .turnCompleted
        case "StopFailure": type = .turnFailed
        case "SessionEnd": type = .sessionEnded
        case "TaskCreated", "TaskCompleted": type = .taskChanged
        default: type = .activityChanged
        }
        let payload: [String: JSONValue] = [
            "project": .string(URL(fileURLWithPath: raw["cwd"] as? String ?? "").lastPathComponent),
            "activity": .string(raw["tool_name"] as? String ?? hook),
        ]
        return [.init(eventId: raw["hook_id"] as? String ?? UUID().uuidString,
                      emittedAt: .now, source: .claude, surface: .cli,
                      sessionId: session, turnId: raw["turn_id"] as? String,
                      taskId: raw["task_id"] as? String, type: type, payload: payload)]
    }
}
```

```swift
// Sources/ClaudeAdapter/ClaudeAdapterMain.swift
import AdapterSupport
import Foundation
import PerchTransport

@main enum ClaudeAdapterMain {
    static func main() async {
        let address = try! UnixSocketAddress.make(adapterID: "claude")
        let writer = AdapterOutputWriter()
        switch AdapterCommand.parse(CommandLine.arguments) {
        case .emit:
            _ = HookEmitter.emitFailOpen(stdin: FileHandle.standardInput.readDataToEndOfFile(), socketPath: address.path)
        case .serve:
            let ready = PluginReady(protocolVersion: 1, adapterId: "claude", adapterVersion: "0.1.0",
                supportedSources: [.claude],
                capabilities: [.taskTree, .toolActivity, .approvalAttention, .accountUsage, .deepLink],
                minimumToolVersions: [:])
            try? await AdapterRuntime(address: address, writer: writer).run(ready: ready) { data in
                try ClaudeEventMapper.map(data).map(AdapterOutput.event)
            }
        case .notify:
            break
        case nil: break
        }
    }
}
```

- [ ] **Step 4: Run all Claude fixtures and confirm no prompt/path leakage**

Run: `swift test --filter ClaudeAdapterTests && swift test`

Expected: PASS; searching encoded mapped events for fixture prompt text or `/Users/` returns no matches.

- [ ] **Step 5: Commit the Claude adapter**

```bash
git add Package.swift Sources/ClaudeAdapter Tests/ClaudeAdapterTests
git commit -m "feat: monitor Claude Code hooks"
```

---

### Task 9: Implement the Codex CLI/Desktop adapter

**Files:**
- Modify: `Package.swift`
- Create: `Sources/CodexAdapter/CodexAdapterMain.swift`
- Create: `Sources/CodexAdapter/CodexEventMapper.swift`
- Create: `Tests/CodexAdapterTests/CodexEventMapperTests.swift`
- Create: `Tests/CodexAdapterTests/Fixtures/permission-request.json`
- Create: `Tests/CodexAdapterTests/Fixtures/stop.json`
- Create: `Tests/CodexAdapterTests/Fixtures/notify-complete.json`

**Interfaces:**
- Consumes: shared adapter runtime and protocol types.
- Produces: executable `perch-adapter-codex` and `CodexEventMapper.map(_:surfaceHint:)`.

- [ ] **Step 1: Add targets and failing source-precision tests**

Add the executable product to `products` and the executable/test targets to `targets`:

```swift
.executable(name: "perch-adapter-codex", targets: ["CodexAdapter"]), // products
.executableTarget(name: "CodexAdapter", dependencies: ["AdapterSupport", "PerchProtocol", "PerchTransport"]),
.testTarget(name: "CodexAdapterTests", dependencies: ["CodexAdapter"], resources: [.copy("Fixtures")]),
```

```swift
// Tests/CodexAdapterTests/CodexEventMapperTests.swift
import XCTest
import PerchProtocol
@testable import CodexAdapter

final class CodexEventMapperTests: XCTestCase {
    func testDoesNotGuessDesktopOrCLI() throws {
        let event = try XCTUnwrap(CodexEventMapper.map(fixture("stop"), surfaceHint: nil).first)
        XCTAssertEqual(event.surface, .unknown)
    }
    func testExplicitSurfaceHintIsPreserved() throws {
        let event = try XCTUnwrap(CodexEventMapper.map(fixture("stop"), surfaceHint: .desktop).first)
        XCTAssertEqual(event.surface, .desktop)
    }
    func testNotifyFallbackCompletesTurn() throws {
        XCTAssertEqual(try XCTUnwrap(CodexEventMapper.map(fixture("notify-complete"), surfaceHint: nil).first).type,
                       .turnCompleted)
    }
    private func fixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }
}
```

```json
// Tests/CodexAdapterTests/Fixtures/permission-request.json
{"session_id":"codex-s1","hook_event_name":"PermissionRequest","tool_name":"Bash","tool_input":{"command":"cat /Users/test/secret"}}
```

```json
// Tests/CodexAdapterTests/Fixtures/stop.json
{"session_id":"codex-s1","hook_event_name":"Stop","last-assistant-message":"private output"}
```

```json
// Tests/CodexAdapterTests/Fixtures/notify-complete.json
{"thread-id":"codex-s1","type":"agent-turn-complete","last-assistant-message":"private output"}
```

- [ ] **Step 2: Verify Codex mapper is missing**

Run: `swift test --filter CodexEventMapperTests`

Expected: FAIL with missing `CodexEventMapper`.

- [ ] **Step 3: Implement hooks/notify mapping without app-server thread observation**

```swift
// Sources/CodexAdapter/CodexEventMapper.swift
import Foundation
import PerchProtocol

public enum CodexEventMapper {
    public static func map(_ data: Data, surfaceHint: EventSurface?) throws -> [EventEnvelope] {
        let raw = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let hook = raw["hook_event_name"] as? String ?? raw["type"] as? String ?? ""
        guard let session = raw["session_id"] as? String ?? raw["thread-id"] as? String else { return [] }
        let type: EventType
        switch hook {
        case "SessionStart": type = .sessionStarted
        case "UserPromptSubmit": type = .turnStarted
        case "PermissionRequest": type = .attentionRequired
        case "Stop", "agent-turn-complete": type = .turnCompleted
        case "SessionEnd": type = .sessionEnded
        default: type = .activityChanged
        }
        return [.init(eventId: raw["event_id"] as? String ?? UUID().uuidString,
                      emittedAt: .now, source: .codex, surface: surfaceHint ?? .unknown,
                      sessionId: session, turnId: raw["turn_id"] as? String,
                      taskId: nil, type: type,
                      payload: [
                        "activity": .string(raw["tool_name"] as? String ?? hook),
                        "project": .string(URL(fileURLWithPath:
                            raw["cwd"] as? String ?? raw["working-directory"] as? String ?? "").lastPathComponent)
                      ])]
    }
}
```

```swift
// Sources/CodexAdapter/CodexAdapterMain.swift
import AdapterSupport
import Foundation
import PerchProtocol
import PerchTransport

@main enum CodexAdapterMain {
    static func main() async {
        let address = try! UnixSocketAddress.make(adapterID: "codex")
        let writer = AdapterOutputWriter()
        let hint: EventSurface? = switch ProcessInfo.processInfo.environment["PERCH_CODEX_SURFACE"] {
        case "cli": .cli
        case "desktop": .desktop
        default: nil
        }
        switch AdapterCommand.parse(CommandLine.arguments) {
        case .emit:
            _ = HookEmitter.emitFailOpen(stdin: FileHandle.standardInput.readDataToEndOfFile(), socketPath: address.path)
        case .serve:
            let ready = PluginReady(protocolVersion: 1, adapterId: "codex", adapterVersion: "0.1.0",
                supportedSources: [.codex],
                capabilities: [.toolActivity, .approvalAttention, .accountUsage, .deepLink],
                minimumToolVersions: [:])
            try? await AdapterRuntime(address: address, writer: writer).run(ready: ready) {
                try CodexEventMapper.map($0, surfaceHint: hint).map(AdapterOutput.event)
            }
        case .notify:
            let argument = CommandLine.arguments.dropFirst(2).first ?? "{}"
            _ = HookEmitter.emitFailOpen(stdin: Data(argument.utf8), socketPath: address.path)
        case nil: break
        }
    }
}
```

- [ ] **Step 4: Run fixtures and assert no private message text survives**

Run: `swift test --filter CodexAdapterTests && swift test`

Expected: PASS; `last-assistant-message`, full command input, and absolute fixture paths are absent from mapped payloads.

- [ ] **Step 5: Commit the Codex adapter**

```bash
git add Package.swift Sources/CodexAdapter Tests/CodexAdapterTests
git commit -m "feat: monitor Codex lifecycle events"
```

---

### Task 10: Add Claude and Codex subscription usage providers

**Files:**
- Modify: `Package.swift`
- Create: `Sources/ClaudeAdapter/ClaudeUsageMapper.swift`
- Create: `Sources/CodexAdapter/CodexRateLimitClient.swift`
- Create: `Sources/CodexAdapter/CodexAppServerTransport.swift`
- Modify: `Sources/ClaudeAdapter/ClaudeAdapterMain.swift`
- Modify: `Sources/CodexAdapter/CodexAdapterMain.swift`
- Create: `Sources/PerchCore/Usage/UsageCenter.swift`
- Create: `Sources/PerchCore/Usage/UsageAlertPolicy.swift`
- Create: `Sources/PerchStatusLineTap/StatusLineTapMain.swift`
- Create: `Sources/PerchStatusLineTap/PassthroughCommand.swift`
- Create: `Tests/ClaudeAdapterTests/ClaudeUsageMapperTests.swift`
- Create: `Tests/CodexAdapterTests/CodexRateLimitClientTests.swift`
- Create: `Tests/PerchCoreTests/UsageCenterTests.swift`
- Create: `Tests/PerchCoreTests/UsageAlertPolicyTests.swift`
- Create: `Tests/PerchStatusLineTapTests/PassthroughCommandTests.swift`

**Interfaces:**
- Consumes: `UsageSnapshot`, `UsageWindow`, and adapter transport.
- Produces: `ClaudeUsageMapper.map(_:)`, protocol `CodexJSONRPCTransport`, `CodexRateLimitClient.read()`, actor `UsageCenter`, opt-in `UsageAlertPolicy`, and executable `perch-statusline-tap`.

- [ ] **Step 1: Add the status-line target and failing provider tests**

Add the executable product to `products` and the executable/test targets to `targets`:

```swift
.executable(name: "perch-statusline-tap", targets: ["PerchStatusLineTap"]), // products
.executableTarget(name: "PerchStatusLineTap", dependencies: ["PerchProtocol", "PerchTransport"]),
.testTarget(name: "PerchStatusLineTapTests", dependencies: ["PerchStatusLineTap"]),
```

```swift
// Tests/ClaudeAdapterTests/ClaudeUsageMapperTests.swift
func testMapsFiveHourAndSevenDayWindows() throws {
    let data = Data(#"{"rate_limits":{"five_hour":{"used_percentage":42,"resets_at":1738425600},"seven_day":{"used_percentage":68,"resets_at":1738857600}}}"#.utf8)
    let snapshot = try XCTUnwrap(ClaudeUsageMapper.map(data))
    XCTAssertEqual(snapshot.windows.map(\.kind), ["five_hour", "seven_day"])
    XCTAssertEqual(snapshot.windows.map(\.usedPercentage), [42, 68])
}
```

```swift
// Tests/CodexAdapterTests/CodexRateLimitClientTests.swift
import XCTest
import PerchProtocol
@testable import CodexAdapter

final class CodexRateLimitClientTests: XCTestCase {
    func testUsesReadMethodAndNeverResetMethod() async throws {
        let response: JSONValue = .object(["rateLimits": .object([
            "primary": .object(["usedPercent": .number(42), "windowDurationMins": .number(300), "resetsAt": .number(1_738_425_600)]),
            "secondary": .object(["usedPercent": .number(68), "windowDurationMins": .number(10_080), "resetsAt": .number(1_738_857_600)])
        ])])
        let transport = FakeJSONRPCTransport(response: response)
        let snapshot = try await CodexRateLimitClient(transport: transport).read()
        XCTAssertEqual(await transport.methods, ["account/rateLimits/read"])
        XCTAssertEqual(snapshot.windows.map(\.usedPercentage), [42, 68])
    }
}
private actor FakeJSONRPCTransport: CodexJSONRPCTransport {
    let response: JSONValue
    var methods: [String] = []
    init(response: JSONValue) { self.response = response }
    func request(method: String, params: [String: JSONValue]) async throws -> JSONValue {
        methods.append(method); return response
    }
}
```

```swift
// Tests/PerchCoreTests/UsageCenterTests.swift
func testExpiredSnapshotBecomesStale() async {
    let center = UsageCenter(staleAfter: 60)
    await center.update(.init(provider: .claude,
                              windows: [.init(kind: "five_hour", usedPercentage: 42, resetsAt: nil)],
                              fetchedAt: Date(timeIntervalSince1970: 0), freshness: .live))
    XCTAssertEqual(await center.snapshot(for: .claude, now: Date(timeIntervalSince1970: 61))?.freshness, .stale)
}
```

```swift
// Tests/PerchCoreTests/UsageAlertPolicyTests.swift
import XCTest
import PerchProtocol
@testable import PerchCore

final class UsageAlertPolicyTests: XCTestCase {
    func testAlertsAreDisabledByDefault() {
        var policy = UsageAlertPolicy()
        let snapshot = UsageSnapshot(provider: .claude,
            windows: [.init(kind: "five_hour", usedPercentage: 99, resetsAt: nil)],
            fetchedAt: .now, freshness: .live)
        XCTAssertTrue(policy.crossings(in: snapshot).isEmpty)
    }
    func testEnabledPolicyReportsConfiguredThresholdOncePerWindow() {
        var policy = UsageAlertPolicy(enabled: true, thresholds: [80, 95])
        let snapshot = UsageSnapshot(provider: .codex,
            windows: [.init(kind: "300m", usedPercentage: 96, resetsAt: nil)],
            fetchedAt: .now, freshness: .live)
        XCTAssertEqual(policy.crossings(in: snapshot), [80, 95])
        XCTAssertTrue(policy.crossings(in: snapshot).isEmpty)
    }
}
```

```swift
// Tests/PerchStatusLineTapTests/PassthroughCommandTests.swift
import XCTest
@testable import PerchStatusLineTap

final class PassthroughCommandTests: XCTestCase {
    func testPreservesStdinStdoutStderrAndStatus() throws {
        let result = try PassthroughCommand.execute(
            command: "cat; printf error >&2; exit 7", stdin: Data("input\n".utf8))
        XCTAssertEqual(result.stdout, Data("input\n".utf8))
        XCTAssertEqual(result.stderr, Data("error".utf8))
        XCTAssertEqual(result.status, 7)
    }
}
```

- [ ] **Step 2: Verify provider symbols are missing**

Run: `swift test --filter 'ClaudeUsageMapperTests|CodexRateLimitClientTests|UsageCenterTests|UsageAlertPolicyTests'`

Expected: FAIL with missing usage provider types.

- [ ] **Step 3: Implement usage mapping, read-only JSON-RPC, memory freshness, and passthrough**

```swift
// Sources/ClaudeAdapter/ClaudeUsageMapper.swift
import Foundation
import PerchProtocol
public enum ClaudeUsageMapper {
    public static func map(_ data: Data) throws -> UsageSnapshot? {
        let raw = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let limits = raw?["rate_limits"] as? [String: [String: Any]] ?? [:]
        let windows = ["five_hour", "seven_day"].compactMap { key -> UsageWindow? in
            guard let value = limits[key], let used = value["used_percentage"] as? Double else { return nil }
            let reset = (value["resets_at"] as? TimeInterval).map(Date.init(timeIntervalSince1970:))
            return .init(kind: key, usedPercentage: used, resetsAt: reset)
        }
        guard !windows.isEmpty else { return nil }
        return .init(provider: .claude, windows: windows, fetchedAt: .now, freshness: .live)
    }
}
```

```swift
// Sources/CodexAdapter/CodexRateLimitClient.swift
import PerchProtocol
public protocol CodexJSONRPCTransport: Sendable {
    func request(method: String, params: [String: JSONValue]) async throws -> JSONValue
}
public struct CodexRateLimitClient<T: CodexJSONRPCTransport>: Sendable {
    let transport: T
    public init(transport: T) { self.transport = transport }
    public func read() async throws -> UsageSnapshot {
        let value = try await transport.request(method: "account/rateLimits/read", params: [:])
        return try CodexRateLimitDecoder.decode(value)
    }
}

public enum CodexRateLimitDecoder {
    public static func decode(_ value: JSONValue) throws -> UsageSnapshot {
        guard case .object(let root) = value,
              case .object(let limits)? = root["rateLimits"] else { throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "rateLimits missing")) }
        let windows = ["primary", "secondary"].compactMap { name -> UsageWindow? in
            guard case .object(let window)? = limits[name],
                  case .number(let used)? = window["usedPercent"] else { return nil }
            let minutes: Double? = { if case .number(let value)? = window["windowDurationMins"] { value } else { nil } }()
            let reset: Date? = { if case .number(let value)? = window["resetsAt"] { Date(timeIntervalSince1970: value) } else { nil } }()
            return .init(kind: minutes.map { "\(Int($0))m" } ?? name,
                         usedPercentage: used, resetsAt: reset)
        }
        return .init(provider: .codex, windows: windows, fetchedAt: .now, freshness: .live)
    }
}
```

```swift
// Sources/PerchCore/Usage/UsageCenter.swift
import Foundation
import PerchProtocol
public actor UsageCenter {
    private let staleAfter: TimeInterval
    private var values: [UsageProvider: UsageSnapshot] = [:]
    private var alertPolicy = UsageAlertPolicy()
    public init(staleAfter: TimeInterval = 60) { self.staleAfter = staleAfter }
    @discardableResult public func update(_ value: UsageSnapshot,
                                          alertsEnabled: Bool = false) -> [Int] {
        values[value.provider] = value
        alertPolicy.enabled = alertsEnabled
        return alertPolicy.crossings(in: value)
    }
    public func snapshot(for provider: UsageProvider, now: Date = .now) -> UsageSnapshot? {
        guard let value = values[provider] else { return nil }
        guard now.timeIntervalSince(value.fetchedAt) > staleAfter else { return value }
        return .init(provider: value.provider, windows: value.windows,
                     fetchedAt: value.fetchedAt, freshness: .stale)
    }
}
```

```swift
// Sources/PerchCore/Usage/UsageAlertPolicy.swift
import PerchProtocol
public struct UsageAlertPolicy: Sendable {
    public var enabled: Bool
    public var thresholds: [Int]
    private var delivered: Set<String> = []
    public init(enabled: Bool = false, thresholds: [Int] = [80, 95]) {
        self.enabled = enabled; self.thresholds = thresholds.sorted()
    }
    public mutating func crossings(in snapshot: UsageSnapshot) -> [Int] {
        guard enabled, snapshot.freshness == .live else { return [] }
        var result: [Int] = []
        for window in snapshot.windows {
            for threshold in thresholds where window.usedPercentage >= Double(threshold) {
                let reset = window.resetsAt?.timeIntervalSince1970 ?? 0
                let key = "\(snapshot.provider.rawValue):\(window.kind):\(threshold):\(reset)"
                if delivered.insert(key).inserted { result.append(threshold) }
            }
        }
        return result
    }
}
```

```swift
// Sources/PerchStatusLineTap/PassthroughCommand.swift
import Foundation
public struct PassthroughResult { public let stdout: Data; public let stderr: Data; public let status: Int32 }
public enum PassthroughCommand {
    public static func execute(command: String, stdin: Data) throws -> PassthroughResult {
        let process = Process(); let input = Pipe()
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let stdoutURL = root.appending(path: "stdout"); let stderrURL = root.appending(path: "stderr")
        FileManager.default.createFile(atPath: stdoutURL.path, contents: nil)
        FileManager.default.createFile(atPath: stderrURL.path, contents: nil)
        let stdout = try FileHandle(forWritingTo: stdoutURL)
        let stderr = try FileHandle(forWritingTo: stderrURL)
        defer { try? stdout.close(); try? stderr.close() }
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", command]
        process.standardInput = input; process.standardOutput = stdout; process.standardError = stderr
        try process.run()
        input.fileHandleForWriting.write(stdin); try input.fileHandleForWriting.close()
        process.waitUntilExit()
        try stdout.synchronize(); try stderr.synchronize()
        return .init(stdout: try Data(contentsOf: stdoutURL),
                     stderr: try Data(contentsOf: stderrURL),
                     status: process.terminationStatus)
    }
}
```

```swift
// Sources/PerchStatusLineTap/StatusLineTapMain.swift
import Darwin
import Foundation
import PerchTransport

@main enum StatusLineTapMain {
    static func main() {
        let stdin = FileHandle.standardInput.readDataToEndOfFile()
        if let address = try? UnixSocketAddress.make(adapterID: "claude") {
            try? UnixSocketClient().send(stdin + Data("\n".utf8), to: address)
        }
        guard let index = CommandLine.arguments.firstIndex(of: "--original-base64"),
              CommandLine.arguments.indices.contains(index + 1),
              let bytes = Data(base64Encoded: CommandLine.arguments[index + 1]),
              let command = String(data: bytes, encoding: .utf8), !command.isEmpty,
              let result = try? PassthroughCommand.execute(command: command, stdin: stdin) else { exit(0) }
        FileHandle.standardOutput.write(result.stdout)
        FileHandle.standardError.write(result.stderr)
        exit(result.status)
    }
}
```

```swift
// Sources/CodexAdapter/CodexAppServerTransport.swift
import Foundation
import PerchProtocol

public final class CodexAppServerTransport: CodexJSONRPCTransport, @unchecked Sendable {
    private let executable: URL
    public init(executable: URL) { self.executable = executable }
    public func request(method: String, params: [String: JSONValue]) async throws -> JSONValue {
        let process = Process(); let input = Pipe(); let output = Pipe()
        process.executableURL = executable; process.arguments = ["app-server", "--listen", "stdio://"]
        process.standardInput = input; process.standardOutput = output; process.standardError = FileHandle.nullDevice
        try process.run(); defer { process.terminate() }
        try send(["id": 0, "method": "initialize", "params": ["clientInfo": ["name": "perch", "title": "Perch", "version": "0.1.0"]]], to: input)
        _ = try readMessage(id: 0, from: output)
        try send(["method": "initialized", "params": [:]], to: input)
        let paramsData = try JSONEncoder().encode(params)
        let paramsObject = try JSONSerialization.jsonObject(with: paramsData)
        try send(["id": 1, "method": method, "params": paramsObject], to: input)
        let response = try readMessage(id: 1, from: output)
        let resultData = try JSONSerialization.data(withJSONObject: response["result"] as Any)
        return try JSONDecoder().decode(JSONValue.self, from: resultData)
    }
    private func send(_ object: [String: Any], to pipe: Pipe) throws {
        let data = try JSONSerialization.data(withJSONObject: object) + Data("\n".utf8)
        pipe.fileHandleForWriting.write(data)
    }
    private func readMessage(id: Int, from pipe: Pipe) throws -> [String: Any] {
        var line = Data()
        while true {
            guard let byte = try pipe.fileHandleForReading.read(upToCount: 1), !byte.isEmpty else {
                throw CocoaError(.fileReadUnexpectedFileSize)
            }
            if byte == Data("\n".utf8) {
                let value = try JSONSerialization.jsonObject(with: line) as! [String: Any]
                if value["id"] as? Int == id { return value }
                line.removeAll(keepingCapacity: true)
            } else { line.append(byte) }
        }
    }
}
```

Modify the Claude `.serve` branch so the same socket accepts both Hook and Status Line payloads:

```swift
try? await AdapterRuntime(address: address, writer: writer).run(ready: ready) { data in
    if let usage = try ClaudeUsageMapper.map(data) { return [.usage(usage)] }
    return try ClaudeEventMapper.map(data).map(AdapterOutput.event)
}
```

Modify the Codex `.serve` branch to poll the account-only App Server method without observing threads:

```swift
let quotaTask = Task {
    let codex = URL(fileURLWithPath: ProcessInfo.processInfo.environment["PERCH_CODEX_EXECUTABLE"] ?? "/Applications/Codex.app/Contents/Resources/codex")
    let client = CodexRateLimitClient(transport: CodexAppServerTransport(executable: codex))
    while !Task.isCancelled {
        if let usage = try? await client.read() { await writer.write(.usage(usage)) }
        try? await Task.sleep(for: .seconds(60))
    }
}
try? await AdapterRuntime(address: address, writer: writer).run(ready: ready) {
    try CodexEventMapper.map($0, surfaceHint: hint).map(AdapterOutput.event)
}
quotaTask.cancel()
```

- [ ] **Step 4: Run usage tests, including passthrough byte equality**

Run: `swift test --filter 'ClaudeUsageMapperTests|CodexRateLimitClientTests|UsageCenterTests|UsageAlertPolicyTests|PassthroughCommandTests'`

Expected: PASS; the fake Codex transport records only `account/rateLimits/read`, and status-line stdout/stderr fixtures match byte-for-byte.

- [ ] **Step 5: Commit subscription usage support**

```bash
git add Package.swift Sources/ClaudeAdapter/ClaudeUsageMapper.swift Sources/CodexAdapter/CodexRateLimitClient.swift Sources/PerchCore/Usage Sources/PerchStatusLineTap Tests
git commit -m "feat: show Claude and Codex plan usage"
```

---

### Task 11: Implement reversible Claude and Codex configuration installation

**Files:**
- Modify: `Package.swift`
- Create: `Sources/PerchInstaller/ConfigurationFingerprint.swift`
- Create: `Sources/PerchInstaller/AtomicFileEditor.swift`
- Create: `Sources/PerchInstaller/OwnershipManifest.swift`
- Create: `Sources/PerchInstaller/ClaudeConfigurationInstaller.swift`
- Create: `Sources/PerchInstaller/CodexConfigurationInstaller.swift`
- Create: `Sources/PerchInstaller/CodexNotifyPatcher.swift`
- Create: `Sources/PerchInstaller/InstallationService.swift`
- Create: `Tests/PerchInstallerTests/ConfigurationInstallerTests.swift`
- Create: `Tests/PerchInstallerTests/Fixtures/claude-existing.json`
- Create: `Tests/PerchInstallerTests/Fixtures/codex-hooks-existing.json`
- Create: `Tests/PerchInstallerTests/Fixtures/codex-config-existing.toml`

**Interfaces:**
- Consumes: stable installed helper paths and the Hook event lists from Tasks 8-10.
- Produces: `ConfigurationFingerprint`, `ConfigurationPreview`, `OwnershipManifest`, deterministic Claude/Codex patchers, and `InstallationService.preview/install/uninstall`.

- [ ] **Step 1: Add installer targets and failing preservation/idempotency tests**

Add targets:

```swift
.library(name: "PerchInstaller", targets: ["PerchInstaller"]),
.target(name: "PerchInstaller"),
.testTarget(name: "PerchInstallerTests", dependencies: ["PerchInstaller"], resources: [.copy("Fixtures")]),
```

```swift
// Tests/PerchInstallerTests/ConfigurationInstallerTests.swift
import XCTest
@testable import PerchInstaller

final class ConfigurationInstallerTests: XCTestCase {
    func testClaudeInstallPreservesExistingHooksAndStatusLine() throws {
        let input = try fixture("claude-existing.json")
        let installer = ClaudeConfigurationInstaller(helperDirectory: URL(fileURLWithPath: "/Users/test/Perch/bin"))
        let first = try installer.patchedData(from: input)
        let second = try installer.patchedData(from: first)
        XCTAssertEqual(first, second)
        XCTAssertTrue(String(decoding: first, as: UTF8.self).contains("existing-hook.sh"))
        XCTAssertTrue(String(decoding: first, as: UTF8.self).contains("perch-statusline-tap"))
    }

    func testFingerprintMismatchRefusesWrite() throws {
        let editor = AtomicFileEditor()
        let url = temporaryFile(contents: Data("newer".utf8))
        XCTAssertThrowsError(try editor.replace(url: url, expected: .sha256(Data("older".utf8)), with: Data("patch".utf8)))
    }

    func testCodexNotifyPatchPreservesUnrelatedToml() throws {
        let input = String(decoding: try fixture("codex-config-existing.toml"), as: UTF8.self)
        let output = try CodexNotifyPatcher.patch(input, command: ["/Users/test/Perch/bin/perch-adapter-codex", "notify"])
        XCTAssertTrue(output.contains("model = \"gpt-5.4\""))
        XCTAssertEqual(output.components(separatedBy: "notify =").count - 1, 1)
    }
}
```

- [ ] **Step 2: Verify installer types are missing**

Run: `swift test --filter PerchInstallerTests`

Expected: FAIL with missing installer and atomic editor types.

- [ ] **Step 3: Implement fingerprints, atomic compare-and-swap, ownership, and idempotent patches**

```swift
// Sources/PerchInstaller/ConfigurationFingerprint.swift
import CryptoKit
import Foundation
public struct ConfigurationFingerprint: Codable, Equatable, Sendable {
    public let hex: String
    public static func sha256(_ data: Data) -> Self {
        .init(hex: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined())
    }
}
public enum ConfigurationEditError: Error { case changedSincePreview, unsupportedShape }
```

```swift
// Sources/PerchInstaller/AtomicFileEditor.swift
import Foundation
public struct AtomicFileEditor {
    public init() {}
    public func replace(url: URL, expected: ConfigurationFingerprint, with data: Data) throws {
        let current = (try? Data(contentsOf: url)) ?? Data()
        guard ConfigurationFingerprint.sha256(current) == expected else {
            throw ConfigurationEditError.changedSincePreview
        }
        let temporary = url.deletingLastPathComponent().appending(path: ".\(url.lastPathComponent).perch-\(UUID().uuidString)")
        try data.write(to: temporary, options: .atomic)
        let existingMode = (try? FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions]) as? NSNumber
        try FileManager.default.setAttributes([.posixPermissions: existingMode?.intValue ?? 0o600],
                                              ofItemAtPath: temporary.path)
        if FileManager.default.fileExists(atPath: url.path) {
            _ = try FileManager.default.replaceItemAt(url, withItemAt: temporary,
                                                       backupItemName: "\(url.lastPathComponent).perch-backup")
        } else {
            try FileManager.default.moveItem(at: temporary, to: url)
        }
    }
}
```

```swift
// Sources/PerchInstaller/OwnershipManifest.swift
import Foundation
public struct ConfigurationWrite: Codable, Equatable, Sendable {
    public let url: URL
    public let original: Data
    public let replacement: Data
    public let mode: Int?
    public init(url: URL, original: Data, replacement: Data, mode: Int? = nil) {
        self.url = url; self.original = original; self.replacement = replacement; self.mode = mode
    }
    public var originalFingerprint: ConfigurationFingerprint { .sha256(original) }
    public var replacementFingerprint: ConfigurationFingerprint { .sha256(replacement) }
}
public struct ConfigurationPreview: Codable, Equatable, Sendable {
    public let writes: [ConfigurationWrite]
    public let conflicts: [String]
    public init(writes: [ConfigurationWrite], conflicts: [String] = []) {
        self.writes = writes; self.conflicts = conflicts
    }
}
public struct OwnershipManifest: Codable, Equatable, Sendable {
    public let installedAt: Date
    public let writes: [ConfigurationWrite]
    public let claudeOriginalStatusLineJSON: Data?
    public init(installedAt: Date, writes: [ConfigurationWrite],
                claudeOriginalStatusLineJSON: Data?) {
        self.installedAt = installedAt; self.writes = writes
        self.claudeOriginalStatusLineJSON = claudeOriginalStatusLineJSON
    }
}
```

```swift
// Sources/PerchInstaller/ClaudeConfigurationInstaller.swift
import Foundation
public struct ClaudeConfigurationInstaller {
    public let helperDirectory: URL
    public init(helperDirectory: URL) { self.helperDirectory = helperDirectory }
    public func patchedData(from data: Data) throws -> Data {
        var root = (try JSONSerialization.jsonObject(with: data.isEmpty ? Data("{}".utf8) : data) as? [String: Any]) ?? [:]
        var hooks = root["hooks"] as? [String: Any] ?? [:]
        let command = helperDirectory.appending(path: "perch-adapter-claude").path + " emit"
        for event in ["SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse", "PostToolUseFailure", "PermissionRequest", "Notification", "SubagentStart", "SubagentStop", "TaskCreated", "TaskCompleted", "Stop", "StopFailure", "SessionEnd"] {
            var groups = hooks[event] as? [[String: Any]] ?? []
            let exists = groups.contains { group in
                (group["hooks"] as? [[String: Any]])?.contains { $0["command"] as? String == command } == true
            }
            if !exists { groups.append(["hooks": [["type": "command", "command": command, "timeout": 1]]]) }
            hooks[event] = groups
        }
        root["hooks"] = hooks
        let tap = helperDirectory.appending(path: "perch-statusline-tap").path
        let current = (root["statusLine"] as? [String: Any])?["command"] as? String ?? ""
        if !current.hasPrefix(tap) {
            root["statusLine"] = ["type": "command", "command": "\(tap) --original-base64 \(Data(current.utf8).base64EncodedString())"]
        }
        return try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys, .prettyPrinted])
    }
}
```

```swift
// Sources/PerchInstaller/CodexConfigurationInstaller.swift
import Foundation
public struct CodexConfigurationInstaller {
    public let helperDirectory: URL
    public init(helperDirectory: URL) { self.helperDirectory = helperDirectory }
    public func patchedHooks(from data: Data) throws -> Data {
        var root = (try JSONSerialization.jsonObject(with: data.isEmpty ? Data("{}".utf8) : data) as? [String: Any]) ?? [:]
        var hooks = root["hooks"] as? [String: Any] ?? [:]
        let command = helperDirectory.appending(path: "perch-adapter-codex").path + " emit"
        for event in ["SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse", "PermissionRequest", "SubagentStart", "SubagentStop", "Stop"] {
            var groups = hooks[event] as? [[String: Any]] ?? []
            let exists = groups.contains { group in
                (group["hooks"] as? [[String: Any]])?.contains { $0["command"] as? String == command } == true
            }
            if !exists { groups.append(["hooks": [["type": "command", "command": command, "timeout": 1]]]) }
            hooks[event] = groups
        }
        root["hooks"] = hooks
        return try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys, .prettyPrinted])
    }
}
```

```swift
// Sources/PerchInstaller/CodexNotifyPatcher.swift
public enum CodexNotifyPatcher {
    public static func patch(_ input: String, command: [String]) throws -> String {
        var lines = input.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let indices = lines.indices.filter { lines[$0].hasPrefix("notify =") }
        guard indices.count <= 1 else { throw ConfigurationEditError.unsupportedShape }
        let escaped = command.map { "\"" + $0.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\"" }.joined(separator: ", ")
        let assignment = "notify = [\(escaped)]"
        if let index = indices.first { lines[index] = assignment }
        else { lines.insert(assignment, at: lines.firstIndex(where: { $0.hasPrefix("[") }) ?? lines.endIndex) }
        return lines.joined(separator: "\n")
    }
}
```

```swift
// Sources/PerchInstaller/InstallationService.swift
import Foundation
public struct InstallationService {
    public let helperDirectory: URL
    public let manifestURL: URL
    private let editor = AtomicFileEditor()
    public init(helperDirectory: URL, manifestURL: URL) {
        self.helperDirectory = helperDirectory; self.manifestURL = manifestURL
    }
    public func preview(helperSources: [URL], claudeURL: URL, codexHooksURL: URL,
                        codexConfigURL: URL, installCodexNotify: Bool) throws -> ConfigurationPreview {
        let claudeOriginal = (try? Data(contentsOf: claudeURL)) ?? Data()
        let hooksOriginal = (try? Data(contentsOf: codexHooksURL)) ?? Data()
        let configOriginal = (try? Data(contentsOf: codexConfigURL)) ?? Data()
        var writes = try helperSources.map { source -> ConfigurationWrite in
            let destination = helperDirectory.appending(path: source.lastPathComponent)
            return .init(url: destination,
                         original: (try? Data(contentsOf: destination)) ?? Data(),
                         replacement: try Data(contentsOf: source), mode: 0o755)
        }
        writes.append(.init(url: claudeURL, original: claudeOriginal,
            replacement: try ClaudeConfigurationInstaller(helperDirectory: helperDirectory)
                .patchedData(from: claudeOriginal)))
        writes.append(.init(url: codexHooksURL, original: hooksOriginal,
            replacement: try CodexConfigurationInstaller(helperDirectory: helperDirectory)
                .patchedHooks(from: hooksOriginal)))
        if installCodexNotify {
            let command = [helperDirectory.appending(path: "perch-adapter-codex").path, "notify"]
            let patched = try CodexNotifyPatcher.patch(String(decoding: configOriginal, as: UTF8.self), command: command)
            writes.append(.init(url: codexConfigURL, original: configOriginal,
                                replacement: Data(patched.utf8)))
        }
        return .init(writes: writes)
    }
    public func install(preview: ConfigurationPreview, claudeOriginalStatusLineJSON: Data?) throws {
        guard preview.conflicts.isEmpty else { throw ConfigurationEditError.unsupportedShape }
        for write in preview.writes {
            let current = (try? Data(contentsOf: write.url)) ?? Data()
            guard ConfigurationFingerprint.sha256(current) == write.originalFingerprint else {
                throw ConfigurationEditError.changedSincePreview
            }
        }
        try FileManager.default.createDirectory(at: helperDirectory, withIntermediateDirectories: true)
        for write in preview.writes {
            try FileManager.default.createDirectory(at: write.url.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try editor.replace(url: write.url, expected: write.originalFingerprint, with: write.replacement)
            if let mode = write.mode { try FileManager.default.setAttributes([.posixPermissions: mode], ofItemAtPath: write.url.path) }
        }
        let manifest = OwnershipManifest(installedAt: .now, writes: preview.writes,
                                         claudeOriginalStatusLineJSON: claudeOriginalStatusLineJSON)
        try FileManager.default.createDirectory(at: manifestURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try JSONEncoder().encode(manifest).write(to: manifestURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600],
                                              ofItemAtPath: manifestURL.path)
    }
    public func uninstall() throws {
        let manifest = try JSONDecoder().decode(OwnershipManifest.self, from: Data(contentsOf: manifestURL))
        for write in manifest.writes {
            let current = (try? Data(contentsOf: write.url)) ?? Data()
            guard ConfigurationFingerprint.sha256(current) == write.replacementFingerprint else {
                throw ConfigurationEditError.changedSincePreview
            }
        }
        for write in manifest.writes.reversed() {
            if write.original.isEmpty { try? FileManager.default.removeItem(at: write.url) }
            else { try editor.replace(url: write.url, expected: write.replacementFingerprint, with: write.original) }
        }
        try FileManager.default.removeItem(at: manifestURL)
    }
}
```

The uninstall test must additionally cover a user edit after install: fingerprint mismatch returns `changedSincePreview` and leaves every file untouched. An unchanged Perch-owned replacement is restored byte-for-byte to its previewed original; an originally absent helper is removed only when its installed fingerprint still matches.

- [ ] **Step 4: Run fixtures, mutation tests, and full suite**

Run: `swift test --filter PerchInstallerTests && swift test`

Expected: PASS for empty, existing, already-installed, concurrent-change, duplicate-notify, and user-edited-after-install fixtures.

- [ ] **Step 5: Commit the reversible installer**

```bash
git add Package.swift Sources/PerchInstaller Tests/PerchInstallerTests
git commit -m "feat: install and restore AI tool integrations"
```

---

### Task 12: Connect supervised adapter output to the canonical Task Store

**Files:**
- Create: `Sources/PerchCore/Tasks/TaskStore.swift`
- Create: `Sources/PerchCore/Plugins/ProcessAdapterLauncher.swift`
- Create: `Tests/PerchCoreTests/TaskStoreTests.swift`
- Create: `Tests/PerchCoreTests/ProcessAdapterLauncherTests.swift`

**Interfaces:**
- Consumes: `PluginReady` followed by `AdapterOutput` NDJSON on adapter stdout, plus `EventDeduplicator`, `TaskReducer`, `NotificationPolicy`, and `PluginSupervisor`.
- Produces: actor `TaskStore.ingest(_:)`, `TaskStore.currentTasks()`, `TaskStore.pendingLand()`, and production `ProcessAdapterLauncher`.

- [ ] **Step 1: Write failing event-to-snapshot and event-to-Land integration tests**

```swift
// Tests/PerchCoreTests/TaskStoreTests.swift
import XCTest
import PerchProtocol
@testable import PerchCore

final class TaskStoreTests: XCTestCase {
    func testCompletionUpdatesSnapshotAndEmitsExactlyOneLand() async throws {
        let store = TaskStore()
        let started = event(id: "1", type: .turnStarted)
        let completed = event(id: "2", type: .turnCompleted)
        await store.ingest(started)
        await store.ingest(completed)
        await store.ingest(completed)
        XCTAssertEqual(await store.currentTasks().first?.status, .succeeded)
        XCTAssertEqual(await store.pendingLand().count, 1)
    }
    func testTwoCompletionsFromSameSourceBecomeOneBatch() async {
        let store = TaskStore()
        await store.ingest(event(id: "1", type: .turnCompleted, session: "a"))
        await store.ingest(event(id: "2", type: .turnCompleted, session: "b"))
        let land = await store.pendingLand()
        XCTAssertEqual(land.count, 1)
        XCTAssertEqual(land.first?.batchCount, 2)
    }
    private func event(id: String, type: EventType, session: String = "s") -> EventEnvelope {
        .init(eventId: id, emittedAt: .now, source: .codex, surface: .unknown,
              sessionId: session, turnId: "t", taskId: nil, type: type, payload: [:])
    }
}
```

```swift
// Tests/PerchCoreTests/ProcessAdapterLauncherTests.swift
func testNonJSONHandshakeMarksLaunchAsFailure() async {
    let launcher = ProcessAdapterLauncher(handshakeTimeout: .milliseconds(200))
    do {
        _ = try await launcher.launch(.fixture,
            hello: .init(protocolVersion: 1, hostVersion: "test"),
            onOutput: { _ in }, onTermination: {})
        XCTFail("Expected malformed handshake to throw")
    } catch { XCTAssertNotNil(error) }
}
```

- [ ] **Step 2: Verify Task Store and production launcher are missing**

Run: `swift test --filter 'TaskStoreTests|ProcessAdapterLauncherTests'`

Expected: FAIL with missing `TaskStore` and `ProcessAdapterLauncher`.

- [ ] **Step 3: Implement serial ingestion and process handshake**

```swift
// Sources/PerchCore/Tasks/TaskStore.swift
import PerchProtocol
public actor TaskStore {
    private var tasks: [TaskKey: TaskSnapshot] = [:]
    private var deduplicator = EventDeduplicator()
    private var land: [LandNotification] = []
    private var batcher = LandBatcher(window: 2)
    private let policy = NotificationPolicy()
    public init() {}
    public func ingest(_ event: EventEnvelope) {
        guard deduplicator.accepts(event.eventId) else { return }
        let key = TaskKey(source: event.source, surface: event.surface,
                          sessionId: event.sessionId, turnId: event.turnId)
        var next = tasks[key] ?? .make(for: event)
        let previous = next.status
        TaskReducer.reduce(event, into: &next)
        tasks[key] = next
        if case .enqueue(let notification) = policy.decision(for: next, previous: previous) {
            let batch = batcher.insert(notification)
            if batch.count > 1 {
                let replaced = Set(batch.dropLast().map(\.id))
                land.removeAll { replaced.contains($0.id) }
                land.append(notification.batched(count: batch.count))
            } else { land.append(notification) }
        }
    }
    public func currentTasks() -> [TaskSnapshot] { tasks.values.sorted { $0.updatedAt > $1.updatedAt } }
    public func pendingLand() -> [LandNotification] { land }
    public func dismissLand(id: String) { land.removeAll { $0.id == id } }
}
```

`ProcessAdapterLauncher` uses `Process` with separate stdin/stdout/stderr pipes, writes `PluginHello` as NDJSON, and keeps the stdin writer open for the child's lifetime so parent exit produces EOF and shuts the adapter down. It treats the first stdout line as `PluginReady`; each later line decodes as `AdapterOutput` and is sent to `onOutput`. A 200 ms handshake timeout terminates the child and throws `AdapterLaunchError.handshakeTimeout`; invalid first-line JSON throws `AdapterLaunchError.invalidHandshake`. Stderr is drained to a bounded 64 KiB diagnostic buffer and is never decoded as protocol data. After a successful handshake, process termination invokes `onTermination` exactly once; a launch/handshake failure throws instead and is scheduled by `PluginSupervisor`'s catch path. Intentional `stop(id:)` closes stdin, terminates after a short grace period, and suppresses `onTermination`.

- [ ] **Step 4: Run integration tests with `/usr/bin/true` and a fixture adapter script**

Run: `swift test --filter 'TaskStoreTests|ProcessAdapterLauncherTests' && swift test`

Expected: PASS; one completion produces one Land even when duplicated, and malformed handshakes fail within 200 ms.

- [ ] **Step 5: Commit Core integration**

```bash
git add Sources/PerchCore/Tasks/TaskStore.swift Sources/PerchCore/Plugins/ProcessAdapterLauncher.swift Tests/PerchCoreTests
git commit -m "feat: ingest adapter events into canonical state"
```

---

### Task 13: Build the three-layer SwiftUI surfaces

**Files:**
- Modify: `Package.swift`
- Create: `Sources/PerchUI/AppModel.swift`
- Create: `Sources/PerchUI/Actions/DeepLinkService.swift`
- Create: `Sources/PerchUI/Ambient/AmbientHUDView.swift`
- Create: `Sources/PerchUI/Land/LandNotificationView.swift`
- Create: `Sources/PerchUI/Tasks/TaskCenterView.swift`
- Create: `Sources/PerchUI/Usage/UsageBarsView.swift`
- Create: `Tests/PerchUITests/AppModelTests.swift`
- Create: `Tests/PerchUITests/DeepLinkServiceTests.swift`

**Interfaces:**
- Consumes: immutable `TaskSnapshot`, `LandNotification`, `UsageSnapshot`, `TaskStore`, and `UsageCenter`.
- Produces: `@MainActor AppModel`, `AmbientHUDView`, `LandNotificationView`, `TaskCenterView`, and `UsageBarsView`.
- Produces: `DeepLinkService.open(_:)`, which activates an app or opens a validated non-file URL without executing a command.

- [ ] **Step 1: Add UI targets and failing presentation-state tests**

Add targets:

```swift
.library(name: "PerchUI", targets: ["PerchUI"]),
.target(name: "PerchUI", dependencies: ["PerchCore", "PerchProtocol"]),
.testTarget(name: "PerchUITests", dependencies: ["PerchUI", "PerchCore", "PerchProtocol"]),
```

```swift
// Tests/PerchUITests/AppModelTests.swift
import XCTest
import PerchProtocol
import PerchCore
@testable import PerchUI

@MainActor final class AppModelTests: XCTestCase {
    func testAmbientSummaryShowsCountAndHighestPriorityOnly() {
        let model = AppModel(tasks: [task(.running, id: "1"), task(.waitingForUser, id: "2")], usage: [])
        XCTAssertEqual(model.ambientSummary.runningCount, 2)
        XCTAssertTrue(model.ambientSummary.needsAttention)
        XCTAssertNil(model.ambientSummary.usagePercentage)
    }
    func testUsageAppearsInPeekAndTaskCenterModels() {
        let snapshot = UsageSnapshot(provider: .claude,
            windows: [.init(kind: "five_hour", usedPercentage: 42, resetsAt: nil)],
            fetchedAt: .now, freshness: .live)
        let model = AppModel(tasks: [], usage: [snapshot])
        XCTAssertEqual(model.peekUsage.count, 1)
        XCTAssertEqual(model.taskCenterUsage.count, 1)
    }
    private func task(_ status: TaskStatus, id: String) -> TaskSnapshot {
        .init(key: .init(source: .codex, surface: .unknown, sessionId: id, turnId: "t"),
              status: status, projectName: "perch", summary: "safe",
              lastActivity: nil, updatedAt: .now)
    }
}
```

```swift
// Tests/PerchUITests/DeepLinkServiceTests.swift
import XCTest
@testable import PerchUI

final class DeepLinkServiceTests: XCTestCase {
    func testRejectsFileAndWebURLs() {
        XCTAssertFalse(DeepLinkService.isAllowed(URL(string: "file:///Users/test/secret")!))
        XCTAssertFalse(DeepLinkService.isAllowed(URL(string: "https://example.com")!))
        XCTAssertTrue(DeepLinkService.isAllowed(URL(string: "codex://thread/123")!))
    }
}
```

- [ ] **Step 2: Verify UI model is missing**

Run: `swift test --filter AppModelTests`

Expected: FAIL with missing `AppModel`.

- [ ] **Step 3: Implement AppModel and minimal accessible views**

```swift
// Sources/PerchUI/AppModel.swift
import Foundation
import PerchCore
import PerchProtocol
import SwiftUI

public struct AmbientSummary: Equatable {
    public let runningCount: Int
    public let needsAttention: Bool
    public let usagePercentage: Double? = nil
}

@MainActor public final class AppModel: ObservableObject {
    @Published public private(set) var tasks: [TaskSnapshot]
    @Published public private(set) var land: [LandNotification]
    @Published public private(set) var usage: [UsageSnapshot]
    public var ambientSummary: AmbientSummary {
        .init(runningCount: tasks.filter { !$0.status.isTerminal }.count,
              needsAttention: tasks.contains { $0.status == .waitingForUser || $0.status == .failed })
    }
    public var peekUsage: [UsageSnapshot] { usage }
    public var taskCenterUsage: [UsageSnapshot] { usage }
    public init(tasks: [TaskSnapshot] = [], land: [LandNotification] = [], usage: [UsageSnapshot] = []) {
        self.tasks = tasks; self.land = land; self.usage = usage
    }
    public func refresh(taskStore: TaskStore, usageCenter: UsageCenter, now: Date = .now) async {
        tasks = await taskStore.currentTasks()
        land = await taskStore.pendingLand()
        let claude = await usageCenter.snapshot(for: .claude, now: now)
        let codex = await usageCenter.snapshot(for: .codex, now: now)
        usage = [claude, codex].compactMap { $0 }
    }
}
```

```swift
// Sources/PerchUI/Actions/DeepLinkService.swift
import AppKit
public enum DeepLinkService {
    public static func isAllowed(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return !["file", "http", "https", "javascript"].contains(scheme)
    }
    @MainActor public static func open(_ url: URL) {
        guard isAllowed(url) else { return }
        NSWorkspace.shared.open(url)
    }
    @MainActor public static func activate(bundleIdentifier: String) async throws {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            throw CocoaError(.fileNoSuchFile)
        }
        _ = try await NSWorkspace.shared.openApplication(at: url, configuration: .init())
    }
}
```

```swift
// Sources/PerchUI/Usage/UsageBarsView.swift
import PerchProtocol
import SwiftUI
public struct UsageBarsView: View {
    public let snapshots: [UsageSnapshot]
    public init(snapshots: [UsageSnapshot]) { self.snapshots = snapshots }
    public var body: some View {
        ForEach(snapshots, id: \.provider) { snapshot in
            VStack(alignment: .leading) {
                Text(snapshot.provider.rawValue.capitalized)
                ForEach(snapshot.windows, id: \.kind) { window in
                    ProgressView(value: window.usedPercentage, total: 100)
                        .accessibilityLabel("\(window.kind) usage")
                        .accessibilityValue("\(Int(window.usedPercentage)) percent used")
                }
            }
        }
    }
}
```

```swift
// Sources/PerchUI/Ambient/AmbientHUDView.swift
import SwiftUI
public struct AmbientHUDView: View {
    @ObservedObject var model: AppModel
    @State private var expanded = false
    public init(model: AppModel) { self.model = model }
    public var body: some View {
        VStack {
            Text("\(model.ambientSummary.runningCount) running")
            if model.ambientSummary.needsAttention { Image(systemName: "exclamationmark.circle.fill") }
            if expanded {
                ForEach(Array(model.tasks.prefix(3).enumerated()), id: \.offset) { _, task in
                    Text(task.projectName ?? task.key.source.rawValue.capitalized).lineLimit(1)
                }
                UsageBarsView(snapshots: model.peekUsage)
            }
        }
        .onHover { expanded = $0 }
        .accessibilityLabel("Perch task status")
    }
}
```

```swift
// Sources/PerchUI/Land/LandNotificationView.swift
import PerchCore
import PerchProtocol
import SwiftUI
public struct LandNotificationView: View {
    public let notification: LandNotification
    public let open: () -> Void
    public let dismiss: () -> Void
    public init(notification: LandNotification, open: @escaping () -> Void,
                dismiss: @escaping () -> Void) {
        self.notification = notification; self.open = open; self.dismiss = dismiss
    }
    public var body: some View {
        VStack(alignment: .leading) {
            Text(notification.source.rawValue.capitalized).font(.headline)
            if let project = notification.projectName { Text(project).font(.subheadline) }
            Text(String(describing: notification.status))
            if notification.batchCount > 1 { Text("\(notification.batchCount) tasks") }
            if let summary = notification.summary { Text(summary).lineLimit(2) }
            Text(Duration.seconds(notification.duration)
                .formatted(.units(allowed: [.minutes, .seconds], width: .abbreviated)))
            HStack { Button("Open", action: open); Button("Dismiss", action: dismiss) }
        }
        .accessibilityElement(children: .contain)
    }
}
```

```swift
// Sources/PerchUI/Tasks/TaskCenterView.swift
import PerchCore
import SwiftUI
public enum TaskFilter: String, CaseIterable, Hashable { case all = "All", active = "Active", needsYou = "Needs You" }
public struct TaskCenterView: View {
    @ObservedObject var model: AppModel
    @State private var filter: TaskFilter = .all
    public init(model: AppModel) { self.model = model }
    public var body: some View {
        VStack {
            UsageBarsView(snapshots: model.taskCenterUsage)
            Picker("Tasks", selection: $filter) { ForEach(TaskFilter.allCases, id: \.self) { Text($0.rawValue) } }
            List(Array(filtered.enumerated()), id: \.offset) { _, task in
                VStack(alignment: .leading) {
                    Text(task.projectName ?? "Task")
                    Text("\(task.key.source.rawValue.capitalized) · \(String(describing: task.status))")
                    if let summary = task.summary { Text(summary).lineLimit(2) }
                    Text(task.updatedAt.formatted(date: .omitted, time: .shortened)).font(.caption)
                }
            }
        }
    }
    private var filtered: [TaskSnapshot] {
        model.tasks.filter { task in
            switch filter {
            case .all: true
            case .active: !task.status.isTerminal
            case .needsYou: task.status == .waitingForUser || task.status == .failed
            }
        }
    }
}
```

`AmbientHUDView` renders only the running count and attention indicator in its compact state. Its hover/expanded state adds recent tasks and `UsageBarsView`. `LandNotificationView` renders source, terminal/attention status, duration, summary, “Open” and “Dismiss”; it exposes accessibility labels and contains no approve/deny controls. “Open” calls `DeepLinkService` only for a validated custom URL; otherwise it activates the configured Claude, Codex, or terminal bundle without executing shell text. `TaskCenterView` has `All`, `Active`, and `Needs You` filters, with usage bars fixed above the list.

- [ ] **Step 4: Run model tests and compile SwiftUI previews**

Run: `swift test --filter PerchUITests && swift build --target PerchUI`

Expected: PASS; no usage percentage is present in `AmbientSummary` compact state.

- [ ] **Step 5: Commit the three-layer views**

```bash
git add Package.swift Sources/PerchUI Tests/PerchUITests
git commit -m "feat: add Ambient Land and Task Center UI"
```

---

### Task 14: Add window placement, settings, Doctor, and app composition

**Files:**
- Modify: `Package.swift`
- Modify: `Sources/PerchApp/PerchApp.swift`
- Create: `Sources/PerchApp/AppComposition.swift`
- Create: `Sources/PerchUI/Windows/WindowPlacement.swift`
- Create: `Sources/PerchUI/Windows/DisplayCoordinator.swift`
- Create: `Sources/PerchUI/Windows/PerchPanel.swift`
- Create: `Sources/PerchUI/Windows/WindowHost.swift`
- Create: `Sources/PerchUI/Settings/SettingsView.swift`
- Create: `Sources/PerchUI/Settings/DoctorView.swift`
- Create: `Sources/PerchCore/Diagnostics/DoctorReport.swift`
- Create: `Sources/PerchCore/Notifications/PresentationPolicy.swift`
- Create: `Tests/PerchUITests/WindowPlacementTests.swift`
- Create: `Tests/PerchCoreTests/DoctorReportTests.swift`
- Create: `Tests/PerchCoreTests/PresentationPolicyTests.swift`

**Interfaces:**
- Consumes: AppModel, installer health, adapter health, screen geometry, Focus suppression preference, and `accessibilityReduceMotion`.
- Produces: pure `WindowPlacement`, `DisplayCoordinator`, `PerchPanel`, `DoctorReport`, focus-aware `PresentationPolicy`, `SettingsView`, and production `AppComposition`.
- Produces: `WindowHost` that actually mounts Ambient and Land, while Task Center is mounted in the menu-bar scene.

- [ ] **Step 1: Write failing notch/floating placement and Doctor tests**

```swift
// Tests/PerchUITests/WindowPlacementTests.swift
func testNotchScreenCentersPanelAtVisibleTop() {
    let frame = CGRect(x: 0, y: 0, width: 1512, height: 982)
    let visible = CGRect(x: 0, y: 0, width: 1512, height: 950)
    let result = WindowPlacement.land(screenFrame: frame, visibleFrame: visible,
                                      safeAreaTop: 32, panelSize: .init(width: 360, height: 120))
    XCTAssertEqual(result.origin.x, 576)
    XCTAssertEqual(result.maxY, 950)
}
```

```swift
// Tests/PerchCoreTests/DoctorReportTests.swift
func testExplainsUntrustedCodexHooks() {
    let report = DoctorReport.make(adapter: .degraded, hooksInstalled: true,
                                   hooksTrusted: false, lastEventAt: nil)
    XCTAssertEqual(report.primaryIssue, .hooksNeedTrust)
}
func testSeparatesVersionMismatchFromConnectionLoss() {
    XCTAssertEqual(DoctorReport.make(adapter: .incompatible, hooksInstalled: true,
        hooksTrusted: true, lastEventAt: nil).primaryIssue, .adapterIncompatible)
    XCTAssertEqual(DoctorReport.make(adapter: .degraded, hooksInstalled: true,
        hooksTrusted: true, lastEventAt: nil).primaryIssue, .connectionInterrupted)
}
```

```swift
// Tests/PerchCoreTests/PresentationPolicyTests.swift
import XCTest
@testable import PerchCore

final class PresentationPolicyTests: XCTestCase {
    func testFocusSuppressionHidesPanelsButKeepsIngestionEnabled() {
        let result = PresentationPolicy(focusSuppressionEnabled: true)
            .decision(focusIsActive: true)
        XCTAssertFalse(result.presentPanels)
        XCTAssertTrue(result.ingestEvents)
    }
}
```

- [ ] **Step 2: Verify placement and Doctor symbols are missing**

Run: `swift test --filter 'WindowPlacementTests|DoctorReportTests|PresentationPolicyTests'`

Expected: FAIL with missing `WindowPlacement`, `DoctorReport`, and `PresentationPolicy`.

- [ ] **Step 3: Implement pure placement, non-activating panels, diagnostics, and composition**

Replace the `PerchApp` target declaration so the executable can import the composed modules:

```swift
.executableTarget(
    name: "PerchApp",
    dependencies: ["PerchCore", "PerchInstaller", "PerchProtocol", "PerchUI"],
    resources: [.copy("Resources/Info.plist")]
),
```

```swift
// Sources/PerchUI/Windows/WindowPlacement.swift
import CoreGraphics
public enum WindowPlacement {
    public static func land(screenFrame: CGRect, visibleFrame: CGRect,
                            safeAreaTop: CGFloat, panelSize: CGSize,
                            topInset: CGFloat = 0) -> CGRect {
        let usableTop = min(visibleFrame.maxY, screenFrame.maxY - safeAreaTop) - topInset
        return CGRect(x: screenFrame.midX - panelSize.width / 2,
                      y: usableTop - panelSize.height,
                      width: panelSize.width, height: panelSize.height)
    }
}
```

```swift
// Sources/PerchCore/Diagnostics/DoctorReport.swift
import Foundation
public enum DoctorIssue: Equatable {
    case hooksMissing, hooksNeedTrust, adapterUnavailable, adapterIncompatible
    case connectionInterrupted, noEventsYet
}
public struct DoctorReport: Equatable {
    public let primaryIssue: DoctorIssue?
    public init(primaryIssue: DoctorIssue?) { self.primaryIssue = primaryIssue }
    public static func make(adapter: AdapterHealth, hooksInstalled: Bool,
                            hooksTrusted: Bool, lastEventAt: Date?) -> Self {
        if !hooksInstalled { return .init(primaryIssue: .hooksMissing) }
        if !hooksTrusted { return .init(primaryIssue: .hooksNeedTrust) }
        if adapter == .incompatible { return .init(primaryIssue: .adapterIncompatible) }
        if adapter == .degraded { return .init(primaryIssue: .connectionInterrupted) }
        if adapter != .healthy { return .init(primaryIssue: .adapterUnavailable) }
        if lastEventAt == nil { return .init(primaryIssue: .noEventsYet) }
        return .init(primaryIssue: nil)
    }
}
```

```swift
// Sources/PerchCore/Notifications/PresentationPolicy.swift
public struct PresentationDecision: Equatable, Sendable {
    public let presentPanels: Bool
    public let ingestEvents: Bool
    public init(presentPanels: Bool, ingestEvents: Bool) {
        self.presentPanels = presentPanels; self.ingestEvents = ingestEvents
    }
}
public struct PresentationPolicy: Sendable {
    public var focusSuppressionEnabled: Bool
    public init(focusSuppressionEnabled: Bool = false) {
        self.focusSuppressionEnabled = focusSuppressionEnabled
    }
    public func decision(focusIsActive: Bool) -> PresentationDecision {
        .init(presentPanels: !(focusSuppressionEnabled && focusIsActive), ingestEvents: true)
    }
}
```

```swift
// Sources/PerchUI/Windows/PerchPanel.swift
import AppKit
public final class PerchPanel: NSPanel {
    private let allowsKey: Bool
    public init(contentRect: NSRect, allowsKey: Bool = false) {
        self.allowsKey = allowsKey
        super.init(contentRect: contentRect, styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        level = .statusBar; isOpaque = false; backgroundColor = .clear
        isFloatingPanel = true; hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }
    public override var canBecomeKey: Bool { allowsKey }
}
```

```swift
// Sources/PerchUI/Windows/WindowHost.swift
import AppKit
import Foundation
import Intents
import PerchCore
import PerchProtocol
import SwiftUI

@MainActor public final class WindowHost {
    private let ambient = PerchPanel(contentRect: .zero)
    private let land = PerchPanel(contentRect: .zero, allowsKey: true)
    private var landGeneration = UUID()
    public init() {}
    public func showAmbient(model: AppModel, on screen: NSScreen) {
        let size = CGSize(width: 240, height: 52)
        ambient.contentView = NSHostingView(rootView: AmbientHUDView(model: model)
            .padding(10).background(.ultraThinMaterial, in: Capsule()))
        ambient.setFrame(WindowPlacement.land(screenFrame: screen.frame,
            visibleFrame: screen.visibleFrame, safeAreaTop: screen.safeAreaInsets.top,
            panelSize: size), display: true)
        ambient.orderFrontRegardless()
    }
    public func showLand(_ notification: LandNotification, on screen: NSScreen,
                         open: @escaping () -> Void, dismiss: @escaping () -> Void) {
        landGeneration = UUID(); let generation = landGeneration
        let size = CGSize(width: 360, height: 150)
        land.contentView = NSHostingView(rootView: LandNotificationView(
            notification: notification, open: open, dismiss: dismiss)
            .padding(16).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20)))
        land.setFrame(WindowPlacement.land(screenFrame: screen.frame,
            visibleFrame: screen.visibleFrame, safeAreaTop: screen.safeAreaInsets.top,
            panelSize: size, topInset: 60), display: true)
        land.orderFrontRegardless()
        if notification.priority == .p1 {
            Task {
                try? await Task.sleep(for: .seconds(5))
                if landGeneration == generation { dismiss() }
            }
        }
    }
    public func showUsageAlert(provider: UsageProvider, threshold: Int, on screen: NSScreen) {
        landGeneration = UUID(); let generation = landGeneration
        let size = CGSize(width: 360, height: 110)
        land.contentView = NSHostingView(rootView: VStack(alignment: .leading) {
            Text("\(provider.rawValue.capitalized) usage").font(.headline)
            Text("\(threshold)% of a subscription window has been used.")
        }.padding(16).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20)))
        land.setFrame(WindowPlacement.land(screenFrame: screen.frame,
            visibleFrame: screen.visibleFrame, safeAreaTop: screen.safeAreaInsets.top,
            panelSize: size, topInset: 60), display: true)
        land.orderFrontRegardless()
        Task {
            try? await Task.sleep(for: .seconds(5))
            if landGeneration == generation { land.orderOut(nil) }
        }
    }
    public func panelsMayPresent() -> Bool {
        let policy = PresentationPolicy(
            focusSuppressionEnabled: UserDefaults.standard.bool(forKey: "focusSuppressionEnabled"))
        return policy.decision(
            focusIsActive: INFocusStatusCenter.default.focusStatus.isFocused ?? false).presentPanels
    }
    public func dismissLand() { land.orderOut(nil) }
}
```

```swift
// Sources/PerchUI/Windows/DisplayCoordinator.swift
import AppKit
@MainActor public final class DisplayCoordinator {
    public init() {}
    public func targetScreen(preferredDisplayID: NSNumber?) -> NSScreen? {
        if let preferredDisplayID,
           let match = NSScreen.screens.first(where: { $0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber == preferredDisplayID }) {
            return match
        }
        return NSScreen.main ?? NSScreen.screens.first
    }
    public func landFrame(on screen: NSScreen, size: CGSize) -> CGRect {
        WindowPlacement.land(screenFrame: screen.frame, visibleFrame: screen.visibleFrame,
                             safeAreaTop: screen.safeAreaInsets.top, panelSize: size)
    }
}
```

```swift
// Sources/PerchApp/AppComposition.swift
import AppKit
import PerchCore
import PerchInstaller
import PerchProtocol
import PerchUI
import SwiftUI

@MainActor final class AppComposition: ObservableObject {
    let taskStore: TaskStore
    let usageCenter: UsageCenter
    let supervisor: PluginSupervisor
    let appModel: AppModel
    let displays: DisplayCoordinator
    let windows: WindowHost
    private var started = false
    init(launcher: ProcessAdapterLauncher = .init(handshakeTimeout: .milliseconds(200))) {
        let tasks = TaskStore(); let usage = UsageCenter(staleAfter: 60)
        let model = AppModel(); let host = WindowHost(); let display = DisplayCoordinator()
        taskStore = tasks; usageCenter = usage; appModel = model
        windows = host; displays = display
        supervisor = PluginSupervisor(protocolVersion: 1, launcher: launcher) { output in
            let shouldPresentTaskLand = output.kind == .event
            switch output.kind {
            case .event: if let event = output.event { await tasks.ingest(event) }
            case .usage:
                if let snapshot = output.usage {
                    let enabled = await MainActor.run {
                        UserDefaults.standard.bool(forKey: "usageAlertsEnabled")
                    }
                    let thresholds = await usage.update(snapshot, alertsEnabled: enabled)
                    await MainActor.run {
                        if let threshold = thresholds.last,
                           host.panelsMayPresent(),
                           let screen = display.targetScreen(preferredDisplayID: Self.preferredDisplayID()) {
                            host.showUsageAlert(provider: snapshot.provider,
                                                threshold: threshold, on: screen)
                        }
                    }
                }
            }
            await model.refresh(taskStore: tasks, usageCenter: usage)
            await MainActor.run {
                if shouldPresentTaskLand, let notification = model.land.last,
                   host.panelsMayPresent(),
                   let screen = display.targetScreen(preferredDisplayID: Self.preferredDisplayID()) {
                    host.showLand(notification, on: screen, open: {
                        let bundle = notification.source == .codex ? "com.openai.codex" : "com.apple.Terminal"
                        Task { try? await DeepLinkService.activate(bundleIdentifier: bundle) }
                    }, dismiss: {
                        Task {
                            await tasks.dismissLand(id: notification.id)
                            await model.refresh(taskStore: tasks, usageCenter: usage)
                            host.dismissLand()
                        }
                    })
                }
            }
        }
    }
    func start() async {
        guard !started else { return }
        started = true
        if let screen = displays.targetScreen(preferredDisplayID: Self.preferredDisplayID()) {
            windows.showAmbient(model: appModel, on: screen)
        }
        let helpers = Bundle.main.bundleURL.appending(path: "Contents/Helpers")
        await supervisor.start(.init(id: "claude",
            executable: helpers.appending(path: "perch-adapter-claude"), arguments: ["serve"]))
        await supervisor.start(.init(id: "codex",
            executable: helpers.appending(path: "perch-adapter-codex"), arguments: ["serve"]))
    }
    private static func preferredDisplayID() -> NSNumber? {
        let raw = UserDefaults.standard.string(forKey: "preferredDisplayID") ?? ""
        return Int(raw).map(NSNumber.init(value:))
    }
}
```

```swift
// Sources/PerchApp/PerchApp.swift
import PerchUI
import SwiftUI

@main struct PerchApp: App {
    @StateObject private var composition = AppComposition()
    @AppStorage("usageAlertsEnabled") private var usageAlertsEnabled = false
    @AppStorage("focusSuppressionEnabled") private var focusSuppressionEnabled = false
    @AppStorage("preferredDisplayID") private var preferredDisplayID = ""
    var body: some Scene {
        MenuBarExtra {
            TaskCenterView(model: composition.appModel).frame(width: 420, height: 560)
        } label: {
            Label("Perch", systemImage: "bird").task { await composition.start() }
        }
        Settings {
            SettingsView(usageAlertsEnabled: $usageAlertsEnabled,
                         focusSuppressionEnabled: $focusSuppressionEnabled,
                         preferredDisplayID: $preferredDisplayID)
                .frame(width: 480, height: 320)
        }
    }
}
```

```swift
// Sources/PerchUI/Settings/SettingsView.swift
import AppKit
import SwiftUI
public struct SettingsView: View {
    @Binding private var usageAlertsEnabled: Bool
    @Binding private var focusSuppressionEnabled: Bool
    @Binding private var preferredDisplayID: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public init(usageAlertsEnabled: Binding<Bool>, focusSuppressionEnabled: Binding<Bool>,
                preferredDisplayID: Binding<String>) {
        _usageAlertsEnabled = usageAlertsEnabled
        _focusSuppressionEnabled = focusSuppressionEnabled
        _preferredDisplayID = preferredDisplayID
    }
    public var body: some View {
        Form {
            Toggle("Usage threshold alerts", isOn: $usageAlertsEnabled)
            Toggle("Suppress panels during Focus", isOn: $focusSuppressionEnabled)
            Picker("Display", selection: $preferredDisplayID) {
                Text("Automatic").tag("")
                ForEach(NSScreen.screens, id: \.localizedName) { screen in
                    let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
                    Text(screen.localizedName).tag(number?.stringValue ?? "")
                }
            }
            LabeledContent("Reduced Motion", value: reduceMotion ? "On" : "Off")
        }.formStyle(.grouped)
    }
}
```

```swift
// Sources/PerchUI/Settings/DoctorView.swift
import PerchCore
import SwiftUI
public struct DoctorView: View {
    public let report: DoctorReport
    public init(report: DoctorReport) { self.report = report }
    public var body: some View {
        VStack(alignment: .leading) {
            Text("Perch Doctor").font(.headline)
            Text(message)
        }.accessibilityElement(children: .combine)
    }
    private var message: String {
        switch report.primaryIssue {
        case .hooksMissing: "Integration hooks are not installed."
        case .hooksNeedTrust: "Codex must trust the configured hook directory."
        case .adapterUnavailable: "The adapter is unavailable and will retry."
        case .adapterIncompatible: "The adapter protocol version is incompatible."
        case .connectionInterrupted: "The adapter connection was interrupted and will retry."
        case .noEventsYet: "Integration is ready; no events have arrived yet."
        case nil: "All monitored integrations are healthy."
        }
    }
}
```

`PerchApp` owns one `@StateObject private var composition = AppComposition()`, supplies `composition.appModel` to Ambient, Land, Task Center, Settings, and Doctor views, and starts both adapter specs on launch. A refresh task calls `AppModel.refresh` after each adapter output. Reduced Motion selects opacity/ease animations instead of spring/geometry motion. Focus suppression skips panel presentation while leaving `TaskStore` and `UsageCenter` updates active.

- [ ] **Step 4: Run geometry, diagnostics, and app build tests**

Run: `swift test --filter 'WindowPlacementTests|DoctorReportTests|PresentationPolicyTests' && Scripts/build-app.sh`

Expected: PASS and `.build/Perch.app` builds without permission usage-description keys.

- [ ] **Step 5: Commit windows and app composition**

```bash
git add Package.swift Sources/PerchCore/Diagnostics Sources/PerchUI/Windows Sources/PerchUI/Settings Sources/PerchApp Tests
git commit -m "feat: compose Perch Alpha windows and diagnostics"
```

---

### Task 15: Package helpers, run end-to-end smoke tests, and document Alpha

**Files:**
- Modify: `Scripts/build-app.sh`
- Create: `Scripts/package-unsigned.sh`
- Create: `Scripts/run-alpha-smoke.sh`
- Create: `Tests/PerchCoreTests/AlphaAcceptanceTests.swift`
- Create: `README.md`
- Create: `docs/alpha-testing.md`

**Interfaces:**
- Consumes: all previous products and acceptance metrics.
- Produces: `.build/Perch.app` containing all helper executables, `.build/Perch-unsigned.zip`, repeatable smoke runner, and contributor documentation.

- [ ] **Step 1: Write a failing end-to-end duplicate/latency acceptance test**

```swift
// Tests/PerchCoreTests/AlphaAcceptanceTests.swift
import XCTest
import PerchProtocol
@testable import PerchCore

final class AlphaAcceptanceTests: XCTestCase {
    func testOneHundredTerminalEventsAreDeliveredOnceAndBatched() async {
        let store = TaskStore()
        for index in 0..<100 {
            let event = EventEnvelope(eventId: "done-\(index)", emittedAt: .now,
                source: .codex, surface: .unknown, sessionId: "s-\(index)", turnId: "t",
                taskId: nil, type: .turnCompleted, payload: [:])
            await store.ingest(event)
            await store.ingest(event)
        }
        XCTAssertEqual(await store.currentTasks().count, 100)
        let land = await store.pendingLand()
        XCTAssertEqual(land.count, 1)
        XCTAssertEqual(land.first?.batchCount, 100)
    }
}
```

- [ ] **Step 2: Run acceptance test before helper packaging changes**

Run: `swift test --filter AlphaAcceptanceTests`

Expected: PASS for Core behavior; `Scripts/run-alpha-smoke.sh` and packaging artifacts do not yet exist.

- [ ] **Step 3: Package all helpers and add real-tool smoke commands**

Replace `Scripts/build-app.sh` with:

```bash
#!/bin/zsh
set -euo pipefail
swift build -c release --arch arm64 --product PerchApp
swift build -c release --arch arm64 --product perch-adapter-claude
swift build -c release --arch arm64 --product perch-adapter-codex
swift build -c release --arch arm64 --product perch-statusline-tap
BIN="$PWD/.build/arm64-apple-macosx/release"
APP="$PWD/.build/Perch.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Helpers" "$APP/Contents/Resources"
cp "$BIN/PerchApp" "$APP/Contents/MacOS/PerchApp"
cp "$BIN/perch-adapter-claude" "$APP/Contents/Helpers/perch-adapter-claude"
cp "$BIN/perch-adapter-codex" "$APP/Contents/Helpers/perch-adapter-codex"
cp "$BIN/perch-statusline-tap" "$APP/Contents/Helpers/perch-statusline-tap"
chmod 0755 "$APP/Contents/MacOS/PerchApp" "$APP/Contents/Helpers/"*
cp Sources/PerchApp/Resources/Info.plist "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist"
echo "$APP"
```

```bash
#!/bin/zsh
# Scripts/package-unsigned.sh
set -euo pipefail
Scripts/build-app.sh >/dev/null
ditto -c -k --keepParent .build/Perch.app .build/Perch-unsigned.zip
shasum -a 256 .build/Perch-unsigned.zip > .build/Perch-unsigned.zip.sha256
```

```bash
#!/bin/zsh
# Scripts/run-alpha-smoke.sh
set -euo pipefail
swift test
Scripts/build-app.sh >/dev/null
test -x .build/Perch.app/Contents/Helpers/perch-adapter-claude
test -x .build/Perch.app/Contents/Helpers/perch-adapter-codex
test -x .build/Perch.app/Contents/Helpers/perch-statusline-tap
! plutil -p .build/Perch.app/Contents/Info.plist | grep -Eq 'Accessibility|InputMonitoring|FullDiskAccess'
echo "alpha smoke: PASS"
```

Document manual real-tool checks in `docs/alpha-testing.md`: install preview, Hook trust, Claude start/permission/stop/failure, Codex CLI start/permission/stop, Codex Desktop start/permission/stop, source `unknown` behavior, 100-run terminal delivery for each tool surface, adapter kill/restart, multi-display placement, Reduced Motion, Focus suppression, quota refresh/stale state, uninstall, configuration diff verification, five idle CPU/RSS samples, and the persistence-directory audit.

- [ ] **Step 4: Run complete verification and record actual metrics**

Run:

```bash
chmod +x Scripts/package-unsigned.sh Scripts/run-alpha-smoke.sh
Scripts/run-alpha-smoke.sh
Scripts/package-unsigned.sh
swift test -c release
/usr/bin/time -p "$HOME/Library/Application Support/Perch/bin/perch-adapter-claude" emit < Tests/ClaudeAdapterTests/Fixtures/stop.json
.build/Perch.app/Contents/MacOS/PerchApp &
PERCH_PID=$!
sleep 60
: > .build/idle-metrics.txt
for i in {1..5}; do
  PIDS="$PERCH_PID $(pgrep -P "$PERCH_PID" || true)"
  ps -o %cpu=,rss= -p "$(echo "$PIDS" | xargs | tr ' ' ',')" |
    awk '{ cpu += $1; rss += $2 } END { print cpu, rss }' >> .build/idle-metrics.txt
  sleep 2
done
kill "$PERCH_PID"; wait "$PERCH_PID" 2>/dev/null || true
awk '{ cpu += $1; if ($2 > rss) rss = $2 } END {
  avg = cpu / NR; printf "idle avg CPU %.2f%%, max RSS %.1f MB\n", avg, rss / 1024;
  exit !(avg < 0.5 && rss < 102400)
}' .build/idle-metrics.txt
STATE_ROOT="$HOME/Library/Application Support/Perch"
if [[ -d "$STATE_ROOT" ]]; then
  test -z "$(find "$STATE_ROOT" -type f ! -path '*/bin/*' ! -name 'ownership.json' -print -quit)"
fi
```

Expected: all tests PASS, `alpha smoke: PASS`, ZIP checksum exists, release bridge execution p95 from 100 runs is below 50 ms, measured Hook-to-Land p95 is below 250 ms, idle average CPU is below 0.5%, combined app/adapter RSS stays below 100 MB, and no task/usage state file exists. Record real-tool and resource results in `docs/alpha-testing.md`. If a metric misses, do not weaken the threshold; record the failure and optimize before release.

- [ ] **Step 5: Commit the complete Alpha deliverable**

```bash
git add Scripts README.md docs/alpha-testing.md Tests/PerchCoreTests/AlphaAcceptanceTests.swift
git commit -m "docs: package and verify Perch AI Alpha"
```

---

## Completion Gate

Before declaring the plan complete, run:

```bash
git status --short
swift test -c release
Scripts/run-alpha-smoke.sh
Scripts/package-unsigned.sh
plutil -lint .build/Perch.app/Contents/Info.plist
```

Expected: clean worktree after committing, all release tests pass, smoke output is `alpha smoke: PASS`, the unsigned ZIP and checksum exist, the Info.plist is valid, and the acceptance record contains passing delivery, latency, idle-resource, persistence, install/uninstall, and three-tool checks.
