import XCTest
@testable import CodexUsageCore

final class MenuBarUsageFormatterTests: XCTestCase {
    func testCompactFormatUsesPipeSeparatorWithoutIconText() {
        let snapshot = CodexUsageSnapshot(
            windows: [
                UsageWindowSnapshot(kind: .fiveHour, remainingPercentage: 52, resetsIn: 8_820),
                UsageWindowSnapshot(kind: .sevenDay, remainingPercentage: 42, resetsIn: 345_600),
            ],
            planName: "Plus",
            credits: 0,
            freshness: .live
        )
        let settings = WidgetSettings(
            refreshIntervalMinutes: 5,
            detailLevel: .rich,
            menuBarDensity: .compact
        )

        XCTAssertEqual(MenuBarUsageFormatter.format(snapshot, settings: settings), "5h 52% | 7d 42%")
    }

    func testCompactFormatCanIncludeCodexPrefix() {
        let snapshot = CodexUsageSnapshot(
            windows: [
                UsageWindowSnapshot(kind: .fiveHour, remainingPercentage: 52, resetsIn: 8_820),
                UsageWindowSnapshot(kind: .sevenDay, remainingPercentage: 42, resetsIn: 345_600),
            ],
            planName: "Plus",
            credits: 0,
            resetCreditsAvailable: 3,
            freshness: .live
        )
        let settings = WidgetSettings(
            refreshIntervalMinutes: 5,
            detailLevel: .rich,
            menuBarDensity: .compact,
            showsCodexPrefix: true
        )

        XCTAssertEqual(MenuBarUsageFormatter.format(snapshot, settings: settings), "Codex 5h 52% | 7d 42%")
    }

    func testDetailedFormatAddsResetTimeAfterPipeSeparator() {
        let snapshot = CodexUsageSnapshot(
            windows: [
                UsageWindowSnapshot(kind: .fiveHour, remainingPercentage: 52, resetsIn: 8_820),
                UsageWindowSnapshot(kind: .sevenDay, remainingPercentage: 42, resetsIn: 345_600),
            ],
            planName: "Plus",
            credits: 0,
            freshness: .live
        )
        let settings = WidgetSettings(
            refreshIntervalMinutes: 5,
            detailLevel: .rich,
            menuBarDensity: .detailed
        )

        XCTAssertEqual(MenuBarUsageFormatter.format(snapshot, settings: settings), "5h 52% | 7d 42% | 02:27")
    }

    func testUnavailableSnapshotShowsCodexPlaceholder() {
        let settings = WidgetSettings(
            refreshIntervalMinutes: 5,
            detailLevel: .standard,
            menuBarDensity: .compact
        )

        XCTAssertEqual(MenuBarUsageFormatter.format(nil, settings: settings), "Codex --")
    }
}
