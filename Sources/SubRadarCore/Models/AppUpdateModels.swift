import Foundation

/// 当前运行时 CPU 架构标识（与 Release 产物后缀对齐）
public enum AppUpdateArchitecture: String, Codable, Sendable {
    case arm64
    case x8664 = "x86_64"

    public static var current: AppUpdateArchitecture {
        #if arch(arm64)
            return .arm64
        #else
            return .x8664
        #endif
    }
}

/// 单个架构的 DMG 下载与校验信息
public struct AppUpdateAsset: Codable, Equatable, Sendable {
    public let dmgURL: String
    public let sha256: String

    public init(dmgURL: String, sha256: String) {
        self.dmgURL = dmgURL
        self.sha256 = sha256
    }
}

/// GitHub Release 静态分发清单（latest.json）
public struct AppUpdateManifest: Codable, Equatable, Sendable {
    public let version: String
    public let build: Int?
    public let publishedAt: String?
    public let notes: String?
    public let releasePageURL: String?
    public let assets: [String: AppUpdateAsset]

    public init(
        version: String,
        build: Int? = nil,
        publishedAt: String? = nil,
        notes: String? = nil,
        releasePageURL: String? = nil,
        assets: [String: AppUpdateAsset] = [:]
    ) {
        self.version = version
        self.build = build
        self.publishedAt = publishedAt
        self.notes = notes
        self.releasePageURL = releasePageURL
        self.assets = assets
    }

    public func assetForCurrentArchitecture() -> AppUpdateAsset? {
        assets[AppUpdateArchitecture.current.rawValue]
            ?? assets["universal"]
            ?? assets.values.first
    }
}

/// 语义化版本号解析与比较（如 1.0.0 < 1.0.1 < 1.2.0）
public struct SemanticVersion: Comparable, Equatable, Sendable {
    public let components: [Int]
    public let raw: String

    public init(_ raw: String) {
        self.raw = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let stripped =
            self.raw.hasPrefix("v") || self.raw.hasPrefix("V")
            ? String(self.raw.dropFirst())
            : self.raw
        let core = stripped.split(separator: "-", maxSplits: 1).first.map(String.init) ?? stripped
        let nums = core.split(separator: ".").map { part -> Int in
            let digits = part.prefix(while: \.isNumber)
            return Int(digits) ?? 0
        }
        self.components = nums.isEmpty ? [0] : nums
    }

    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        let maxCount = max(lhs.components.count, rhs.components.count)
        for index in 0..<maxCount {
            let lVal = index < lhs.components.count ? lhs.components[index] : 0
            let rVal = index < rhs.components.count ? rhs.components[index] : 0
            if lVal != rVal {
                return lVal < rVal
            }
        }
        return false
    }
}

/// 可用更新详情
public struct AppUpdateRelease: Equatable, Sendable {
    public let version: String
    public let notes: String
    public let publishedAt: String?
    public let dmgURL: URL?
    public let sha256: String?
    public let releasePageURL: URL?

    public init(manifest: AppUpdateManifest) {
        self.version = manifest.version
        self.notes = manifest.notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.publishedAt = manifest.publishedAt
        let matched = manifest.assetForCurrentArchitecture()
        self.dmgURL = matched.flatMap { URL(string: $0.dmgURL) }
        self.sha256 = matched?.sha256
        self.releasePageURL = manifest.releasePageURL.flatMap { URL(string: $0) }
    }
}

/// 已下载校验并解压暂存的新版本包（等待用户点击重启完成替换）
public struct StagedAppUpdate: Equatable, Sendable {
    public let release: AppUpdateRelease
    public let stagedAppURL: URL
    public let targetAppURL: URL
    public let stagingDir: URL

    public init(
        release: AppUpdateRelease,
        stagedAppURL: URL,
        targetAppURL: URL,
        stagingDir: URL
    ) {
        self.release = release
        self.stagedAppURL = stagedAppURL
        self.targetAppURL = targetAppURL
        self.stagingDir = stagingDir
    }
}

/// 更新检查与安装状态
public enum AppUpdateState: Equatable, Sendable {
    case idle
    case checking
    case upToDate(version: String)
    case available(AppUpdateRelease)
    case installing(version: String, stage: String)
    case readyToRestart(StagedAppUpdate)
    case failed(message: String)
}

public enum AppUpdateError: LocalizedError, Sendable {
    case feedURLNotConfigured
    case invalidManifest
    case missingAssetForArchitecture(String)
    case sha256Mismatch(expected: String, actual: String)
    case notRunningFromAppBundle
    case mountFailed(String)
    case appNotFoundInDMG
    case replaceFailed(String)

    public var errorDescription: String? {
        switch self {
        case .feedURLNotConfigured:
            return "尚未配置版本更新源，请通过发行页面手动检查或联系维护者。"
        case .invalidManifest:
            return "未能读取到有效的版本更新清单，请检查更新源地址或稍后再试。"
        case .missingAssetForArchitecture(let arch):
            return "当前版本暂未提供适配你设备架构（\(arch)）的安装包。"
        case .sha256Mismatch:
            return "新版本安装包完整性校验未通过，为保证安全已自动取消安装，请稍后重试。"
        case .notRunningFromAppBundle:
            return "当前为开发运行模式，不支持就地自动替换，请下载 DMG 安装包运行。"
        case .mountFailed:
            return "无法打开下载的安装包镜像，请检查磁盘空间或前往发布页手动下载安装。"
        case .appNotFoundInDMG:
            return "安装包内容不完整（未找到应用程序），请稍后重试或手动下载。"
        case .replaceFailed:
            return "无法自动替换应用，请确认已将 SubRadar 放入「应用程序」文件夹并拥有写入权限。"
        }
    }
}
