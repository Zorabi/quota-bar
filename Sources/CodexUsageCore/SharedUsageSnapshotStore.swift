import Foundation

public enum SharedUsageSnapshotStore {
    public static var snapshotURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base
            .appendingPathComponent("CodexUsageWidget", isDirectory: true)
            .appendingPathComponent("usage.json")
    }

    public static func save(_ snapshot: CodexUsageSnapshot) {
        let url = snapshotURL
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: url, options: [.atomic])
        } catch {
            // 快照缓存失败不影响主应用显示。
        }
    }

    public static func load() -> CodexUsageSnapshot? {
        do {
            let data = try Data(contentsOf: snapshotURL)
            return try JSONDecoder().decode(CodexUsageSnapshot.self, from: data)
        } catch {
            return nil
        }
    }
}
