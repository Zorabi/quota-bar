import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusItemController {
    private let item: NSStatusItem
    private let model: AppModel
    private let desktopWidgetController: DesktopWidgetController
    private let onOpenSettings: () -> Void
    private let popover = NSPopover()
    private var outsideClickMonitor: Any?
    private var currentTitle = ""
    private var cancellables: Set<AnyCancellable> = []

    init(
        model: AppModel,
        desktopWidgetController: DesktopWidgetController,
        onOpenSettings: @escaping () -> Void
    ) {
        self.model = model
        self.desktopWidgetController = desktopWidgetController
        self.onOpenSettings = onOpenSettings
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
            DispatchQueue.main.async { self?.applySettings() }
        }.store(in: &cancellables)
        NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.closePopover(nil) }
            }
            .store(in: &cancellables)
        applySettings()
    }

    private func applySettings() {
        if !model.settings.showsStatusItem {
            closePopover(nil)
        }

        popover.appearance = model.settings.appearanceMode.nsAppearance
        item.isVisible = true
        if model.settings.showsStatusItem {
            item.length = NSStatusItem.variableLength
            updateTitle()
        } else {
            item.button?.title = ""
            item.length = 0
        }
        desktopWidgetController.applySettings(model.settings)
    }

    private func updateTitle() {
        let title = model.menuBarTitle
        guard title != currentTitle else {
            return
        }
        currentTitle = title
        item.button?.title = title
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = item.button else {
            return
        }

        if popover.isShown {
            closePopover(sender)
        } else {
            showPopover(relativeTo: button)
        }
    }

    private func showPopover(relativeTo button: NSStatusBarButton) {
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
        startOutsideClickMonitor()
    }

    private func closePopover(_ sender: Any?) {
        stopOutsideClickMonitor()
        popover.performClose(sender)
    }

    private func startOutsideClickMonitor() {
        guard outsideClickMonitor == nil else {
            return
        }

        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                self?.closePopover(nil)
            }
        }
    }

    private func stopOutsideClickMonitor() {
        guard let outsideClickMonitor else {
            return
        }

        NSEvent.removeMonitor(outsideClickMonitor)
        self.outsideClickMonitor = nil
    }

    private func toggleWidget() {
        desktopWidgetController.toggle(model: model)
    }

    private func openSettings() {
        closePopover(nil)
        onOpenSettings()
    }
}
