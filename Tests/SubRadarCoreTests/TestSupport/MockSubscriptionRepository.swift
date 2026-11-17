import Foundation

@testable import SubRadarCore

/// 内存态 Mock 数据仓库（供 Phase 2 UI 体验与单测使用）
public actor MockSubscriptionRepository: SubscriptionRepositoryProtocol {
    private var categories: [SubscriptionCategory]
    private var templates: [TemplateDefinition]
    private var subscriptions: [UUID: SubscriptionItem] = [:]
    private var billingRecords: [BillingRecord] = []

    public init(useSampleData: Bool = true) {
        self.categories = CategoryPresetManager.builtinCategories
        self.templates = TemplatePresetManager.builtinTemplates
        if useSampleData {
            let sample = MockSampleData.makeInitialData()
            for item in sample.subscriptions {
                self.subscriptions[item.id] = item
            }
            self.billingRecords = sample.records
        }
    }

    // MARK: - Categories

    public func fetchCategories() async throws -> [SubscriptionCategory] {
        categories.sorted { ($0.sortOrder, $0.createdAt) < ($1.sortOrder, $1.createdAt) }
    }

    public func saveCategory(_ category: SubscriptionCategory) async throws {
        if let idx = categories.firstIndex(where: { $0.id == category.id }) {
            categories[idx] = category
        } else {
            categories.append(category)
        }
    }

    public func deleteCategory(id: UUID) async throws {
        guard let target = categories.first(where: { $0.id == id }), !target.isBuiltin else { return }
        categories.removeAll { $0.id == id }
        let fallbackId = SubscriptionCategory.BuiltinID.productivity
        for (subId, var item) in subscriptions where item.categoryId == id {
            item.categoryId = fallbackId
            subscriptions[subId] = item
        }
    }

    // MARK: - Templates

    public func fetchTemplates() async throws -> [TemplateDefinition] {
        templates.sorted { ($0.isBuiltin ? 0 : 1, $0.createdAt) < ($1.isBuiltin ? 0 : 1, $1.createdAt) }
    }

    public func saveTemplate(_ template: TemplateDefinition) async throws {
        if let idx = templates.firstIndex(where: { $0.id == template.id }) {
            templates[idx] = template
        } else {
            templates.append(template)
        }
    }

    public func deleteTemplate(id: UUID) async throws {
        templates.removeAll { $0.id == id && !$0.isBuiltin }
    }

    // MARK: - Subscriptions

    public func fetchSubscriptions() async throws -> [SubscriptionItem] {
        subscriptions.values.sorted { $0.nextRenewalDate < $1.nextRenewalDate }
    }

    public func fetchSubscription(id: UUID) async throws -> SubscriptionItem? {
        subscriptions[id]
    }

    public func saveSubscription(_ item: SubscriptionItem, initialRecords: [BillingRecord] = []) async throws {
        try item.validate()
        subscriptions[item.id] = item
        if !initialRecords.isEmpty {
            billingRecords.append(contentsOf: initialRecords)
        }
    }

    public func deleteSubscription(id: UUID) async throws {
        subscriptions.removeValue(forKey: id)
        billingRecords.removeAll { $0.subscriptionId == id }
    }

    // MARK: - Billing Records

    public func fetchBillingRecords(for subscriptionId: UUID) async throws -> [BillingRecord] {
        billingRecords
            .filter { $0.subscriptionId == subscriptionId }
            .sorted { $0.billedAt > $1.billedAt }
    }

    public func fetchBillingRecords(from startDate: Date, to endDate: Date) async throws -> [BillingRecord] {
        billingRecords
            .filter { $0.billedAt >= startDate && $0.billedAt <= endDate }
            .sorted { $0.billedAt > $1.billedAt }
    }

    public func addBillingRecord(_ record: BillingRecord) async throws {
        billingRecords.append(record)
    }

    public func updateBillingRecord(_ record: BillingRecord) async throws {
        if let index = billingRecords.firstIndex(where: { $0.id == record.id }) {
            billingRecords[index] = record
        }
    }

    public func deleteBillingRecord(id: UUID) async throws {
        billingRecords.removeAll { $0.id == id }
    }

    public func totalSpent(for subscriptionId: UUID) async throws -> Decimal {
        billingRecords
            .filter { $0.subscriptionId == subscriptionId }
            .reduce(Decimal.zero) { $0 + $1.signedAmount }
    }
}
