import AppKit
import Foundation
import Observation

/// 应用内检查更新、15 分钟默认后台巡检与静默预下载后提醒重启管理器
@Observable
@MainActor
public final class AppUpdateManager {
    public static let defaultCheckIntervalSeconds: TimeInterval = 900

    public private(set) var state: AppUpdateState = .idle
    public private(set) var availableRelease: AppUpdateRelease?
    public private(set) var lastCheckedAt: Date?
    public var showUpdatePrompt: Bool = false

    private let settings: AppSettingsStore
    private let transport: HTTPTransportProtocol
    private let logger: AppLogService
    private let checkIntervalSeconds: TimeInterval
    private let isAppBundleProvider: @Sendable () -> Bool
    private let stageHandler:
        @Sendable (AppUpdateRelease, @escaping @Sendable (String) -> Void) async throws -> StagedAppUpdate
    private let applyHandler: @Sendable (StagedAppUpdate) throws -> Void
    private let terminateHandler: @MainActor @Sendable () -> Void

    private var periodicTask: Task<Void, Never>?
    private var isBusy: Bool = false

    public init(
        settings: AppSettingsStore,
        transport: HTTPTransportProtocol = URLSessionHTTPTransport(),
        logger: AppLogService = .shared,
        checkIntervalSeconds: TimeInterval = AppUpdateManager.defaultCheckIntervalSeconds,
        isAppBundleProvider: @escaping @Sendable () -> Bool = { AppUpdateInstaller.currentBundleIsApp() },
        stageHandler:
            @escaping @Sendable (AppUpdateRelease, @escaping @Sendable (String) -> Void) async throws ->
            StagedAppUpdate = { release, onStage in
                try await AppUpdateInstaller.stageUpdate(release: release, onStage: onStage)
            },
        applyHandler: @escaping @Sendable (StagedAppUpdate) throws -> Void = { staged in
            try AppUpdateInstaller.applyStagedUpdateAndRelaunch(staged)
        },
        terminateHandler: @escaping @MainActor @Sendable () -> Void = {
            NSApplication.shared.terminate(nil)
        }
    ) {
        self.settings = settings
        self.transport = transport
        self.logger = logger
        self.checkIntervalSeconds = max(60, checkIntervalSeconds)
        self.isAppBundleProvider = isAppBundleProvider
        self.stageHandler = stageHandler
        self.applyHandler = applyHandler
        self.terminateHandler = terminateHandler
    }

