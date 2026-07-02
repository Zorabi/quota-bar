import Foundation

public enum CodexRateLimitResponseMapper {
    public static func map(_ data: Data, now: Date = Date()) -> CodexUsageSnapshot? {
        guard let response = try? JSONDecoder().decode(AppServerRateLimitResponse.self, from: data) else {
            return nil
        }

        let limits = response.rateLimitsByLimitId?["codex"] ?? response.rateLimits
        let windows = [
            window(from: limits.primary, kind: .fiveHour, now: now),
            window(from: limits.secondary, kind: .sevenDay, now: now),
        ].compactMap { $0 }

        guard !windows.isEmpty else {
            return nil
        }

        return CodexUsageSnapshot(
            windows: windows,
            planName: formatPlanName(limits.planType),
            credits: parseCredits(limits.credits),
            resetCreditsAvailable: response.rateLimitResetCredits?.availableCount ?? 0,
            freshness: .live
        )
    }

    private static func window(
        from limitWindow: AppServerRateLimitWindow?,
        kind: UsageWindowKind,
        now: Date
    ) -> UsageWindowSnapshot? {
        guard let limitWindow else {
            return nil
        }

        let resetsIn: TimeInterval?
        if let resetsAt = limitWindow.resetsAt {
            resetsIn = max(TimeInterval(resetsAt) - now.timeIntervalSince1970, 0)
        } else {
            resetsIn = nil
        }

        return UsageWindowSnapshot(
            kind: kind,
            remainingPercentage: 100 - limitWindow.usedPercent,
            resetsIn: resetsIn,
            resetsAt: limitWindow.resetsAt.map { Date(timeIntervalSince1970: TimeInterval($0)) }
        )
    }

    private static func parseCredits(_ credits: AppServerCreditsSnapshot?) -> Int {
        guard let balance = credits?.balance else {
            return 0
        }
        return Int(balance) ?? 0
    }

    private static func formatPlanName(_ planType: String?) -> String {
        guard let planType, !planType.isEmpty else {
            return "--"
        }
        return planType.prefix(1).uppercased() + planType.dropFirst()
    }
}

private struct AppServerRateLimitResponse: Decodable {
    let rateLimits: AppServerRateLimitSnapshot
    let rateLimitsByLimitId: [String: AppServerRateLimitSnapshot]?
    let rateLimitResetCredits: AppServerRateLimitResetCredits?
}

private struct AppServerRateLimitSnapshot: Decodable {
    let primary: AppServerRateLimitWindow?
    let secondary: AppServerRateLimitWindow?
    let credits: AppServerCreditsSnapshot?
    let planType: String?
}

private struct AppServerRateLimitWindow: Decodable {
    let usedPercent: Int
    let resetsAt: Int?
}

private struct AppServerCreditsSnapshot: Decodable {
    let balance: String?
}

private struct AppServerRateLimitResetCredits: Decodable {
    let availableCount: Int
}
