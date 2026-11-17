import Foundation

/// 全局依赖注入容器（产品运行期统一注入真实本地 SQLite 与网络实现）
@MainActor
public final class AppContainer {
    public let repository: SubscriptionRepositoryProtocol
    public let billingEngine: BillingEngineProtocol
    public let iconService: IconServiceProtocol
    public let notificationService: NotificationServiceProtocol
    public let exchangeRateService: ExchangeRateServiceProtocol
    public let secretStore: SecretStoreProtocol
    public let apiBalanceService: APIBalanceServiceProtocol

    public init(
        repository: SubscriptionRepositoryProtocol,
        billingEngine: BillingEngineProtocol,
        iconService: IconServiceProtocol,
        notificationService: NotificationServiceProtocol,
        exchangeRateService: ExchangeRateServiceProtocol,
        secretStore: SecretStoreProtocol,
        apiBalanceService: APIBalanceServiceProtocol
    ) {
        self.repository = repository
        self.billingEngine = billingEngine
        self.iconService = iconService
        self.notificationService = notificationService
        self.exchangeRateService = exchangeRateService
        self.secretStore = secretStore
        self.apiBalanceService = apiBalanceService
    }

    public static func makeProductionSync(databaseURL: URL? = nil) throws -> AppContainer {
        let dbURL = try databaseURL ?? SQLiteDatabase.defaultDatabaseURL()
        let database = try SQLiteDatabase(path: dbURL.path) { conn in
            try DatabaseMigrator.migrateIfNeeded(connection: conn)
        }
        return try makeProductionContainer(database: database, databasePath: dbURL.path)
    }

    public static func makeInMemoryProductionSync() throws -> AppContainer {
        let database = try SQLiteDatabase(path: ":memory:") { conn in
            try DatabaseMigrator.migrateIfNeeded(connection: conn)
        }
        return try makeProductionContainer(database: database, databasePath: ":memory:")
    }

    public static func makeProduction(databaseURL: URL? = nil) async throws -> AppContainer {
        try makeProductionSync(databaseURL: databaseURL)
    }

    private static func makeProductionContainer(database: SQLiteDatabase, databasePath: String) throws -> AppContainer {
        let secretStore = try SQLiteSecretStore(databasePath: databasePath)
        let repo = SQLiteSubscriptionRepository(database: database, secretStore: secretStore)
        let exchangeRateService = ExchangeRateService(database: database)

        return AppContainer(
            repository: repo,
            billingEngine: BillingEngine(),
            iconService: IconService(),
            notificationService: LocalNotificationService(),
            exchangeRateService: exchangeRateService,
            secretStore: secretStore,
            apiBalanceService: APIBalanceService()
        )
    }
}
