import AppKit
import CodexUsageCore
import SwiftUI

@main
struct CodexUsageWidgetApp: App {
    @NSApplicationDelegateAdaptor(AppCoordinator.self) private var coordinator

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("QuotaBar 设置") {
                    coordinator.openSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}

@MainActor
final class AppCoordinator: NSObject, NSApplicationDelegate {
    let model = AppModel(provider: CodexAppServerUsageProvider())
    private let desktopWidgetController = DesktopWidgetController()
    private let settingsWindowController = SettingsWindowController()
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        syncLaunchAtLoginStatus()
        applyActivationPolicy(model.settings)
        statusItemController = StatusItemController(
            model: model,
            desktopWidgetController: desktopWidgetController,
            onOpenSettings: { [weak self] in
                self?.openSettings()
            }
        )
    }

    private func syncLaunchAtLoginStatus() {
        model.updateSettings { settings in
            settings.launchesAtLogin = LaunchAtLoginController.isEnabled
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            openSettings()
        }
        return true
    }

    func openSettings() {
        applyActivationPolicy(model.settings, keepsSettingsVisible: true)
        settingsWindowController.show(model: model) { [weak self] in
            guard let self else {
                return
            }
            self.desktopWidgetController.toggle(model: self.model)
        } onClose: { [weak self] in
            guard let self else {
                return
            }
            self.applyActivationPolicy(self.model.settings, keepsSettingsVisible: false)
        }
    }

    private func applyActivationPolicy(
        _ settings: WidgetSettings,
        keepsSettingsVisible: Bool? = nil
    ) {
        let settingsIsVisible = keepsSettingsVisible ?? settingsWindowController.isVisible
        let policy: NSApplication.ActivationPolicy = settings.showsDockIcon || settingsIsVisible ? .regular : .accessory
        NSApp.setActivationPolicy(policy)
        if policy == .regular {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

}
