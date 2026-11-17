import Foundation
import Testing

@testable import SubRadarCore

private final class MockFlowHTTPTransport: HTTPTransportProtocol, @unchecked Sendable {
    let handler: @Sendable (URLRequest) throws -> (Data, HTTPURLResponse)

    init(handler: @escaping @Sendable (URLRequest) throws -> (Data, HTTPURLResponse)) {
        self.handler = handler
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try handler(request)
    }
}

private final class AtomicCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var _value = 0

    func increment() {
        lock.lock()
        _value += 1
        lock.unlock()
    }

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return _value
    }
}

@Suite("应用更新 15 分钟默认巡检与静默预下载重启提醒测试")
struct AppUpdateFlowTests {
    private func makeManifestData(version: String = "9.9.9") throws -> Data {
        let manifest = AppUpdateManifest(
            version: version,
            build: 99,
            notes: "新版本特性：15 分钟巡检与静默下载后提示重启",
            releasePageURL: "https://example.com/releases/tag/v\(version)",
            assets: [
                AppUpdateArchitecture.current.rawValue: AppUpdateAsset(
                    dmgURL: "https://example.com/SubRadar-v\(version).dmg",
                    sha256: "abc123"
                )
            ]
        )
        return try JSONEncoder().encode(manifest)
    }

    @Test("默认巡检间隔固定为 15 分钟（900 秒）且发现新版后先静默暂存再提醒重启，不提前退出")
    @MainActor
    func testSilentDownloadStagesAndPromptsRestartWithoutImmediateTerminate() async throws {
        #expect(AppUpdateManager.defaultCheckIntervalSeconds == 900)

        let suiteName = "subradar.update.flow.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let logDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("subradar-update-logs-\(UUID().uuidString)", isDirectory: true)
        let stagingDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("subradar-staged-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: logDir)
            try? FileManager.default.removeItem(at: stagingDir)
        }
        try FileManager.default.createDirectory(at: stagingDir, withIntermediateDirectories: true)
        let stagedAppURL = stagingDir.appendingPathComponent("SubRadar.app", isDirectory: true)
        try FileManager.default.createDirectory(at: stagedAppURL, withIntermediateDirectories: true)

        let settings = AppSettingsStore(userDefaults: defaults)
        settings.customUpdateFeedURL = "https://example.com/latest.json"
        let manifestData = try makeManifestData()
        let transport = MockFlowHTTPTransport { request in
            let http = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
            return (manifestData, http)
        }

        let logger = AppLogService(directoryURL: logDir)
        let stageCounter = AtomicCounter()
        let applyCounter = AtomicCounter()
        let terminateCounter = AtomicCounter()

        let manager = AppUpdateManager(
            settings: settings,
            transport: transport,
            logger: logger,
            isAppBundleProvider: { true },
            stageHandler: { release, onStage in
                stageCounter.increment()
                onStage("正在静默下载 v\(release.version)...")
                return StagedAppUpdate(
                    release: release,
                    stagedAppURL: stagedAppURL,
                    targetAppURL: URL(fileURLWithPath: "/Applications/SubRadar.app"),
                    stagingDir: stagingDir
                )
            },
            applyHandler: { _ in
                applyCounter.increment()
            },
            terminateHandler: {
                terminateCounter.increment()
            },
            forceExitHandler: {},
            terminateDelay: .milliseconds(10),
            forceExitDelay: .seconds(60)
        )

        await manager.checkForUpdates(manual: false)

        #expect(stageCounter.value == 1)
        #expect(applyCounter.value == 0)
        #expect(terminateCounter.value == 0)
        #expect(manager.showUpdatePrompt == true)
        if case .readyToRestart(let staged) = manager.state {
            #expect(staged.release.version == "9.9.9")
        } else {
            Issue.record("期望状态为 .readyToRestart，实际为 \(manager.state)")
        }

        manager.restartAndInstallReadyUpdate()
        #expect(applyCounter.value == 1)
        try await Task.sleep(for: .milliseconds(100))
        #expect(terminateCounter.value == 1)

        let logContent = try String(contentsOf: await logger.logFileURL(), encoding: .utf8)
        #expect(logContent.contains("[Update]"))
        #expect(logContent.contains("9.9.9"))
    }

    @Test("跳过已暂存更新时清理临时目录并记录 skippedUpdateVersion")
    @MainActor
    func testSkipReadyUpdateCleansStagingDirectory() async throws {
        let suiteName = "subradar.update.skip.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let stagingDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("subradar-skip-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: stagingDir) }
        try FileManager.default.createDirectory(at: stagingDir, withIntermediateDirectories: true)
        let stagedAppURL = stagingDir.appendingPathComponent("SubRadar.app", isDirectory: true)
        try FileManager.default.createDirectory(at: stagedAppURL, withIntermediateDirectories: true)

        let settings = AppSettingsStore(userDefaults: defaults)
        settings.customUpdateFeedURL = "https://example.com/latest.json"
        let manifestData = try makeManifestData(version: "8.8.8")
        let transport = MockFlowHTTPTransport { request in
            let http = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
            return (manifestData, http)
        }

        let manager = AppUpdateManager(
            settings: settings,
            transport: transport,
            isAppBundleProvider: { true },
            stageHandler: { release, _ in
                StagedAppUpdate(
                    release: release,
                    stagedAppURL: stagedAppURL,
                    targetAppURL: URL(fileURLWithPath: "/Applications/SubRadar.app"),
                    stagingDir: stagingDir
                )
            }
        )

        await manager.checkForUpdates(manual: true)
        #expect(FileManager.default.fileExists(atPath: stagingDir.path))

        manager.skipCurrentAvailableVersion()
        #expect(settings.skippedUpdateVersion == "8.8.8")
        #expect(manager.showUpdatePrompt == false)
        #expect(manager.state == .idle)
        #expect(!FileManager.default.fileExists(atPath: stagingDir.path))
    }
}