    public var currentVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "0.1.0"
    }

    public var feedURL: URL? {
        let override = settings.customUpdateFeedURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !override.isEmpty, let url = URL(string: override) {
            return url
        }
        if let plistRaw = Bundle.main.object(forInfoDictionaryKey: "SubRadarUpdateFeedURL") as? String {
            let trimmed = plistRaw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, let url = URL(string: trimmed) {
                return url
            }
        }
        return nil
    }

    public func startLifecycleMonitoring() {
        periodicTask?.cancel()
        let interval = checkIntervalSeconds
        periodicTask = Task { [weak self] in
            // 启动 3 秒后做一次首检，避免阻塞启动首帧渲染
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, let self else { return }
            if self.settings.autoCheckForUpdates {
                await self.checkForUpdates(manual: false)
            }

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { break }
                if self.settings.autoCheckForUpdates {
                    await self.checkForUpdates(manual: false)
                }
            }
        }
    }

    public func stopLifecycleMonitoring() {
        periodicTask?.cancel()
        periodicTask = nil
    }

    public func checkForUpdates(manual: Bool) async {
        guard !isBusy else { return }
        guard let url = feedURL else {
            if manual {
                state = .failed(message: AppUpdateError.feedURLNotConfigured.localizedDescription)
            }
            return
        }

        isBusy = true
        defer { isBusy = false }
        let priorReadyStaged: StagedAppUpdate? =
            if case .readyToRestart(let staged) = state { staged } else { nil }

        if manual, priorReadyStaged == nil {
            state = .checking
        }

        await logger.log(.info, category: .update, "开始检查更新 manual=\(manual) current=v\(currentVersion)")

        do {
            let manifest = try await fetchManifest(from: url)
            lastCheckedAt = Date()
            let remote = SemanticVersion(manifest.version)
            let local = SemanticVersion(currentVersion)

            guard remote > local else {
                if let priorReadyStaged {
                    AppUpdateInstaller.cleanupStaging(priorReadyStaged)
                }
                availableRelease = nil
                state = manual ? .upToDate(version: currentVersion) : .idle
                await logger.log(.info, category: .update, "当前已是最新版本 v\(currentVersion)")
                return
            }

            let release = AppUpdateRelease(manifest: manifest)
            if !manual && settings.skippedUpdateVersion == release.version {
                return
            }
            if manual && settings.skippedUpdateVersion == release.version {
                settings.skippedUpdateVersion = ""
            }

            availableRelease = release
            if let priorReadyStaged,
                priorReadyStaged.release.version == release.version,
                FileManager.default.fileExists(atPath: priorReadyStaged.stagedAppURL.path)
            {
                state = .readyToRestart(priorReadyStaged)
                showUpdatePrompt = true
                return
            }

            if let priorReadyStaged {
                AppUpdateInstaller.cleanupStaging(priorReadyStaged)
            }

            if isAppBundleProvider(), release.dmgURL != nil {
                await performSilentStage(release: release, manual: manual)
            } else {
                state = .available(release)
                showUpdatePrompt = true
                await logger.log(.info, category: .update, "发现新版本 v\(release.version)（开发或非 DMG 模式，仅提示更新）")
            }
        } catch {
            let msg = error.localizedDescription
            await logger.log(.error, category: .update, "检查更新失败 error=\(msg)")
            if manual {
                state = .failed(message: msg)
            }
        }
    }

    public func installAvailableUpdate() async {
        if case .readyToRestart = state {
            restartAndInstallReadyUpdate()
            return
        }
        guard let release = availableRelease else { return }
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        await performSilentStage(release: release, manual: true)
    }

    public func restartAndInstallReadyUpdate() {
        guard case .readyToRestart(let staged) = state else { return }
        do {
            try applyHandler(staged)
            let version = staged.release.version
            let logRef = logger
            Task { await logRef.log(.info, category: .update, "用户确认立即重启并安装 v\(version)") }
            showUpdatePrompt = false
            terminateHandler()
        } catch {
            let msg = error.localizedDescription
            let logRef = logger
            Task { await logRef.log(.error, category: .update, "触发重启安装失败 error=\(msg)") }
            state = .failed(message: msg)
        }
    }

    private func performSilentStage(release: AppUpdateRelease, manual: Bool) async {
        guard isAppBundleProvider() else {
            state = .failed(message: AppUpdateError.notRunningFromAppBundle.localizedDescription)
            return
        }
        do {
            state = .installing(version: release.version, stage: "正在静默下载 v\(release.version) 安装包...")
            let staged = try await stageHandler(release) { [weak self] stage in
                Task { @MainActor [weak self] in
                    self?.state = .installing(version: release.version, stage: stage)
                }
            }
            state = .readyToRestart(staged)
            showUpdatePrompt = true
            await logger.log(.info, category: .update, "新版本 v\(release.version) 静默下载并校验就绪，已提醒用户重启")
        } catch {
            let msg = error.localizedDescription
            await logger.log(.error, category: .update, "静默下载失败 version=\(release.version) error=\(msg)")
            state = .failed(message: msg)
            if manual {
                showUpdatePrompt = true
            }
        }
    }

    public func skipCurrentAvailableVersion() {
        if let version = availableRelease?.version {
            settings.skippedUpdateVersion = version
        }
        if case .readyToRestart(let staged) = state {
            AppUpdateInstaller.cleanupStaging(staged)
        }
        state = .idle
        showUpdatePrompt = false
    }

    private func fetchManifest(from url: URL) async throws -> AppUpdateManifest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        let (data, response) = try await transport.data(for: request)
        guard (200...299).contains(response.statusCode) else {
            throw AppUpdateError.replaceFailed("请求清单返回 HTTP \(response.statusCode)")
        }
        guard let manifest = try? JSONDecoder().decode(AppUpdateManifest.self, from: data),
            !manifest.version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw AppUpdateError.invalidManifest
        }
        return manifest
    }
}
