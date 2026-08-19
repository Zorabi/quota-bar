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
