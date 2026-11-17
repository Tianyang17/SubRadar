import Foundation

/// 安全定位 SwiftPM 资源包，避免 `Bundle.module` 在 `.app` 内找不到资源包时 `fatalError` 崩溃
public enum ResourceBundleLocator {
    public static let coreBundleName = "SubRadar_SubRadarCore"

    /// 依次在 `Contents/Resources`、`.app` 根目录、其同级目录（如 xctest 旁）与可执行文件旁查找；均不存在时返回 `nil`
    public static func locate(
        named name: String = coreBundleName,
        mainBundle: Bundle = .main
    ) -> Bundle? {
        let hostBundle = Bundle(for: BundleToken.self)
        let candidates = [
            hostBundle.bundleURL.deletingLastPathComponent(),
            mainBundle.resourceURL,
            mainBundle.bundleURL,
            mainBundle.bundleURL.deletingLastPathComponent(),
            mainBundle.executableURL?.deletingLastPathComponent()
        ]
        for base in candidates.compactMap({ $0 }) {
            let url = base.appendingPathComponent("\(name).bundle", isDirectory: true)
            if let bundle = Bundle(url: url) {
                return bundle
            }
        }
        return nil
    }

    public static let core: Bundle? = locate()
}

private final class BundleToken {}
