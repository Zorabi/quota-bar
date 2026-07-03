import Foundation

public struct WidgetSettingsStore: Sendable {
    public let url: URL

    public init(url: URL = Self.defaultURL) {
        self.url = url
    }

    public static var defaultURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base
            .appendingPathComponent("QuotaBar", isDirectory: true)
            .appendingPathComponent("settings.json")
    }

    public func save(_ settings: WidgetSettings) {
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(settings)
            try data.write(to: url, options: [.atomic])
        } catch {
            // 设置保存失败不影响主应用继续使用当前会话配置。
        }
    }

    public func load() -> WidgetSettings? {
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(WidgetSettings.self, from: data)
        } catch {
            return nil
        }
    }
}
