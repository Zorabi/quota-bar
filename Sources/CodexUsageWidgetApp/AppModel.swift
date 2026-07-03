import CodexUsageCore
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var snapshot: CodexUsageSnapshot?
    @Published private(set) var lastRefreshedAt: Date?
    @Published private(set) var nextRefreshAt: Date?
    @Published private(set) var isRefreshing = false
    @Published private(set) var settings: WidgetSettings {
        didSet {
            settingsStore.save(settings)
            restartTimer()
        }
    }

    private let provider: UsageProviding
    private let settingsStore: WidgetSettingsStore
    private var timer: Timer?

    init(
        provider: UsageProviding = MockUsageProvider(),
        settingsStore: WidgetSettingsStore = WidgetSettingsStore()
    ) {
        self.provider = provider
        self.settingsStore = settingsStore
        self.settings = (settingsStore.load() ?? WidgetSettings()).normalizedForPresentation()
        self.snapshot = nil
        refresh()
    }

    var menuBarTitle: String {
        MenuBarUsageFormatter.format(snapshot, settings: settings)
    }

    func updateSettings(_ update: (inout WidgetSettings) -> Void) {
        var nextSettings = settings
        update(&nextSettings)
        settings = nextSettings.normalizedForPresentation()
    }

    func refresh() {
        guard !isRefreshing else {
            return
        }
        isRefreshing = true
        let provider = provider
        Task.detached {
            let snapshot = provider.fetchUsage()
            await MainActor.run {
                if let snapshot {
                    self.snapshot = snapshot
                    self.lastRefreshedAt = Date()
                    SharedUsageSnapshotStore.save(snapshot)
                }
                self.isRefreshing = false
                self.restartTimer()
            }
        }
    }

    private func restartTimer() {
        timer?.invalidate()
        let interval = TimeInterval(settings.refreshIntervalMinutes * 60)
        nextRefreshAt = Date().addingTimeInterval(interval)

        let timer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
}
