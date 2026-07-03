import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var onClose: () -> Void = {}

    var isVisible: Bool {
        window?.isVisible == true
    }

    func show(
        model: AppModel,
        onToggleWidget: @escaping () -> Void = {},
        onClose: @escaping () -> Void = {}
    ) {
        self.onClose = onClose
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.contentView = NSHostingView(rootView: SettingsPanelView(model: model, onToggleWidget: onToggleWidget))
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 620, height: 560)
        window.title = "QuotaBar 设置"
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}
