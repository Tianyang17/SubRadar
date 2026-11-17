import Foundation

@testable import SubRadarCore

/// 单元测试专用内存敏感字段存储
final class InMemorySecretStore: SecretStoreProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: String] = [:]

    init() {}

    func saveSecret(_ value: String, forKey key: String) throws {
        lock.withLock { storage[key] = value }
    }

    func loadSecret(forKey key: String) throws -> String? {
        lock.withLock { storage[key] }
    }

    func deleteSecret(forKey key: String) throws {
        lock.withLock { _ = storage.removeValue(forKey: key) }
    }

    func authenticateUser(reason: String) async -> Bool {
        true
    }
}

/// 单元测试专用 API 余额模拟服务
final class MockAPIBalanceService: APIBalanceServiceProtocol {
    init() {}

    func fetchBalance(for item: SubscriptionItem) async throws -> APIBalanceResult {
        let current = Decimal(string: item.fieldValue(forKey: "current_balance") ?? "") ?? Decimal(string: "18.80")!
        return APIBalanceResult(balance: current, currency: item.currency)
    }
}

extension AppContainer {
    /// 仅供单元测试构建隔离的内存注入容器（产品 Target 不可见）
    @MainActor
    static func makeMock(
        repository: SubscriptionRepositoryProtocol? = nil,
        notificationService: NotificationServiceProtocol = MockNotificationService(),
        apiBalanceService: APIBalanceServiceProtocol = MockAPIBalanceService()
    ) -> AppContainer {
        AppContainer(
            repository: repository ?? MockSubscriptionRepository(useSampleData: true),
            billingEngine: BillingEngine(),
            iconService: MockIconService(),
            notificationService: notificationService,
            exchangeRateService: MockExchangeRateService(),
            secretStore: InMemorySecretStore(),
            apiBalanceService: apiBalanceService
        )
    }
}
