import CryptoKit
import Foundation

/// 原生 DMG 静默下载、SHA256 完整性校验、挂载替换与自动重启安装器
public enum AppUpdateInstaller {
    public static func currentBundleIsApp() -> Bool {
        Bundle.main.bundleURL.pathExtension.lowercased() == "app"
    }

    /// 阶段 1：静默下载 DMG、校验 SHA256 并解压暂存 `.app`，不退出当前应用
    public static func stageUpdate(
        release: AppUpdateRelease,
        targetAppURL: URL = Bundle.main.bundleURL,
        logger: AppLogService = .shared,
        onStage: @escaping @Sendable (String) -> Void
    ) async throws -> StagedAppUpdate {
        guard let dmgURL = release.dmgURL else {
            throw AppUpdateError.missingAssetForArchitecture(AppUpdateArchitecture.current.rawValue)
        }

        await logger.log(
            .info, category: .update, "开始静默下载安装包 v\(release.version) url=\(LogSanitizer.sanitizeURL(dmgURL))")
        onStage("正在静默下载 v\(release.version) 安装包...")
        let downloadedDMG = try await downloadFile(from: dmgURL)

        if let expectedHash = release.sha256?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            !expectedHash.isEmpty
        {
            onStage("正在校验安装包 SHA256...")
            let actualHash = try computeSHA256(of: downloadedDMG)
            guard actualHash == expectedHash else {
                try? FileManager.default.removeItem(at: downloadedDMG)
                await logger.log(.error, category: .update, "SHA256 校验失败 v\(release.version)")
                throw AppUpdateError.sha256Mismatch(expected: expectedHash, actual: actualHash)
            }
        }

        onStage("正在解压并准备新版本...")
        let stagingDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SubRadarUpdate-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: stagingDir, withIntermediateDirectories: true)

        let stagedAppURL = try extractAppFromDMG(dmgURL: downloadedDMG, into: stagingDir)
        try? FileManager.default.removeItem(at: downloadedDMG)

        await logger.log(.info, category: .update, "新版本 v\(release.version) 已下载校验并暂存就绪")
        return StagedAppUpdate(
            release: release,
            stagedAppURL: stagedAppURL,
            targetAppURL: targetAppURL,
            stagingDir: stagingDir
        )
    }

    /// 阶段 2：投递等待当前进程退出后的原子替换与重启脚本
    public static func applyStagedUpdateAndRelaunch(_ staged: StagedAppUpdate) throws {
        guard currentBundleIsApp() else {
            throw AppUpdateError.notRunningFromAppBundle
        }
        try scheduleAtomicReplaceAndRelaunch(
            stagedAppURL: staged.stagedAppURL,
            targetAppURL: staged.targetAppURL,
            stagingDir: staged.stagingDir
        )
    }

    public static func cleanupStaging(_ staged: StagedAppUpdate) {
        try? FileManager.default.removeItem(at: staged.stagingDir)
    }

    private static func downloadFile(from remoteURL: URL) async throws -> URL {
        var request = URLRequest(url: remoteURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 180
        let (tempURL, response) = try await URLSession.shared.download(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw AppUpdateError.replaceFailed("下载返回 HTTP \(http.statusCode)")
        }
        let localDMG = FileManager.default.temporaryDirectory
            .appendingPathComponent("SubRadar-Update-\(UUID().uuidString).dmg")
        if FileManager.default.fileExists(atPath: localDMG.path) {
            try? FileManager.default.removeItem(at: localDMG)
        }
        try FileManager.default.moveItem(at: tempURL, to: localDMG)
        return localDMG
    }

    static func computeSHA256(of fileURL: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            let chunk = try handle.read(upToCount: 1_048_576) ?? Data()
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func extractAppFromDMG(dmgURL: URL, into stagingDir: URL) throws -> URL {
        let attachResult = try runProcess(
            executable: "/usr/bin/hdiutil",
            arguments: ["attach", dmgURL.path, "-nobrowse", "-readonly", "-plist"]
        )
        guard attachResult.status == 0 else {
            throw AppUpdateError.mountFailed(attachResult.stderr)
        }

        let mountURL = try parseMountPoint(from: attachResult.stdoutData)
        defer {
            _ = try? runProcess(executable: "/usr/bin/hdiutil", arguments: ["detach", mountURL.path, "-quiet"])
        }

        let contents = try FileManager.default.contentsOfDirectory(
            at: mountURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        guard let sourceApp = contents.first(where: { $0.pathExtension.lowercased() == "app" }) else {
            throw AppUpdateError.appNotFoundInDMG
        }

        let stagedApp = stagingDir.appendingPathComponent("SubRadar.app", isDirectory: true)
        if FileManager.default.fileExists(atPath: stagedApp.path) {
            try FileManager.default.removeItem(at: stagedApp)
        }
        try FileManager.default.copyItem(at: sourceApp, to: stagedApp)
        _ = try? runProcess(executable: "/usr/bin/xattr", arguments: ["-cr", stagedApp.path])

        let verifyResult = try runProcess(
            executable: "/usr/bin/codesign",
            arguments: ["--verify", "--deep", "--strict", stagedApp.path]
        )
        if verifyResult.status != 0 {
            throw AppUpdateError.replaceFailed("新版本包完整性校验失败：\(verifyResult.stderr)")
        }
        return stagedApp
    }

    private static func parseMountPoint(from plistData: Data) throws -> URL {
        guard let plist = try PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
            let entities = plist["system-entities"] as? [[String: Any]],
            let mountPath = entities.compactMap({ $0["mount-point"] as? String }).first
        else {
            throw AppUpdateError.mountFailed("无法解析 DMG 挂载路径")
        }
        return URL(fileURLWithPath: mountPath, isDirectory: true)
    }

    private static func scheduleAtomicReplaceAndRelaunch(
        stagedAppURL: URL,
        targetAppURL: URL,
        stagingDir: URL
    ) throws {
        let pid = ProcessInfo.processInfo.processIdentifier
        let parentWritable = FileManager.default.isWritableFile(atPath: targetAppURL.deletingLastPathComponent().path)
        let helperScript = stagingDir.appendingPathComponent("replace_and_relaunch.sh")

        let replaceCommand: String
        if parentWritable {
            replaceCommand = """
                rm -rf "\(targetAppURL.path)"
                mv "\(stagedAppURL.path)" "\(targetAppURL.path)"
                """
        } else {
            let shellSnippet = "rm -rf '\(targetAppURL.path)' && mv '\(stagedAppURL.path)' '\(targetAppURL.path)'"
            let escaped = shellSnippet.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(
                of: "\"", with: "\\\"")
            replaceCommand = """
                /usr/bin/osascript -e "do shell script \\"\(escaped)\\" with administrator privileges"
                """
        }

        let script = """
            #!/usr/bin/env bash
            set -e
            while kill -0 \(pid) 2>/dev/null; do
                sleep 0.2
            done
            \(replaceCommand)
            /usr/bin/xattr -cr "\(targetAppURL.path)" || true
            /usr/bin/open -n "\(targetAppURL.path)"
            rm -rf "\(stagingDir.path)" || true
            """

        try script.write(to: helperScript, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: helperScript.path)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [helperScript.path]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
    }

    private static func runProcess(
        executable: String,
        arguments: [String]
    ) throws -> (status: Int32, stdoutData: Data, stderr: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        try process.run()
        process.waitUntilExit()
        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        let stderr = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return (process.terminationStatus, outData, stderr)
    }
}
