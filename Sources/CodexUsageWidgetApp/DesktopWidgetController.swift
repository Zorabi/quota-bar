import AppKit
import Combine
import CodexUsageCore
import SwiftUI

@MainActor
final class DesktopWidgetController {
    private var panel: NSPanel?
    private weak var hostingView: NSHostingView<DesktopWidgetView>?
    private var resizeObservation: AnyCancellable?
    private(set) var isVisible = false

    func show(model: AppModel) {
        if let panel {
            configureLevel(panel, settings: model.settings)
            if let hostingView {
                resizePanel(panel, toFit: hostingView)
            }
            panel.orderFrontRegardless()
            isVisible = true
            return
        }

        let panel = NSPanel(
            contentRect: defaultFrame(),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        let hostingView = NSHostingView(rootView: DesktopWidgetView(model: model))
        panel.contentView = hostingView
        self.hostingView = hostingView
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.isOpaque = false
        configureLevel(panel, settings: model.settings)
        resizeObservation = model.objectWillChange.sink { [weak self, weak panel, weak hostingView] _ in
            DispatchQueue.main.async {
                guard let self, let panel, let hostingView, panel.isVisible else {
                    return
                }
                self.resizePanel(panel, toFit: hostingView)
            }
        }
        resizePanel(panel, toFit: hostingView)
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.orderFrontRegardless()
        self.panel = panel
        isVisible = true
    }

    func hide() {
        panel?.orderOut(nil)
        isVisible = false
    }

    func toggle(model: AppModel) {
        if isVisible {
            hide()
        } else {
            show(model: model)
        }
    }

    func applySettings(_ settings: WidgetSettings?) {
        guard let panel, let settings else {
            return
        }
        configureLevel(panel, settings: settings)
    }

    private func configureLevel(_ panel: NSPanel, settings: WidgetSettings) {
        if settings.pinsWidgetToDesktop {
            panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        } else {
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        }
    }

    private func defaultFrame() -> NSRect {
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let size = NSSize(width: 376, height: 1)
        return NSRect(
            x: visibleFrame.maxX - size.width - 28,
            y: visibleFrame.maxY - size.height - 42,
            width: size.width,
            height: size.height
        )
    }

    private func resizePanel(_ panel: NSPanel, toFit hostingView: NSHostingView<DesktopWidgetView>) {
        hostingView.layoutSubtreeIfNeeded()
        let fittingSize = hostingView.fittingSize
        let currentFrame = panel.frame
        let newFrame = NSRect(
            x: currentFrame.minX,
            y: currentFrame.maxY - fittingSize.height,
            width: fittingSize.width,
            height: fittingSize.height
        )
        panel.setFrame(newFrame, display: true)
    }
}
