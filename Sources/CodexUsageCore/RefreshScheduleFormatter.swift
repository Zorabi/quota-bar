import Foundation

public enum RefreshScheduleFormatter {
    public static func remainingText(until nextRefreshAt: Date?, now: Date = Date()) -> String {
        guard let nextRefreshAt else {
            return "--"
        }

        let seconds = max(Int(nextRefreshAt.timeIntervalSince(now)), 0)
        if seconds == 0 {
            return "即将刷新"
        }

        let minutes = seconds / 60
        let remainderSeconds = seconds % 60
        if minutes > 0 {
            return "\(minutes) 分 \(remainderSeconds) 秒"
        }
        return "\(remainderSeconds) 秒"
    }

    public static func clockText(_ date: Date?, timeZone: TimeZone = .current) -> String {
        guard let date else {
            return "--:--"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
