import Foundation

/// 订阅、分类、模版与流水数据持久层抽象协议
public protocol SubscriptionRepositoryProtocol: Sendable {
    // MARK: - Categories
    func fetchCategories() async throws -> [SubscriptionCategory]
    func saveCategory(_ category: SubscriptionCategory) async throws
    func deleteCategory(id: UUID) async throws

    // MARK: - Templates
    func fetchTemplates() async throws -> [TemplateDefinition]
    func saveTemplate(_ template: TemplateDefinition) async throws
    func deleteTemplate(id: UUID) async throws

    // MARK: - Subscriptions
    func fetchSubscriptions() async throws -> [SubscriptionItem]
    func fetchSubscription(id: UUID) async throws -> SubscriptionItem?
    func saveSubscription(_ item: SubscriptionItem, initialRecords: [BillingRecord]) async throws
    func deleteSubscription(id: UUID) async throws

    // MARK: - Billing Records
    func fetchBillingRecords(for subscriptionId: UUID) async throws -> [BillingRecord]
    func fetchBillingRecords(from startDate: Date, to endDate: Date) async throws -> [BillingRecord]
    func addBillingRecord(_ record: BillingRecord) async throws
    func updateBillingRecord(_ record: BillingRecord) async throws
    func deleteBillingRecord(id: UUID) async throws
    func totalSpent(for subscriptionId: UUID) async throws -> Decimal
}
