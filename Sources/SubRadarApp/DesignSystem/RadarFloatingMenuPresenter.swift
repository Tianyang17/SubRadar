import AppKit
import SwiftUI

struct RightClickCaptureView: NSViewRepresentable {
    let onRightClick: (NSPoint) -> Void

    func makeNSView(context: Context) -> RightClickOverlayNSView {
        let view = RightClickOverlayNSView()
        view.onRightClick = onRightClick
        return view
    }

    func updateNSView(_ nsView: RightClickOverlayNSView, context: Context) {
        nsView.onRightClick = onRightClick
    }

    final class RightClickOverlayNSView: NSView {
        var onRightClick: ((NSPoint) -> Void)?

        override func hitTest(_ point: NSPoint) -> NSView? {
            guard let event = NSApp.currentEvent else { return nil }
            let isSecondary =
                event.type == .rightMouseDown
                || (event.type == .leftMouseDown && event.modifierFlags.contains(.control))
            guard isSecondary else { return nil }
            return bounds.contains(point) ? self : nil
        }

        override func rightMouseDown(with event: NSEvent) {
            onRightClick?(NSEvent.mouseLocation)
        }

        override func mouseDown(with event: NSEvent) {
            if event.modifierFlags.contains(.control) {
                onRightClick?(NSEvent.mouseLocation)
            } else {
                super.mouseDown(with: event)
            }
        }
    }
}

@MainActor
final class RadarAnchorRef {
    weak var view: NSView?

    func screenRect() -> NSRect? {
        guard let view, let window = view.window else { return nil }
        let inWindow = view.convert(view.bounds, to: nil)
        return window.convertToScreen(inWindow)
    }
}

struct RadarAnchorBackgroundView: NSViewRepresentable {
    let anchorRef: RadarAnchorRef

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        anchorRef.view = view
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        anchorRef.view = nsView
    }
}

/// 无边框无箭头通用浮动面板呈现器（统一替代原生 NSPopover / NSMenu 三角气泡）
@MainActor
public final class RadarFloatingPanelPresenter {
    public static let shared = RadarFloatingPanelPresenter()

    private var activePanel: NSPanel?
    private var activeAnchorToken: UUID?
    private var activeAnchorRect: NSRect?
    private var suppressedToggleToken: UUID?
    private var suppressedToggleUptime: TimeInterval = 0
    private var onDismissHandler: (() -> Void)?
    private var localEventMonitor: Any?
    private var resignObserver: NSObjectProtocol?

    private init() {}

