import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusItemController {
    private let item: NSStatusItem
    private let model: AppModel
    private let desktopWidgetController: DesktopWidgetController
    private let settingsWindowController: SettingsWindowController
    private let popover = NSPopover()
    private var cancellables: Set<AnyCancellable> = []

    init(
        model: AppModel,
        desktopWidgetController: DesktopWidgetController,
        settingsWindowController: SettingsWindowController
    ) {
        self.model = model
        self.desktopWidgetController = desktopWidgetController
        self.settingsWindowController = settingsWindowController
        self.item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configure()
    }

    private func configure() {
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 356, height: 430)
        popover.contentViewController = NSHostingController(
            rootView: StatusPopoverView(
                model: model,
                onToggleWidget: { [weak self] in self?.toggleWidget() },
                onOpenSettings: { [weak self] in self?.openSettings() }
            )
        )

        if let button = item.button {
            button.image = nil
            button.action = #selector(togglePopover(_:))
            button.target = self
            button.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        }

        model.$snapshot.sink { [weak self] _ in
            DispatchQueue.main.async { self?.updateTitle() }
        }.store(in: &cancellables)
        model.$settings.sink { [weak self] _ in
            DispatchQueue.main.async { self?.updateTitle() }
            DispatchQueue.main.async { self?.desktopWidgetController.applySettings(self?.model.settings) }
        }.store(in: &cancellables)
        updateTitle()
    }

    private func updateTitle() {
        item.button?.title = model.menuBarTitle
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = item.button else {
            return
        }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func toggleWidget() {
        desktopWidgetController.toggle(model: model)
    }

    private func openSettings() {
        popover.performClose(nil)
        settingsWindowController.show(model: model) { [weak self] in
            self?.toggleWidget()
        }
    }
}
