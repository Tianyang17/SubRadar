import Foundation

@testable import SubRadarCore

#if canImport(AppKit)
    import AppKit
#endif

/// Mock 图标服务（优先联网获取真实 App Store / 网站图标，离线或测试环境下自动降级）
public final class MockIconService: IconServiceProtocol, Sendable {
    private let realHelper = IconService()
    private let allowNetwork: Bool

    public init(allowNetwork: Bool = true) {
        self.allowNetwork = allowNetwork
    }

    public func extractLocalAppInfo(at appURL: URL) throws -> ExtractedAppInfo {
        try realHelper.extractLocalAppInfo(at: appURL)
    }

    public func searchAppStore(keyword: String, country: String, limit: Int) async throws -> [AppStoreSearchItem] {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        if allowNetwork {
            do {
                let live = try await realHelper.searchAppStore(keyword: trimmed, country: country, limit: limit)
                if !live.isEmpty {
                    return live
                }
            } catch {
                // 离线或超时时平滑回落到本地示例
            }
        }
        let samples = [
            AppStoreSearchItem(
                trackId: 414_603_431, trackName: "QQ音乐", artistName: "Tencent", bundleId: "com.tencent.QQMusicMac"),
            AppStoreSearchItem(
                trackId: 547_166_701, trackName: "百度网盘", artistName: "Baidu", bundleId: "com.baidu.netdiskmac"),
            AppStoreSearchItem(
                trackId: 1_559_269_364, trackName: "Notion", artistName: "Notion Labs", bundleId: "notion.id"),
            AppStoreSearchItem(
                trackId: 1_444_383_602, trackName: "Goodnotes", artistName: "Goodnotes Limited",
                bundleId: "com.goodnotes.mac")
        ]
        let filtered = samples.filter { $0.trackName.localizedCaseInsensitiveContains(trimmed) }
        return filtered.isEmpty
            ? [AppStoreSearchItem(trackId: 999999, trackName: trimmed, artistName: "App Store 示例")] : filtered
    }

    public func downloadAndNormalizeIcon(from url: URL) async throws -> Data {
        if allowNetwork {
            do {
                return try await realHelper.downloadAndNormalizeIcon(from: url)
            } catch {
                // 离线降级
            }
        }
        return Self.generateSymbolPNG(symbolName: "app.badge.fill")
    }

    public func fetchFavicon(for urlString: String) async throws -> Data {
        if allowNetwork {
            do {
                return try await realHelper.fetchFavicon(for: urlString)
            } catch {
                // 离线降级
            }
        }
        return Self.generateSymbolPNG(symbolName: "globe")
    }

    public func normalizeImageData(_ rawData: Data, targetDimension: Int = 256) throws -> Data {
        try realHelper.normalizeImageData(rawData, targetDimension: targetDimension)
    }

    private static func generateSymbolPNG(symbolName: String) -> Data {
        #if canImport(AppKit)
            let dim = 256
            guard
                let rep = NSBitmapImageRep(
                    bitmapDataPlanes: nil,
                    pixelsWide: dim,
                    pixelsHigh: dim,
                    bitsPerSample: 8,
                    samplesPerPixel: 4,
                    hasAlpha: true,
                    isPlanar: false,
                    colorSpaceName: .deviceRGB,
                    bytesPerRow: 0,
                    bitsPerPixel: 0
                ), let ctx = NSGraphicsContext(bitmapImageRep: rep)
            else {
                return Data()
            }

            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = ctx
            defer { NSGraphicsContext.restoreGraphicsState() }

            let rect = NSRect(x: 0, y: 0, width: dim, height: dim)
            let bgPath = NSBezierPath(roundedRect: rect, xRadius: 56, yRadius: 56)
            NSColor(srgbRed: 0.145, green: 0.388, blue: 0.922, alpha: 0.14).setFill()
            bgPath.fill()

            if let symImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
                .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 112, weight: .semibold))
            {
                let targetSize = NSSize(width: 128, height: 128)
                let drawRect = NSRect(
                    x: (CGFloat(dim) - targetSize.width) / 2,
                    y: (CGFloat(dim) - targetSize.height) / 2,
                    width: targetSize.width,
                    height: targetSize.height
                )
                symImage.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)
            }

            return rep.representation(using: .png, properties: [:]) ?? Data()
        #else
            return Data()
        #endif
    }
}

/// Mock 汇率服务
public final class MockExchangeRateService: ExchangeRateServiceProtocol, Sendable {
    public init() {}

    public func rate(from currency: String, to baseCurrency: String, on date: Date) async -> Decimal {
        Decimal(ExchangeRateService.staticFallbackRate(from: currency, to: baseCurrency))
    }

    public func prefetchRates(from currency: String, to baseCurrency: String, startDate: Date, endDate: Date) async {}
}

/// Mock 通知服务
public final class MockNotificationService: NotificationServiceProtocol, Sendable {
    public init() {}

    public func requestAuthorization() async -> Bool { true }
    public func scheduleReminder(for item: SubscriptionItem) async {}
    public func cancelReminder(for subscriptionId: UUID) async {}
    public func syncAllReminders(for items: [SubscriptionItem]) async {}
    public func notifyLowBalance(for item: SubscriptionItem, currentBalance: Decimal, threshold: Decimal) async {}
    public func sendTestNotification(title: String, body: String) async -> NotificationDeliveryReport {
        NotificationDeliveryReport(delivered: true, channel: "Mock", detail: "Mock 模式已模拟发布通知：\(title)")
    }
}
