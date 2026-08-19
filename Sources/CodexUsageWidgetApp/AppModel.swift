import CodexUsageCore
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var snapshot: CodexUsageSnapshot?
    @Published private(set) var lastRefreshedAt: Date?
    @Published private(set) var nextRefreshAt: Date?
    @Published private(set) var isRefreshing = false
    @Published private(set) var resetCreditExpirySnapshot: ResetCreditExpirySnapshot?
    @Published private(set) var resetCreditExpiryErrorText: String?
    @Published private(set) var usageErrorText: String?
    @Published private(set) var isQueryingResetCreditExpirations = false
    @Published private(set) var settings: WidgetSettings {
        didSet {
            settingsStore.save(settings)
            restartTimer()
        }
    }

    private let provider: UsageProviding
    private let resetCreditExpiryProvider: ResetCreditExpiryProviding
    private let settingsStore: WidgetSettingsStore
    private var timer: Timer?

    init(
        provider: UsageProviding = MockUsageProvider(),
        resetCreditExpiryProvider: ResetCreditExpiryProviding = ResetCreditExpiryProvider(),
        settingsStore: WidgetSettingsStore = WidgetSettingsStore()
    ) {
        self.provider = provider
        self.resetCreditExpiryProvider = resetCreditExpiryProvider
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
            let result = provider.fetchUsage()
            await MainActor.run {
                switch result {
                case .success(let snapshot):
                    self.snapshot = snapshot
                    self.lastRefreshedAt = Date()
                    self.usageErrorText = nil
                    SharedUsageSnapshotStore.save(snapshot)
                case .failure(let error):
                    self.usageErrorText = UsageProviderErrorDisplayFormatter.errorText(error)
                }
                self.isRefreshing = false
                self.restartTimer()
            }
        }
    }

    func queryResetCreditExpirations() {
        guard !isQueryingResetCreditExpirations else {
            return
        }
        isQueryingResetCreditExpirations = true
        resetCreditExpiryErrorText = nil
        let provider = resetCreditExpiryProvider
        Task.detached {
            let result = provider.fetchExpirySnapshot()
            await MainActor.run {
                switch result {
                case .success(let snapshot):
                    self.resetCreditExpirySnapshot = snapshot
                    self.resetCreditExpiryErrorText = nil
                case .failure(let error):
                    self.resetCreditExpiryErrorText = ResetCreditExpiryDisplayFormatter.errorText(error)
                }
                self.isQueryingResetCreditExpirations = false
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
