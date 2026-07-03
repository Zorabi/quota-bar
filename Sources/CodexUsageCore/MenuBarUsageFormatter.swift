public enum MenuBarUsageFormatter {
    public static func format(_ snapshot: CodexUsageSnapshot?, settings: WidgetSettings) -> String {
        guard let snapshot else {
            return settings.showsCodexPrefix ? "Codex --" : "--"
        }

        let fiveHour = snapshot.window(.fiveHour)
        let sevenDay = snapshot.window(.sevenDay)

        let title: String
        switch settings.menuBarDensity {
        case .minimal:
            title = fiveHour.map { "\($0.remainingPercentage)%" } ?? "--"
        case .compact:
            title = [segment(for: fiveHour), segment(for: sevenDay)]
                .compactMap { $0 }
                .joined(separator: " | ")
        case .detailed:
            let base = [segment(for: fiveHour), segment(for: sevenDay)]
                .compactMap { $0 }
                .joined(separator: " | ")
            guard let resetText = fiveHour?.resetCountdownText else {
                title = base.isEmpty ? "--" : base
                return settings.showsCodexPrefix ? "Codex \(title)" : title
            }
            title = "\(base) | \(resetText)"
        }

        let fallbackTitle = title.isEmpty ? "--" : title
        return settings.showsCodexPrefix ? "Codex \(fallbackTitle)" : fallbackTitle
    }

    private static func segment(for window: UsageWindowSnapshot?) -> String? {
        guard let window else {
            return nil
        }
        return "\(window.kind.menuLabel) \(window.remainingPercentage)%"
    }
}
