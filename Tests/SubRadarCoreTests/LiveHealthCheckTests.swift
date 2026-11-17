import Foundation
import Testing

@testable import SubRadarCore

/// 外部网络接口健康度探测测试（需在联网环境下由本机终端或 Xcode 运行：`swift test --filter LiveHealthCheckTests`）
@Suite("外部接口实时健康度测试")
struct LiveHealthCheckTests {
    @Test("App Store Search API 连通性与图标下载验证")
    func testAppStoreSearchHealth() async throws {
        let iconService = IconService()
        let results = try await iconService.searchAppStore(keyword: "QQ音乐", country: "cn", limit: 3)
        #expect(!results.isEmpty)

        let firstURL = try #require(results.first?.bestArtworkURL)
        let pngData = try await iconService.downloadAndNormalizeIcon(from: firstURL)
        #expect(pngData.count > 100)
    }

    @Test("网站 Favicon 抓取链路健康度验证")
    func testFaviconFetcherHealth() async throws {
        let iconService = IconService()
        let pngData = try await iconService.fetchFavicon(for: "https://github.com")
        #expect(pngData.count > 100)
    }

    @Test("Frankfurter 与 fawazahmed0 历史汇率查询与 SQLite 缓存验证")
    func testExchangeRateHealthAndCaching() async throws {
        let db = try SQLiteDatabase(path: ":memory:")
        try await DatabaseMigrator.migrateIfNeeded(db)

        let service = ExchangeRateService(database: db)
        let historicalDate = Date(timeIntervalSince1970: 1_684_108_800)  // 2023-05-15

        let rate = await service.rate(from: "USD", to: "CNY", on: historicalDate)
        #expect(rate > 5 && rate < 10)

        // 验证已写入本地 SQLite 缓存
        let rows = try await db.query("SELECT COUNT(*) AS cnt FROM exchange_rates;")
        #expect((rows.first?.int("cnt") ?? 0) >= 1)
    }
}
