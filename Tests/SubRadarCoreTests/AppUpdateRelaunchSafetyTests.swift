import Foundation
import Testing

@testable import SubRadarCore

private final class CallCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    func increment() {
        lock.lock()
        count += 1
        lock.unlock()
    }

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }
}

@Suite("Auto-update relaunch safety")
struct AppUpdateRelaunchSafetyTests {
    @Test("Repeated restart confirmation only launches one replace helper")
    @MainActor
    func repeatedConfirmationAppliesOnce() async throws {
        let defaults = UserDefaults(suiteName: "subradar.relaunch.\(UUID().uuidString)")!
        let applyCounter = CallCounter()
        let terminateCounter = CallCounter()
        let forceExitCounter = CallCounter()
        defer { _ = defaults }
        let manager = AppUpdateManager(
            settings: AppSettingsStore(userDefaults: defaults),
            logger: AppLogService(
                directoryURL: FileManager.default.temporaryDirectory
                    .appendingPathComponent("subradar-relaunch-logs-\(UUID().uuidString)")),
            applyHandler: { _ in applyCounter.increment() },
            terminateHandler: { terminateCounter.increment() },
            forceExitHandler: { forceExitCounter.increment() },
            terminateDelay: .milliseconds(10),
            forceExitDelay: .milliseconds(50)
        )
        let release = AppUpdateRelease(
            manifest: AppUpdateManifest(
                version: "9.9.9", build: 1, notes: "", releasePageURL: nil, assets: [:]))
        manager.state = .readyToRestart(
            StagedAppUpdate(
                release: release,
                stagedAppURL: URL(fileURLWithPath: "/tmp/staged/SubRadar.app"),
                targetAppURL: URL(fileURLWithPath: "/Applications/SubRadar.app"),
                stagingDir: URL(fileURLWithPath: "/tmp/staged")
            ))

        manager.showUpdatePrompt = true
        manager.restartAndInstallReadyUpdate()
        manager.restartAndInstallReadyUpdate()

        #expect(applyCounter.value == 1)
        // The prompt sheet must be dismissed before terminating, otherwise AppKit blocks termination.
        #expect(manager.showUpdatePrompt == false)
        #expect(terminateCounter.value == 0)
        try await Task.sleep(for: .milliseconds(80))
        #expect(terminateCounter.value == 1)
        #expect(forceExitCounter.value == 0)
        // If the process is still alive after the grace period, force exit.
        try await Task.sleep(for: .milliseconds(150))
        #expect(forceExitCounter.value == 1)
    }

    @Test("Replace script never deletes the target before verifying staged app and can roll back")
    func scriptIsSafe() {
        let script = AppUpdateInstaller.makeReplaceScript(
            pid: 123,
            stagedAppPath: "/tmp/staged/SubRadar.app",
            targetAppPath: "/Applications/SubRadar.app",
            stagingDirPath: "/tmp/staged",
            privileged: false
        )
        let guardRange = script.range(of: "[ -d \"/tmp/staged/SubRadar.app\" ]")
        let removeRange = script.range(of: "rm -rf \"/Applications/SubRadar.app\"")
        #expect(guardRange != nil)
        #expect(removeRange == nil)
        #expect(script.contains("SubRadar.app.old"))
        #expect(script.contains("mv \"/Applications/SubRadar.app.old\" \"/Applications/SubRadar.app\""))
    }
}
