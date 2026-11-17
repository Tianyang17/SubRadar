import Foundation

/// 本机应用导入提取结果
public struct ExtractedAppInfo: Sendable, Equatable {
    public let name: String
    public let iconData: Data?

    public init(name: String, iconData: Data?) {
        self.name = name
        self.iconData = iconData
    }
}

/// 四维一体图标导入与归一化服务协议
public protocol IconServiceProtocol: Sendable {
    /// 1. 从本机 /Applications 选择的 .app 应用包提取应用名称与图标（不支持拖拽 .app）
    func extractLocalAppInfo(at appURL: URL) throws -> ExtractedAppInfo

    /// 2. 从 App Store Search API 搜索应用
    func searchAppStore(keyword: String, country: String, limit: Int) async throws -> [AppStoreSearchItem]

    /// 2b. 下载并归一化 App Store 图标为 256x256 PNG
    func downloadAndNormalizeIcon(from url: URL) async throws -> Data

    /// 3. 输入网址解析并抓取高清 Favicon / Apple Touch Icon
    func fetchFavicon(for urlString: String) async throws -> Data

    /// 4. 将本地上传图片或剪贴板图片居中裁剪并归一化为 256x256 PNG
    func normalizeImageData(_ rawData: Data, targetDimension: Int) throws -> Data
}
