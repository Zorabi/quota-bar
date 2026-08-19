import XCTest
@testable import CodexUsageCore

final class UsageModelTests: XCTestCase {
    func testWindowSnapshotClampsPercentageIntoValidRange() {
        let low = UsageWindowSnapshot(kind: .fiveHour, remainingPercentage: -20, resetsIn: nil)
        let high = UsageWindowSnapshot(kind: .sevenDay, remainingPercentage: 140, resetsIn: nil)

        XCTAssertEqual(low.remainingPercentage, 0)
        XCTAssertEqual(high.remainingPercentage, 100)
    }

    func testResetTimeFormatsAsHoursAndMinutes() {
        let window = UsageWindowSnapshot(kind: .fiveHour, remainingPercentage: 52, resetsIn: 8_820)

        XCTAssertEqual(window.resetCountdownText, "02:27")
        XCTAssertEqual(window.readableResetCountdownText, "2 小时 27 分钟")
    }

    func testReadableResetCountdownFormatsDaysAndHours() {
        let window = UsageWindowSnapshot(kind: .sevenDay, remainingPercentage: 52, resetsIn: 176_400)

        XCTAssertEqual(window.readableResetCountdownText, "2 天 1 小时")
    }

    func testResetDateFormatsSpecificAvailableDate() {
        let window = UsageWindowSnapshot(
            kind: .fiveHour,
            remainingPercentage: 52,
            resetsIn: 8_820,
            resetsAt: Date(timeIntervalSince1970: 1_782_970_267)
        )

        XCTAssertEqual(window.resetDateText(timeZone: TimeZone(secondsFromGMT: 8 * 3600)!), "07-02 13:31")
    }

    func testRefreshScheduleFormatterShowsReadableRemainingTime() {
        let now = Date(timeIntervalSince1970: 1_782_970_000)
        let next = now.addingTimeInterval(268)

        XCTAssertEqual(RefreshScheduleFormatter.remainingText(until: next, now: now), "4 分 28 秒")
    }

    func testRefreshScheduleFormatterClampsExpiredRemainingTime() {
        let now = Date(timeIntervalSince1970: 1_782_970_000)
        let next = now.addingTimeInterval(-12)

        XCTAssertEqual(RefreshScheduleFormatter.remainingText(until: next, now: now), "即将刷新")
    }

    func testRefreshScheduleFormatterFormatsClockTime() {
        let date = Date(timeIntervalSince1970: 1_782_970_267)

        XCTAssertEqual(
            RefreshScheduleFormatter.clockText(date, timeZone: TimeZone(secondsFromGMT: 8 * 3600)!),
            "13:31"
        )
    }

    func testMockProviderSuppliesBothCodexUsageWindows() {
        guard
        case .success(let snapshot) = MockUsageProvider().fetchUsage() else {
            XCTFail("MockUsageProvider 应返回成功结果")
            return
        }

        XCTAssertEqual(snapshot.window(.fiveHour)?.remainingPercentage, 52)
        XCTAssertEqual(snapshot.window(.sevenDay)?.remainingPercentage, 42)
        XCTAssertEqual(snapshot.planName, "Plus")
        XCTAssertEqual(snapshot.credits, 0)
        XCTAssertEqual(snapshot.resetCreditsAvailable, 3)
        XCTAssertEqual(snapshot.freshness, .live)
    }

    func testWidgetSettingsStorePersistsSettingsToDisk() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = WidgetSettingsStore(url: directory.appendingPathComponent("settings.json"))
        let settings = WidgetSettings(
            refreshIntervalMinutes: 15,
            detailLevel: .standard,
            menuBarDensity: .detailed,
            appearanceMode: .dark,
            showsCodexPrefix: true,
            pinsWidgetToDesktop: true,
            showsStatusItem: false,
            showsDockIcon: true,
            launchesAtLogin: true
        )

        store.save(settings)

        XCTAssertEqual(store.load(), settings)
        try? FileManager.default.removeItem(at: directory)
    }

    func testWidgetSettingsDecodesOlderSettingsWithPresentationDefaults() throws {
        let json = """
        {
          "refreshIntervalMinutes": 15,
          "detailLevel": "standard",
          "menuBarDensity": "detailed",
          "showsCodexPrefix": true,
          "pinsWidgetToDesktop": true
        }
        """

        let settings = try JSONDecoder().decode(WidgetSettings.self, from: Data(json.utf8))

        XCTAssertTrue(settings.showsStatusItem)
        XCTAssertFalse(settings.showsDockIcon)
        XCTAssertFalse(settings.launchesAtLogin)
        XCTAssertEqual(settings.appearanceMode, .system)
    }

    func testAppearanceModeProvidesChineseDisplayText() {
        XCTAssertEqual(AppearanceMode.system.displayText, "系统")
        XCTAssertEqual(AppearanceMode.dark.displayText, "深色")
        XCTAssertEqual(AppearanceMode.light.displayText, "浅色")
    }

    func testWidgetSettingsKeepsDockVisibleWhenStatusItemIsHiddenWithoutDockSetting() {
        let settings = WidgetSettings(showsStatusItem: false, showsDockIcon: false)

        let normalized = settings.normalizedForPresentation()

        XCTAssertFalse(normalized.showsStatusItem)
        XCTAssertTrue(normalized.showsDockIcon)
    }

    func testWidgetSettingsOnlyNeedsPresentationNormalizationWhenBothEntriesAreHidden() {
        XCTAssertFalse(WidgetSettings(showsStatusItem: true, showsDockIcon: false).needsPresentationNormalization)
        XCTAssertFalse(WidgetSettings(showsStatusItem: false, showsDockIcon: true).needsPresentationNormalization)
        XCTAssertTrue(WidgetSettings(showsStatusItem: false, showsDockIcon: false).needsPresentationNormalization)
    }

    func testWidgetSettingsStoreUsesQuotaBarApplicationSupportDirectory() {
        let url = WidgetSettingsStore.defaultURL

        XCTAssertEqual(url.deletingLastPathComponent().lastPathComponent, "QuotaBar")
        XCTAssertEqual(url.lastPathComponent, "settings.json")
    }

    func testSharedUsageSnapshotStoreUsesQuotaBarApplicationSupportDirectory() {
        let url = SharedUsageSnapshotStore.snapshotURL

        XCTAssertEqual(url.deletingLastPathComponent().lastPathComponent, "QuotaBar")
        XCTAssertEqual(url.lastPathComponent, "usage.json")
    }

    func testWidgetSettingsStoreReturnsNilForInvalidSettingsFile() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let url = directory.appendingPathComponent("settings.json")
        let store = WidgetSettingsStore(url: url)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: url)

        XCTAssertNil(store.load())
        try? FileManager.default.removeItem(at: directory)
    }

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
            parseISO8601Date("2026-07-26T23:26:04.000Z"),
            parseISO8601Date("2026-08-01T19:02:09.000Z"),
        ])
        XCTAssertEqual(snapshot.fetchedAt, Date(timeIntervalSince1970: 1_783_080_000))
    }

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

    func testResetCreditExpiryDisplayFormatterUsesLocalDateAndClockText() {
        let date = parseISO8601Date("2026-07-26T23:26:04.000Z")
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

    private func parseISO8601Date(_ value: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value)!
    }
}
