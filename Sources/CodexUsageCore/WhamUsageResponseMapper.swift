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
