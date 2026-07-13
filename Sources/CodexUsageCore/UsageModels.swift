import Foundation

public enum UsageWindowKind: String, CaseIterable, Codable, Sendable {
    case fiveHour
    case sevenDay

    public var menuLabel: String {
        switch self {
        case .fiveHour:
            return "5h"
        case .sevenDay:
            return "7d"
        }
    }

    public var displayTitle: String {
        switch self {
        case .fiveHour:
            return "5 小时窗口"
        case .sevenDay:
            return "7 天窗口"
        }
    }
}

public struct UsageWindowSnapshot: Codable, Equatable, Sendable {
    public let kind: UsageWindowKind
    public let remainingPercentage: Int
    public let resetsIn: TimeInterval?
    public let resetsAt: Date?

    public init(
        kind: UsageWindowKind,
        remainingPercentage: Int,
        resetsIn: TimeInterval?,
        resetsAt: Date? = nil
    ) {
        self.kind = kind
        self.remainingPercentage = min(max(remainingPercentage, 0), 100)
        self.resetsIn = resetsIn
        self.resetsAt = resetsAt
    }

    public var usedPercentage: Int {
        100 - remainingPercentage
    }

    public var resetCountdownText: String {
        guard let resetsIn else {
            return "--:--"
        }

        let totalMinutes = max(Int(resetsIn / 60), 0)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return String(format: "%02d:%02d", hours, minutes)
    }

    public var readableResetCountdownText: String {
        guard let resetsIn else {
            return "--"
        }

        let totalMinutes = max(Int(resetsIn / 60), 0)
        let days = totalMinutes / (24 * 60)
        let hours = (totalMinutes % (24 * 60)) / 60
        let minutes = totalMinutes % 60

        if days > 0 {
            return hours > 0 ? "\(days) 天 \(hours) 小时" : "\(days) 天"
        }
        if hours > 0 {
            return minutes > 0 ? "\(hours) 小时 \(minutes) 分钟" : "\(hours) 小时"
        }
        return "\(minutes) 分钟"
    }

    public func resetDateText(timeZone: TimeZone = .current) -> String {
        guard let resetsAt else {
            return "--"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: resetsAt)
    }
}

public enum UsageFreshness: String, CaseIterable, Codable, Sendable {
    case live
    case stale
    case unavailable

    public var displayText: String {
        switch self {
        case .live:
            return "Live"
        case .stale:
            return "已过期"
        case .unavailable:
            return "不可用"
        }
    }
}

public struct CodexUsageSnapshot: Codable, Equatable, Sendable {
    public let windows: [UsageWindowSnapshot]
    public let planName: String
    public let credits: Int
    public let resetCreditsAvailable: Int
    public let freshness: UsageFreshness

    public init(
        windows: [UsageWindowSnapshot],
        planName: String,
        credits: Int,
        resetCreditsAvailable: Int = 0,
        freshness: UsageFreshness
    ) {
        self.windows = windows
        self.planName = planName
        self.credits = credits
        self.resetCreditsAvailable = resetCreditsAvailable
        self.freshness = freshness
    }

    public func window(_ kind: UsageWindowKind) -> UsageWindowSnapshot? {
        windows.first { $0.kind == kind }
    }

    public var preferredWindow: UsageWindowSnapshot? {
        window(.fiveHour) ?? window(.sevenDay)
    }
}

public enum DetailLevel: String, CaseIterable, Codable, Sendable {
    case concise
    case standard
    case rich

    public var displayText: String {
        switch self {
        case .concise:
            return "简洁"
        case .standard:
            return "标准"
        case .rich:
            return "丰富"
        }
    }
}

public enum MenuBarDensity: String, CaseIterable, Codable, Sendable {
    case minimal
    case compact
    case detailed

    public var displayText: String {
        switch self {
        case .minimal:
            return "极简"
        case .compact:
            return "紧凑"
        case .detailed:
            return "详细"
        }
    }
}

public enum AppearanceMode: String, CaseIterable, Codable, Sendable {
    case system
    case dark
    case light

    public var displayText: String {
        switch self {
        case .system:
            return "系统"
        case .dark:
            return "深色"
        case .light:
            return "浅色"
        }
    }
}

public struct WidgetSettings: Codable, Equatable, Sendable {
    public var refreshIntervalMinutes: Int
    public var detailLevel: DetailLevel
    public var menuBarDensity: MenuBarDensity
    public var appearanceMode: AppearanceMode
    public var showsCodexPrefix: Bool
    public var pinsWidgetToDesktop: Bool
    public var showsStatusItem: Bool
    public var showsDockIcon: Bool
    public var launchesAtLogin: Bool

    public init(
        refreshIntervalMinutes: Int = 5,
        detailLevel: DetailLevel = .rich,
        menuBarDensity: MenuBarDensity = .compact,
        appearanceMode: AppearanceMode = .system,
        showsCodexPrefix: Bool = false,
        pinsWidgetToDesktop: Bool = false,
        showsStatusItem: Bool = true,
        showsDockIcon: Bool = false,
        launchesAtLogin: Bool = false
    ) {
        self.refreshIntervalMinutes = refreshIntervalMinutes
        self.detailLevel = detailLevel
        self.menuBarDensity = menuBarDensity
        self.appearanceMode = appearanceMode
        self.showsCodexPrefix = showsCodexPrefix
        self.pinsWidgetToDesktop = pinsWidgetToDesktop
        self.showsStatusItem = showsStatusItem
        self.showsDockIcon = showsDockIcon
        self.launchesAtLogin = launchesAtLogin
    }

    public func normalizedForPresentation() -> WidgetSettings {
        guard needsPresentationNormalization else {
            return self
        }

        var settings = self
        settings.showsDockIcon = true
        return settings
    }

    public var needsPresentationNormalization: Bool {
        !showsStatusItem && !showsDockIcon
    }

    private enum CodingKeys: String, CodingKey {
        case refreshIntervalMinutes
        case detailLevel
        case menuBarDensity
        case appearanceMode
        case showsCodexPrefix
        case pinsWidgetToDesktop
        case showsStatusItem
        case showsDockIcon
        case launchesAtLogin
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            refreshIntervalMinutes: try container.decodeIfPresent(Int.self, forKey: .refreshIntervalMinutes) ?? 5,
            detailLevel: try container.decodeIfPresent(DetailLevel.self, forKey: .detailLevel) ?? .rich,
            menuBarDensity: try container.decodeIfPresent(MenuBarDensity.self, forKey: .menuBarDensity) ?? .compact,
            appearanceMode: try container.decodeIfPresent(AppearanceMode.self, forKey: .appearanceMode) ?? .system,
            showsCodexPrefix: try container.decodeIfPresent(Bool.self, forKey: .showsCodexPrefix) ?? false,
            pinsWidgetToDesktop: try container.decodeIfPresent(Bool.self, forKey: .pinsWidgetToDesktop) ?? false,
            showsStatusItem: try container.decodeIfPresent(Bool.self, forKey: .showsStatusItem) ?? true,
            showsDockIcon: try container.decodeIfPresent(Bool.self, forKey: .showsDockIcon) ?? false,
            launchesAtLogin: try container.decodeIfPresent(Bool.self, forKey: .launchesAtLogin) ?? false
        )
    }
}
