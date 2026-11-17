import Foundation
import Testing

@testable import SubRadarCore

private final class StubHTTPTransport: HTTPTransportProtocol, @unchecked Sendable {
    var handler: @Sendable (URLRequest) throws -> (Data, HTTPURLResponse)

    init(handler: @escaping @Sendable (URLRequest) throws -> (Data, HTTPURLResponse)) {
        self.handler = handler
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try handler(request)
    }
}

private final class RecordingNotificationService: NotificationServiceProtocol, @unchecked Sendable {
    private let lock = NSLock()
    var lowBalanceAlerts: [(name: String, balance: Decimal, threshold: Decimal)] = []

    func requestAuthorization() async -> Bool { true }
    func scheduleReminder(for item: SubscriptionItem) async {}
    func cancelReminder(for subscriptionId: UUID) async {}
    func syncAllReminders(for items: [SubscriptionItem]) async {}
    func notifyLowBalance(for item: SubscriptionItem, currentBalance: Decimal, threshold: Decimal) async {
        lock.withLock {
            lowBalanceAlerts.append((item.name, currentBalance, threshold))
        }
    }
    func sendTestNotification(title: String, body: String) async -> NotificationDeliveryReport {
        NotificationDeliveryReport(delivered: true, channel: "Test", detail: title)
    }
}

