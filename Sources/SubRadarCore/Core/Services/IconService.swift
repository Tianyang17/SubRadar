import Foundation

#if canImport(AppKit)
    import AppKit
#endif

public enum IconServiceError: LocalizedError, Sendable {
    case invalidApplicationBundle
    case invalidURL
    case networkFailure
    case invalidImageData
    case faviconNotFound

    public var errorDescription: String? {
        switch self {
        case .invalidApplicationBundle:
            return "请选择有效的 .app 应用程序包"
        case .invalidURL:
            return "无效的网址或链接"
        case .networkFailure:
            return "网络请求失败，请检查网络连接"
        case .invalidImageData:
            return "无法解析为有效图片数据"
        case .faviconNotFound:
            return "未能从该网站获取到有效图标"
        }
    }
}

/// 四维一体图标导入与归一化服务真实实现
public final class IconService: IconServiceProtocol, Sendable {
    private let session: URLSession

    public init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 10
            config.timeoutIntervalForResource = 15
            self.session = URLSession(configuration: config)
        }
    }

    // MARK: - 1. 本机 /Applications 目录 .app 应用提取

    public func extractLocalAppInfo(at appURL: URL) throws -> ExtractedAppInfo {
        guard appURL.pathExtension.lowercased() == "app" else {
            throw IconServiceError.invalidApplicationBundle
        }

        let bundle = Bundle(url: appURL)
        let localizedName =
            bundle?.localizedInfoDictionary?["CFBundleDisplayName"] as? String
            ?? bundle?.localizedInfoDictionary?["CFBundleName"] as? String
            ?? bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? appURL.deletingPathExtension().lastPathComponent

        #if canImport(AppKit)
            let iconImage = NSWorkspace.shared.icon(forFile: appURL.path)
            let pngData = try normalizeNSImage(iconImage, targetDimension: 256)
            return ExtractedAppInfo(name: localizedName, iconData: pngData)
        #else
            return ExtractedAppInfo(name: localizedName, iconData: nil)
        #endif
    }

    // MARK: - 2. App Store 公开搜索

    public func searchAppStore(
        keyword: String,
        country: String = "cn",
        limit: Int = 8
    ) async throws -> [AppStoreSearchItem] {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let primary = try await fetchAppStoreResults(keyword: trimmed, country: country, limit: limit)
        if primary.isEmpty, country.lowercased() == "cn" {
            return try await fetchAppStoreResults(keyword: trimmed, country: "us", limit: limit)
        }
        return primary
    }

    private func fetchAppStoreResults(
        keyword: String,
        country: String,
        limit: Int
    ) async throws -> [AppStoreSearchItem] {
        var components = URLComponents(string: "https://itunes.apple.com/search")
        components?.queryItems = [
            URLQueryItem(name: "term", value: keyword),
            URLQueryItem(name: "entity", value: "software,macSoftware"),
            URLQueryItem(name: "country", value: country),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        guard let url = components?.url else {
            throw IconServiceError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw IconServiceError.networkFailure
        }

        struct SearchResponse: Decodable {
            let results: [AppStoreSearchItem]
        }

        let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
        return decoded.results
    }

    public func downloadAndNormalizeIcon(from url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw IconServiceError.networkFailure
        }
        return try normalizeImageData(data, targetDimension: 256)
    }

    // MARK: - 3. 网站 Favicon 抓取

    public func fetchFavicon(for urlString: String) async throws -> Data {
        var normalized = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { throw IconServiceError.invalidURL }
        if !normalized.hasPrefix("http://") && !normalized.hasPrefix("https://") {
            normalized = "https://" + normalized
        }
        guard let baseURL = URL(string: normalized), let host = baseURL.host else {
            throw IconServiceError.invalidURL
        }

        // 策略 1：直抓网页 HTML 解析高精度 apple-touch-icon / icon
        if let htmlIconURL = await discoverIconURLFromHTML(pageURL: baseURL) {
            if let data = try? await downloadAndNormalizeIcon(from: htmlIconURL) {
                return data
            }
        }

        // 策略 2：尝试站点根目录 /apple-touch-icon.png 与 /favicon.ico
        if let scheme = baseURL.scheme {
            for path in ["/apple-touch-icon.png", "/favicon.ico"] {
                if let candidate = URL(string: "\(scheme)://\(host)\(path)"),
                    let data = try? await downloadAndNormalizeIcon(from: candidate)
                {
                    return data
                }
            }
        }

        // 策略 3：多节点第三方 Favicon 聚合兜底
        let fallbackURLs = [
            "https://www.google.com/s2/favicons?domain=\(host)&sz=128",
            "https://icons.duckduckgo.com/ip3/\(host).ico"
        ]
        for fallbackStr in fallbackURLs {
            if let url = URL(string: fallbackStr),
                let data = try? await downloadAndNormalizeIcon(from: url)
            {
                return data
            }
        }

        throw IconServiceError.faviconNotFound
    }

    // MARK: - 4. 本地上传 / 剪贴板图片居中裁剪归一化

    public func normalizeImageData(_ rawData: Data, targetDimension: Int = 256) throws -> Data {
        #if canImport(AppKit)
            guard let nsImage = NSImage(data: rawData) else {
                throw IconServiceError.invalidImageData
            }
            return try normalizeNSImage(nsImage, targetDimension: targetDimension)
        #else
            return rawData
        #endif
    }

    #if canImport(AppKit)
        private func normalizeNSImage(_ image: NSImage, targetDimension: Int) throws -> Data {
            let size = image.size
            guard size.width > 0, size.height > 0 else {
                throw IconServiceError.invalidImageData
            }

            guard
                let rep = NSBitmapImageRep(
                    bitmapDataPlanes: nil,
                    pixelsWide: targetDimension,
                    pixelsHigh: targetDimension,
                    bitsPerSample: 8,
                    samplesPerPixel: 4,
                    hasAlpha: true,
                    isPlanar: false,
                    colorSpaceName: .deviceRGB,
                    bytesPerRow: 0,
                    bitsPerPixel: 0
                )
            else {
                throw IconServiceError.invalidImageData
            }

            rep.size = NSSize(width: targetDimension, height: targetDimension)

            NSGraphicsContext.saveGraphicsState()
            defer { NSGraphicsContext.restoreGraphicsState() }

            guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
                throw IconServiceError.invalidImageData
            }
            NSGraphicsContext.current = context
            context.imageInterpolation = .high

            let minSide = min(size.width, size.height)
            let sourceRect = NSRect(
                x: (size.width - minSide) / 2.0,
                y: (size.height - minSide) / 2.0,
                width: minSide,
                height: minSide
            )
            let destRect = NSRect(x: 0, y: 0, width: targetDimension, height: targetDimension)

            image.draw(in: destRect, from: sourceRect, operation: .copy, fraction: 1.0)

            guard let pngData = rep.representation(using: .png, properties: [:]) else {
                throw IconServiceError.invalidImageData
            }
            return pngData
        }
    #endif

    // MARK: - HTML Icon Discovery Helper

    private func discoverIconURLFromHTML(pageURL: URL) async -> URL? {
        var request = URLRequest(url: pageURL)
        request.timeoutInterval = 5
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )

        guard let (data, response) = try? await session.data(for: request),
            let http = response as? HTTPURLResponse,
            (200...299).contains(http.statusCode),
            let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii)
        else {
            return nil
        }

        let patterns = [
            #"<link[^>]*rel=["'][^"']*apple-touch-icon[^"']*["'][^>]*href=["']([^"']+)["']"#,
            #"<link[^>]*href=["']([^"']+)["'][^>]*rel=["'][^"']*apple-touch-icon[^"']*["']"#,
            #"<link[^>]*rel=["'][^"']*icon[^"']*["'][^>]*href=["']([^"']+)["']"#,
            #"<link[^>]*href=["']([^"']+)["'][^>]*rel=["'][^"']*icon[^"']*["']"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                let range = Range(match.range(at: 1), in: html)
            {
                let href = String(html[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                if let resolved = URL(string: href, relativeTo: pageURL)?.absoluteURL {
                    return resolved
                }
            }
        }
        return nil
    }
}