    public func dismiss() {
        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
            self.localEventMonitor = nil
        }
        if let resignObserver {
            NotificationCenter.default.removeObserver(resignObserver)
            self.resignObserver = nil
        }
        activePanel?.orderOut(nil)
        activePanel = nil
        activeAnchorToken = nil
        activeAnchorRect = nil
        let handler = onDismissHandler
        onDismissHandler = nil
        handler?()
    }

    public func show<Content: View>(
        anchorRect: NSRect? = nil,
        screenPoint: NSPoint = NSEvent.mouseLocation,
        anchorToken: UUID? = nil,
        minWidth: CGFloat = 172,
        allowsKeyboardInput: Bool = false,
        palette: SubRadarPalette,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        if let anchorToken, anchorToken == activeAnchorToken, activePanel != nil {
            dismiss()
            return
        }
        if let anchorToken, anchorToken == suppressedToggleToken,
            ProcessInfo.processInfo.systemUptime - suppressedToggleUptime < 0.45
        {
            suppressedToggleToken = nil
            return
        }
        suppressedToggleToken = nil
        dismiss()
        NSApp.keyWindow?.makeFirstResponder(nil)

        let shadowPad: CGFloat = 16
        let wrappedView = content()
            .padding(5)
            .frame(minWidth: minWidth)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .circular)
                    .fill(palette.cardSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .circular)
                    .strokeBorder(palette.borderStrong, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(palette.isDark ? 0.52 : 0.14), radius: 16, x: 0, y: 8)
            .padding(shadowPad)
            .environment(\.radarPalette, palette)
            .preferredColorScheme(palette.colorScheme)

        let panel = FloatingPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.allowsKeyInput = allowsKeyboardInput
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .popUpMenu
        panel.hasShadow = false
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = true

        let hostingView = NSHostingView(rootView: wrappedView)
        panel.contentView = hostingView
        let fitting = hostingView.fittingSize
        let size = NSSize(width: max(minWidth + shadowPad * 2, fitting.width), height: fitting.height)
        hostingView.frame = NSRect(origin: .zero, size: size)

        let referencePoint = anchorRect.map { NSPoint(x: $0.midX, y: $0.midY) } ?? screenPoint
        let visibleFrame =
            NSScreen.screens.first(where: { $0.frame.contains(referencePoint) })?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        var originX: CGFloat
        var originY: CGFloat
        if let anchorRect {
            originX = anchorRect.minX - shadowPad
            originY = anchorRect.minY - (size.height - shadowPad) - 4
            if originY + shadowPad < visibleFrame.minY + 8 {
                originY = anchorRect.maxY - shadowPad + 4
            }
        } else {
            originX = screenPoint.x - shadowPad + 4
            originY = screenPoint.y - (size.height - shadowPad) - 4
            if originY + shadowPad < visibleFrame.minY + 8 {
                originY = screenPoint.y - shadowPad + 4
            }
        }

        if originX + size.width - shadowPad > visibleFrame.maxX - 8 {
            originX = visibleFrame.maxX - size.width + shadowPad - 8
        }
        if originX + shadowPad < visibleFrame.minX + 8 {
            originX = visibleFrame.minX - shadowPad + 8
        }

        panel.setFrame(NSRect(origin: NSPoint(x: originX, y: originY), size: size), display: true)
        if allowsKeyboardInput {
            panel.makeKeyAndOrderFront(nil)
        } else {
            panel.orderFrontRegardless()
        }
        activePanel = panel
        activeAnchorToken = anchorToken
        activeAnchorRect = anchorRect
        onDismissHandler = onDismiss

        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [
            .leftMouseDown, .rightMouseDown, .keyDown, .scrollWheel
        ]) { [weak self] event in
            guard let self, let panel = self.activePanel else { return event }
            if event.type == .keyDown && event.keyCode == 53 {
                self.dismiss()
                return nil
            }
            if event.type == .leftMouseDown || event.type == .rightMouseDown {
                let clickPoint = NSEvent.mouseLocation
                let interactiveRect = panel.frame.insetBy(dx: shadowPad, dy: shadowPad)
                if !interactiveRect.contains(clickPoint) {
                    if let anchorRect = self.activeAnchorRect, anchorRect.contains(clickPoint),
                        let token = self.activeAnchorToken
                    {
                        self.suppressedToggleToken = token
                        self.suppressedToggleUptime = ProcessInfo.processInfo.systemUptime
                    }
                    self.dismiss()
                }
            }
            if event.type == .scrollWheel {
                let pointer = NSEvent.mouseLocation
                let interactiveRect = panel.frame.insetBy(dx: shadowPad, dy: shadowPad)
                if !interactiveRect.contains(pointer) {
                    self.dismiss()
                }
            }
            return event
        }

        resignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.dismiss()
            }
        }
    }

    private final class FloatingPanel: NSPanel {
        var allowsKeyInput = false
        override var canBecomeKey: Bool { allowsKeyInput }
        override var canBecomeMain: Bool { false }
    }
}

/// 无边框无箭头浮动菜单呈现器（替代带有粗糙三角气泡的原生 NSPopover / NSMenu）
@MainActor
public final class RadarFloatingMenuPresenter {
    public static func show(
        items: [RadarContextMenuItem],
        palette: SubRadarPalette,
        screenPoint: NSPoint = NSEvent.mouseLocation
    ) {
        guard !items.isEmpty else { return }
        RadarFloatingPanelPresenter.shared.show(
            anchorRect: nil,
            screenPoint: screenPoint,
            minWidth: 168,
            palette: palette
        ) {
            RadarFloatingMenuContent(items: items, palette: palette) { selected in
                RadarFloatingPanelPresenter.shared.dismiss()
                Task { @MainActor in
                    selected.action()
                }
            }
        }
    }
}
