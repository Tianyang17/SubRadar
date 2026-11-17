import Foundation
import Testing

@testable import SubRadarCore

private final class MockUpdateHTTPTransport: HTTPTransportProtocol, @unchecked Sendable {
    let handler: @Sendable (URLRequest) throws -> (Data, HTTPURLResponse)

    init(handler: @escaping @Sendable (URLRequest) throws -> (Data, HTTPURLResponse)) {
        self.handler = handler
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try handler(request)
    }
}

@Suite("SQLite 本地敏感存储、系统报错文案与自动更新测试")
struct SQLiteSecretsAndUpdateTests {
    @Test("SQLiteSecretStore 与主数据库共享文件路径并持久化读写删")
    func testSQLiteSecretStorePersistence() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("subradar-secret-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let dbURL = tmpDir.appendingPathComponent("subradar.sqlite")
        let database = try SQLiteDatabase(path: dbURL.path)
        try await DatabaseMigrator.migrateIfNeeded(database)
        #expect(try await database.userVersion() == 21)

        let secretStore = try SQLiteSecretStore(databasePath: dbURL.path)
        let repo = SQLiteSubscriptionRepository(database: database, secretStore: secretStore)

        var sub = SubscriptionItem(
            name: "DeepSeek Secret Test",
            categoryId: SubscriptionCategory.BuiltinID.aiTools,
            templateId: TemplateDefinition.BuiltinID.apiBalance,
            price: Decimal(100),
            currency: "CNY",
            billingCycleType: .oneTime,
            nextRenewalDate: Date()
        )
        sub.customFields = [
            CustomField(
                subscriptionId: sub.id,
                key: "api_key",
                label: "API Key",
                type: .secret,
                value: "sk-sqlite-secret-999"
            )
        ]

        try await repo.saveSubscription(sub)
        let fetched = try await repo.fetchSubscription(id: sub.id)
        #expect(fetched?.fieldValue(forKey: "api_key") == "sk-sqlite-secret-999")

        try await repo.deleteSubscription(id: sub.id)
        let afterDelete = try secretStore.loadSecret(forKey: "subradar.field.\(sub.customFields[0].id.uuidString)")
        #expect(afterDelete == nil)
    }

    @Test("AppSettingsStore 更新默认配置与持久化")
    @MainActor
    func testUpdateSettingsPersistence() {
        let suiteName = "subradar.defaults.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = AppSettingsStore(userDefaults: defaults)
        #expect(store.autoCheckForUpdates == true)

        store.autoCheckForUpdates = false
        let reloaded = AppSettingsStore(userDefaults: defaults)
        #expect(reloaded.autoCheckForUpdates == false)
    }

    @Test("SemanticVersion 比较与 AppUpdateManager 检测新版并触发提醒状态")
    @MainActor
    func testUpdateManagerDetectionAndSemanticVersion() async throws {
        #expect(SemanticVersion("1.0.1") > SemanticVersion("1.0.0"))
        #expect(SemanticVersion("v1.10.0") > SemanticVersion("v1.2.9"))
        #expect(!(SemanticVersion("1.0.0") > SemanticVersion("1.0.0")))

        let suiteName = "subradar.update.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettingsStore(userDefaults: defaults)
        settings.customUpdateFeedURL = "https://example.com/releases/latest/download/latest.json"

        let manifest = AppUpdateManifest(
            version: "9.9.9",
            build: 99,
            notes: "新版本特性：双架构 DMG 与自动静默更新",
            releasePageURL: "https://example.com/releases/tag/v9.9.9",
            assets: [
                AppUpdateArchitecture.current.rawValue: AppUpdateAsset(
                    dmgURL: "https://example.com/SubRadar-v9.9.9.dmg",
                    sha256: "abc123"
                )
            ]
        )
        let manifestData = try JSONEncoder().encode(manifest)
        let transport = MockUpdateHTTPTransport { request in
            let http = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
            return (manifestData, http)
        }

        let manager = AppUpdateManager(settings: settings, transport: transport)
        await manager.checkForUpdates(manual: true)

        #expect(manager.availableRelease?.version == "9.9.9")
        #expect(manager.availableRelease?.dmgURL?.absoluteString == "https://example.com/SubRadar-v9.9.9.dmg")
        #expect(manager.showUpdatePrompt == true)

        manager.skipCurrentAvailableVersion()
        #expect(settings.skippedUpdateVersion == "9.9.9")
        #expect(manager.showUpdatePrompt == false)
    }

    @Test("网络错误文案为用户提供友好中文提示")
    func testFriendlyNetworkErrorMessages() {
        let offlineMsg = URLError(.notConnectedToInternet).userFacingMessage
        #expect(offlineMsg.contains("网络"))
    }

    @Test("AppContainer.makeProductionSync 同步建库迁移到 V14 并真实持久化订阅与密钥")
    @MainActor
    func testProductionSyncBootstrapAndPersistence() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("subradar-prod-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let dbURL = tmpDir.appendingPathComponent("subradar.sqlite")
        let container1 = try AppContainer.makeProductionSync(databaseURL: dbURL)
        #expect(try await container1.repository.fetchCategories().count == 6)
        #expect(try await container1.repository.fetchTemplates().count == 7)
        #expect(try await container1.repository.fetchSubscriptions().isEmpty)

        var sub = SubscriptionItem(
            name: "Production Persist Test",
            categoryId: SubscriptionCategory.BuiltinID.aiTools,
            templateId: TemplateDefinition.BuiltinID.apiBalance,
            price: Decimal(50),
            currency: "CNY",
            billingCycleType: .oneTime,
            nextRenewalDate: Date()
        )
        sub.customFields = [
            CustomField(
                subscriptionId: sub.id,
                key: "api_key",
                label: "API Key",
                type: .secret,
                value: "sk-prod-persist-010"
            )
        ]
        try await container1.repository.saveSubscription(sub, initialRecords: [])

        let container2 = try AppContainer.makeProductionSync(databaseURL: dbURL)
        let fetched = try await container2.repository.fetchSubscription(id: sub.id)
        #expect(fetched?.name == "Production Persist Test")
        #expect(fetched?.fieldValue(forKey: "api_key") == "sk-prod-persist-010")
        #expect(SemanticVersion("0.2.0") > SemanticVersion("0.1.0"))
        #expect(SemanticVersion("0.1.0") > SemanticVersion("0.0.9"))
    }

    @Test("AppContainer.makeInMemoryProductionSync 纯内存生产兜底支持建库与真实持久化")
    @MainActor
    func testInMemoryProductionFallbackSync() async throws {
        let container = try AppContainer.makeInMemoryProductionSync()
        #expect(try await container.repository.fetchCategories().count == 6)
        #expect(try await container.repository.fetchTemplates().count == 7)

        var sub = SubscriptionItem(
            name: "Memory Fallback Test",
            categoryId: SubscriptionCategory.BuiltinID.aiTools,
            templateId: TemplateDefinition.BuiltinID.apiBalance,
            price: Decimal(20),
            currency: "USD",
            billingCycleType: .oneTime,
            nextRenewalDate: Date()
        )
        sub.customFields = [
            CustomField(
                subscriptionId: sub.id,
                key: "api_key",
                label: "API Key",
                type: .secret,
                value: "sk-memory-fallback"
            )
        ]
        try await container.repository.saveSubscription(sub, initialRecords: [])
        let fetched = try await container.repository.fetchSubscription(id: sub.id)
        #expect(fetched?.name == "Memory Fallback Test")
        #expect(fetched?.fieldValue(forKey: "api_key") == "sk-memory-fallback")
    }
}
