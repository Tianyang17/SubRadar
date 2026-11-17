import Foundation
import Testing

@testable import SubRadarCore

private final class MockLogHTTPTransport: HTTPTransportProtocol, @unchecked Sendable {
    let handler: @Sendable (URLRequest) throws -> (Data, HTTPURLResponse)

    init(handler: @escaping @Sendable (URLRequest) throws -> (Data, HTTPURLResponse)) {
        self.handler = handler
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try handler(request)
    }
}

@Suite("本地脱敏运行日志与服务链路埋点测试")
struct AppLogServiceTests {
    @Test("AppLogService 按日写入、并发安全、严格脱敏并清理超过 7 天日志")
    func testDailyRotationSanitizationAndRetention() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("subradar-logs-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        let expiredFile = tmpDir.appendingPathComponent("subradar-2020-01-01.log")
        let recentFile = tmpDir.appendingPathComponent("subradar-2026-11-12.log")
        try Data("old".utf8).write(to: expiredFile)
        try Data("recent".utf8).write(to: recentFile)

        var comps = DateComponents()
        comps.year = 2026
        comps.month = 11
        comps.day = 16
        comps.hour = 12
        comps.minute = 0
        let fixedNow = Calendar(identifier: .gregorian).date(from: comps)!

        let logger = AppLogService(directoryURL: tmpDir, retentionDays: 7) { fixedNow }
        await logger.log(
            .info,
            category: .balance,
            "Header Authorization: Bearer sk-secret-1234567890abcd url=https://api.example.com/v1/usage?api_key=myTopSecretKey99"
        )
        await logger.log(.warning, category: .app, "多行异常\n第二行详情 Bearer token_abcdef12345")

        let todayFile = await logger.logFileURL(for: fixedNow)
        #expect(todayFile.lastPathComponent == "subradar-2026-11-16.log")
        #expect(FileManager.default.fileExists(atPath: todayFile.path))
        #expect(!FileManager.default.fileExists(atPath: expiredFile.path))
        #expect(FileManager.default.fileExists(atPath: recentFile.path))

        let content = try String(contentsOf: todayFile, encoding: .utf8)
        #expect(content.contains("[INFO] [Balance]"))
        #expect(content.contains("[WARN] [App]"))
        #expect(!content.contains("sk-secret-1234567890abcd"))
        #expect(!content.contains("myTopSecretKey99"))
        #expect(!content.contains("token_abcdef12345"))
        #expect(content.contains("Bearer ***"))
        #expect(content.contains("api_key=***"))
        #expect(content.components(separatedBy: .newlines).filter { !$0.isEmpty }.count == 2)
    }

    @Test("API 余额探针写入脱敏日志且不泄露密钥")
    func testBalanceServiceLoggingWithoutSecretLeak() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("subradar-service-logs-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let logger = AppLogService(directoryURL: tmpDir, retentionDays: 7)

        let transport = MockLogHTTPTransport { request in
            let url = request.url!
            let json: [String: Any] = [
                "is_available": true,
                "balance_infos": [["currency": "CNY", "total_balance": "42.50"]]
            ]
            let data = try JSONSerialization.data(withJSONObject: json)
            let http = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
            return (data, http)
        }

        let balanceService = APIBalanceService(transport: transport, logger: logger)
        let subID = UUID()
        var item = SubscriptionItem(
            id: subID,
            name: "DeepSeek API",
            categoryId: UUID(),
            templateId: UUID(),
            price: 100,
            currency: "CNY",
            nextRenewalDate: Date()
        )
        item.customFields = [
            CustomField(subscriptionId: subID, key: "provider_preset", label: "服务商", type: .text, value: "deepseek"),
            CustomField(
                subscriptionId: subID,
                key: "api_endpoint",
                label: "Endpoint",
                type: .url,
                value: "https://api.deepseek.com"
            ),
            CustomField(
                subscriptionId: subID,
                key: "api_key",
                label: "Key",
                type: .secret,
                value: "sk-balance-secret-5544"
            )
        ]
        _ = try await balanceService.fetchBalance(for: item)

        let todayFile = await logger.logFileURL()
        let content = try String(contentsOf: todayFile, encoding: .utf8)
        #expect(content.contains("[Balance]"))
        #expect(!content.contains("sk-balance-secret-5544"))
    }
}
