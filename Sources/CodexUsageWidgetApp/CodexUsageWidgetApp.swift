import AppKit
import CodexUsageCore
import SwiftUI

@main
struct CodexUsageWidgetApp: App {
    @NSApplicationDelegateAdaptor(AppCoordinator.self) private var coordinator

    var body: some Scene {
        Settings {
            SettingsPanelView(model: coordinator.model)
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
        NSApp.setActivationPolicy(.accessory)
        statusItemController = StatusItemController(
            model: model,
            desktopWidgetController: desktopWidgetController,
            settingsWindowController: settingsWindowController
        )
    }
}
