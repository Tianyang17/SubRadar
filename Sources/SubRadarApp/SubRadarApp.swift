import AppKit
import SubRadarCore
import SwiftUI
import UserNotifications

@MainActor
final class SubRadarAppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var windowCloseObserver: NSObjectProtocol?
    var settingsStore: AppSettingsStore?
    var onReopenMainWindow: (@MainActor () -> Void)?

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 确保通过 swift run 启动时也能正常拥有 Dock 图标、窗口聚焦、原生全屏与键盘输入权限
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.applicationIconImage = SubRadarAppIcon.makeDockIcon()
        NSApplication.shared.activate(ignoringOtherApps: true)
        for window in NSApplication.shared.windows where !(window is NSPanel) && window.styleMask.contains(.titled) {
            WindowFullScreenConfigurator.configure(window)
        }
        if Bundle.main.bundleIdentifier != nil {
            UNUserNotificationCenter.current().delegate = self
        }
        windowCloseObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(80))
                self?.syncWindowClosedPolicy()
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            onReopenMainWindow?()
        } else {
            sender.activate(ignoringOtherApps: true)
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        !(settingsStore?.keepRunningInMenuBar ?? true)
    }

    func syncWindowClosedPolicy() {
        let hasVisibleMainWindow = NSApplication.shared.windows.contains { win in
            win.isVisible && !(win is NSPanel) && win.styleMask.contains(.titled) && win.level == .normal
        }
        guard !hasVisibleMainWindow else { return }
        let keepRunning = settingsStore?.keepRunningInMenuBar ?? true
        let hideDock = settingsStore?.hideDockWhenWindowClosed ?? false
        if !keepRunning {
            NSApplication.shared.terminate(nil)
        } else if hideDock {
            NSApplication.shared.setActivationPolicy(.accessory)
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}

@main
struct SubRadarApp: App {
    @NSApplicationDelegateAdaptor(SubRadarAppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow

    @State private var mainViewModel: MainViewModel
    @State private var updateManager: AppUpdateManager
    @State private var activeEditorSheet: MainSplitView.EditorSheetMode?

    init() {
        let startupError: String?
        let container: AppContainer
        do {
            container = try AppContainer.makeProductionSync()
            startupError = nil
        } catch {
            startupError = "本地数据库初始化失败：\(error.localizedDescription)"
            do {
                container = try AppContainer.makeInMemoryProductionSync()
            } catch let fallbackError {
                fatalError("本地与内存数据库均初始化失败：\(fallbackError.localizedDescription)")
            }
        }
        let vm = MainViewModel(container: container)
        vm.errorMessage = startupError
        _mainViewModel = State(initialValue: vm)
        let updater = AppUpdateManager(settings: vm.settings)
        _updateManager = State(initialValue: updater)
        appDelegate.settingsStore = vm.settings
        updater.startLifecycleMonitoring()
    }

    var body: some Scene {
        Window("SubRadar", id: "main") {
            MainSplitView(
                viewModel: mainViewModel,
                activeEditorSheet: $activeEditorSheet,
                updateManager: updateManager
            )
            .radarTheme(mainViewModel.settings.themeMode)
            .onAppear {
                appDelegate.onReopenMainWindow = {
                    restoreMainWindowAndDock()
                }
            }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1120, height: 720)
        .commands {
            CommandGroup(after: .windowSize) {
                Button("进入 / 退出全屏") {
                    WindowFullScreenConfigurator.toggleMainWindowFullScreen()
                }
                .keyboardShortcut("f", modifiers: [.command, .control])
            }
        }

        MenuBarExtra {
            MenuBarExtraView(
                viewModel: mainViewModel,
                updateManager: updateManager,
                onOpenMainWindow: restoreMainWindowAndDock,
                onOpenNewSubscription: {
                    restoreMainWindowAndDock()
                    activeEditorSheet = .create(defaultTemplateId: nil)
                },
                onOpenSettings: {
                    restoreMainWindowAndDock()
                    mainViewModel.openSettings()
                }
            )
            .radarTheme(mainViewModel.settings.themeMode)
        } label: {
            Image(nsImage: SubRadarMenuBarIcon.templateImage)
        }
        .menuBarExtraStyle(.window)
    }

    @MainActor
    private func restoreMainWindowAndDock() {
        appDelegate.onReopenMainWindow = {
            restoreMainWindowAndDock()
        }
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.applicationIconImage = SubRadarAppIcon.makeDockIcon()
        if let existing = NSApplication.shared.windows.first(where: { win in
            !(win is NSPanel) && win.styleMask.contains(.titled) && win.level == .normal
        }) {
            WindowFullScreenConfigurator.configure(existing)
            existing.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: "main")
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
