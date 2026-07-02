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
        let snapshot = MockUsageProvider().fetchUsage()

        XCTAssertEqual(snapshot?.window(.fiveHour)?.remainingPercentage, 52)
        XCTAssertEqual(snapshot?.window(.sevenDay)?.remainingPercentage, 42)
        XCTAssertEqual(snapshot?.planName, "Plus")
        XCTAssertEqual(snapshot?.credits, 0)
        XCTAssertEqual(snapshot?.resetCreditsAvailable, 3)
        XCTAssertEqual(snapshot?.freshness, .live)
    }

    func testRateLimitMapperUsesCurrentCodexAccountPayload() throws {
        let json = """
        {
          "rateLimits": {
            "limitId": "codex",
            "primary": {"usedPercent": 26, "windowDurationMins": 300, "resetsAt": 1782970267},
            "secondary": {"usedPercent": 37, "windowDurationMins": 10080, "resetsAt": 1783475012},
            "credits": {"hasCredits": false, "unlimited": false, "balance": "0"},
            "planType": "plus"
          },
          "rateLimitsByLimitId": {
            "codex": {
              "limitId": "codex",
              "primary": {"usedPercent": 26, "windowDurationMins": 300, "resetsAt": 1782970267},
              "secondary": {"usedPercent": 37, "windowDurationMins": 10080, "resetsAt": 1783475012},
              "credits": {"hasCredits": false, "unlimited": false, "balance": "0"},
              "planType": "plus"
            }
          },
          "rateLimitResetCredits": {"availableCount": 3}
        }
        """

        let snapshot = try XCTUnwrap(CodexRateLimitResponseMapper.map(
            Data(json.utf8),
            now: Date(timeIntervalSince1970: 1782960000)
        ))

        XCTAssertEqual(snapshot.window(.fiveHour)?.remainingPercentage, 74)
        XCTAssertEqual(snapshot.window(.fiveHour)?.resetsIn, 10_267)
        XCTAssertEqual(snapshot.window(.sevenDay)?.remainingPercentage, 63)
        XCTAssertEqual(snapshot.window(.sevenDay)?.resetsIn, 515_012)
        XCTAssertEqual(snapshot.planName, "Plus")
        XCTAssertEqual(snapshot.credits, 0)
        XCTAssertEqual(snapshot.resetCreditsAvailable, 3)
        XCTAssertEqual(snapshot.freshness, .live)
    }
}