@Suite("Phase 7.9 Batch C: API 余额探测、低余额告警与 CSV/JSON 备份恢复测试")
struct APIBalanceAndBackupTests {
    private func makeHTTPResponse(url: URL, statusCode: Int = 200) -> HTTPURLResponse {
        HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: nil)!
    }

    private func makeAPIItem(
        name: String,
        preset: String,
        endpoint: String,
        apiKey: String = "sk-test-123",
        parseRule: String = "",
        threshold: String = "10",
        currency: String = "USD"
    ) -> SubscriptionItem {
        let subId = UUID()
        let now = Date()
        return SubscriptionItem(
            id: subId,
            name: name,
            categoryId: SubscriptionCategory.BuiltinID.productivity,
            templateId: TemplateDefinition.BuiltinID.apiBalance,
            price: 100,
            currency: currency,
            billingCycleType: .oneTime,
            startDate: now,
            nextRenewalDate: now,
            customFields: [
                CustomField(
                    subscriptionId: subId, key: "provider_preset", label: "平台适配器", type: .text, value: preset,
                    sortOrder: 0),
                CustomField(
                    subscriptionId: subId, key: "api_endpoint", label: "接口 Base / 查询地址", type: .url, value: endpoint,
                    sortOrder: 1),
                CustomField(
                    subscriptionId: subId, key: "api_key", label: "API Key", type: .secret, value: apiKey, sortOrder: 2),
                CustomField(
                    subscriptionId: subId, key: "parse_rule", label: "解析与换算规则", type: .text, value: parseRule,
                    sortOrder: 3),
                CustomField(
                    subscriptionId: subId, key: "current_balance", label: "当前账户余额", type: .number, value: "0",
                    sortOrder: 4),
                CustomField(
                    subscriptionId: subId, key: "low_balance_threshold", label: "低余额告警阈值", type: .number,
                    value: threshold, sortOrder: 5)
            ]
        )
    }

    @Test("DeepSeek / OpenRouter / SiliconFlow / New API / Sub2API / Custom 适配器解析验证")
    func testAPIBalanceProviders() async throws {
        // 1. DeepSeek
        let dsTransport = StubHTTPTransport { req in
            #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer sk-test-123")
            let json =
                #"{"is_available":true,"balance_infos":[{"currency":"CNY","total_balance":"42.50","granted_balance":"0.00","topped_up_balance":"42.50"}]}"#
            return (Data(json.utf8), self.makeHTTPResponse(url: req.url!))
        }
        let dsResult = try await APIBalanceService(transport: dsTransport).fetchBalance(
            for: makeAPIItem(
                name: "DeepSeek", preset: "deepseek", endpoint: "https://api.deepseek.com/user/balance", currency: "CNY"
            )
        )
        #expect(dsResult.balance == Decimal(string: "42.50"))
        #expect(dsResult.currency == "CNY")

        // 2. OpenRouter (total_credits - total_usage)
        let orTransport = StubHTTPTransport { req in
            let json = #"{"data":{"total_credits":25.0,"total_usage":6.25}}"#
            return (Data(json.utf8), self.makeHTTPResponse(url: req.url!))
        }
        let orResult = try await APIBalanceService(transport: orTransport).fetchBalance(
            for: makeAPIItem(name: "OpenRouter", preset: "openrouter", endpoint: "https://openrouter.ai/api/v1/credits")
        )
        #expect(orResult.balance == Decimal(string: "18.75"))

        // 3. SiliconFlow
        let sfTransport = StubHTTPTransport { req in
            let json = #"{"code":20000,"data":{"totalBalance":"88.12"}}"#
            return (Data(json.utf8), self.makeHTTPResponse(url: req.url!))
        }
        let sfResult = try await APIBalanceService(transport: sfTransport).fetchBalance(
            for: makeAPIItem(
                name: "SiliconFlow", preset: "siliconflow", endpoint: "https://api.siliconflow.cn/v1/user/info",
                currency: "CNY")
        )
        #expect(sfResult.balance == Decimal(string: "88.12"))

        // 4. New API (/api/usage/token 404 -> fallback /api/user/self + / 500000 divisor)
        let naTransport = StubHTTPTransport { req in
            if req.url?.path.contains("/api/usage/token") == true {
                return (Data(), self.makeHTTPResponse(url: req.url!, statusCode: 404))
            }
            #expect(req.url?.path.contains("/api/user/self") == true)
            let json = #"{"success":true,"data":{"quota":2500000}}"#
            return (Data(json.utf8), self.makeHTTPResponse(url: req.url!))
        }
        let naResult = try await APIBalanceService(transport: naTransport).fetchBalance(
            for: makeAPIItem(
                name: "New API", preset: "new_api", endpoint: "https://relay.example.com",
                parseRule: "total_available / 500000")
        )
        #expect(naResult.balance == Decimal(5))

        // 5. Sub2API & Custom dot-path
        let sub2Transport = StubHTTPTransport { req in
            let json = #"{"remaining":12.34}"#
            return (Data(json.utf8), self.makeHTTPResponse(url: req.url!))
        }
        let sub2Result = try await APIBalanceService(transport: sub2Transport).fetchBalance(
            for: makeAPIItem(name: "Sub2API", preset: "sub2api", endpoint: "https://s2.example.com")
        )
        #expect(sub2Result.balance == Decimal(string: "12.34"))

        let customTransport = StubHTTPTransport { req in
            let json = #"{"data":{"wallet":{"cents":1580}}}"#
            return (Data(json.utf8), self.makeHTTPResponse(url: req.url!))
        }
        let customResult = try await APIBalanceService(transport: customTransport).fetchBalance(
            for: makeAPIItem(
                name: "Custom API", preset: "custom", endpoint: "https://custom.example.com/bal",
                parseRule: "data.wallet.cents / 100")
        )
        #expect(customResult.balance == Decimal(string: "15.80"))
    }

    @Test("MainViewModel 刷新余额低于阈值时写入最新余额并触发本地低余额通知")
    @MainActor
    func testLowBalanceRefreshAndAlert() async throws {
        let recorder = RecordingNotificationService()
        let lowTransport = StubHTTPTransport { req in
            let json = #"{"balance_infos":[{"currency":"CNY","total_balance":"4.20"}]}"#
            return (Data(json.utf8), self.makeHTTPResponse(url: req.url!))
        }
        let container = AppContainer.makeMock(
            notificationService: recorder,
            apiBalanceService: APIBalanceService(transport: lowTransport)
        )
        let item = makeAPIItem(
            name: "DeepSeek Alert", preset: "deepseek", endpoint: "https://api.deepseek.com/user/balance",
            threshold: "10", currency: "CNY")
        try await container.repository.saveSubscription(item, initialRecords: [])

        let vm = MainViewModel(container: container)
        await vm.loadAll()

        let result = await vm.refreshAPIBalance(for: item)
        #expect(result?.balance == Decimal(string: "4.20"))
        #expect(recorder.lowBalanceAlerts.count == 1)
        #expect(recorder.lowBalanceAlerts.first?.name == "DeepSeek Alert")

        let updated = try #require(vm.subscriptions.first(where: { $0.id == item.id }))
        #expect(updated.fieldValue(forKey: "current_balance") == "4.20")
    }

    @Test("CSV 财务流水导出（含退款负号与引号转义）及 JSON 全量备份与恢复")
    func testCSVAndJSONBackupRoundTrip() async throws {
        let repo1 = MockSubscriptionRepository(useSampleData: true)
        let subId = UUID()
        let now = Date()
        let refundItem = SubscriptionItem(
            id: subId,
            name: "Pro, \"Cloud\"",
            categoryId: SubscriptionCategory.BuiltinID.cloudInfra,
            templateId: TemplateDefinition.BuiltinID.vps,
            price: 100,
            currency: "USD",
            billingCycleType: .monthly,
            startDate: now,
            nextRenewalDate: now
        )
        let refundRec = BillingRecord(
            subscriptionId: subId,
            amount: 25,
            currency: "USD",
            baseCurrencyAmount: 180,
            billedAt: Date(),
            source: .manualLedger,
            kind: .refund,
            note: "退差价, 第1期"
        )
        try await repo1.saveSubscription(refundItem, initialRecords: [refundRec])

        let service = BackupExportService()
        let csv = try await service.exportLedgerCSV(from: repo1, baseCurrency: "CNY")
        #expect(csv.hasPrefix("\u{FEFF}日期,订阅名称"))
        #expect(csv.contains("\"Pro, \"\"Cloud\"\"\""))
        #expect(csv.contains("-25"))

        let jsonData = try await service.exportJSONBackup(from: repo1, includeSecrets: false)

        // 恢复到一个全新空白 SQLite repository
        let db2 = try SQLiteDatabase(path: ":memory:")
        try await DatabaseMigrator.migrateIfNeeded(db2)
        let repo2 = SQLiteSubscriptionRepository(database: db2, secretStore: InMemorySecretStore())

        let stats = try await service.restoreJSONBackup(data: jsonData, into: repo2)
        #expect(stats.restoredSubscriptions >= 6)
        let restoredSub = try await repo2.fetchSubscription(id: subId)
        #expect(restoredSub?.name == "Pro, \"Cloud\"")
        let restoredRecords = try await repo2.fetchBillingRecords(for: subId)
        #expect(restoredRecords.first?.kind == .refund)
    }
}
