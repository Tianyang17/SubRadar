import AppKit
import SwiftUI

struct WindowFullScreenConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                Self.configure(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                Self.configure(window)
            }
        }
    }

    @MainActor
    static func configure(_ window: NSWindow) {
        window.collectionBehavior.remove(.fullScreenNone)
        window.collectionBehavior.remove(.fullScreenAuxiliary)
        if !window.collectionBehavior.contains(.fullScreenPrimary) {
            window.collectionBehavior.insert(.fullScreenPrimary)
        }
        if !window.styleMask.contains(.resizable) {
            window.styleMask.insert(.resizable)
        }
    }

    @MainActor
    static func toggleMainWindowFullScreen() {
        if let keyWindow = NSApplication.shared.keyWindow {
            configure(keyWindow)
            keyWindow.toggleFullScreen(nil)
        } else if let mainWindow = NSApplication.shared.windows.first(where: {
            !($0 is NSPanel) && $0.styleMask.contains(.titled) && $0.level == .normal
        }) {
            configure(mainWindow)
            mainWindow.toggleFullScreen(nil)
        }
    }
}
