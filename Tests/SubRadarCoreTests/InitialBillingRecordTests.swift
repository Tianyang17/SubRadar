import Foundation
import Testing

@testable import SubRadarCore

@Suite("Phase 19: 新建默认首期购买流水与 V17 存量补录测试")
struct InitialBillingRecordTests {
    @Test("新建非 API 余额订阅未勾选历史计费时默认写入 1 笔首期购买流水并计入大盘总额")
    @MainActor
    func testNewSubscriptionWritesInitialPurchaseRecordByDefault() async throws {
        let container = AppContainer.makeMock()
        let emptyRepo = MockSubscriptionRepository(useSampleData: false)
        let isolatedContainer = AppContainer.makeMock(repository: emptyRepo)
        _ = container

        let templates = try await emptyRepo.fetchTemplates()
        let categories = try await emptyRepo.fetchCategories()
        let editorVM = EditorViewModel(
            container: isolatedContainer,
            templates: templates,
            categories: categories,
            existingItem: nil
        )
        editorVM.switchTemplate(to: TemplateDefinition.BuiltinID.vps)
        editorVM.name = "DediRock VPS"
        editorVM.priceText = "79.25"
        editorVM.currency = "CNY"
        editorVM.billingCycleType = .annually
        editorVM.includeHistoricalBilling = false

        let saved = try await editorVM.save(baseCurrency: "CNY")
        let records = try await emptyRepo.fetchBillingRecords(for: saved.id)
        #expect(records.count == 1)
        #expect(records.first?.source == .initialPurchase)
        #expect(records.first?.kind == .charge)
        #expect(records.first?.amount == Decimal(string: "79.25"))

        let analyticsVM = AnalyticsViewModel(container: isolatedContainer)
        analyticsVM.selectedRangePreset = .allTime
        await analyticsVM.reloadAnalytics()
        #expect(analyticsVM.summary?.records.count == 1)
        #expect(analyticsVM.summary?.totalBaseAmount == Decimal(string: "79.25"))
    }

    @Test("SQLite V17 迁移为无流水存量订阅幂等补录 1 笔初始购买流水")
    func testSQLiteV17BackfillsMissingInitialRecordsIdempotently() async throws {
        let db = try SQLiteDatabase(path: ":memory:")
        try await DatabaseMigrator.migrateIfNeeded(db)
        let version = try await db.userVersion()
        #expect(version == 21)

        let secretStore = InMemorySecretStore()
        let repo = SQLiteSubscriptionRepository(database: db, secretStore: secretStore)
        let now = Date()

        // 1. 插入 1 条 price > 0 但故意不写任何流水记录的存量订阅，再回退 user_version 至 16 验证 V17 迁移
        let missingLedgerSub = SubscriptionItem(
            name: "存量 VPS",
            categoryId: SubscriptionCategory.BuiltinID.cloudInfra,
            templateId: TemplateDefinition.BuiltinID.vps,
            price: Decimal(string: "79.25") ?? 79.25,
            currency: "CNY",
            billingCycleType: .annually,
            startDate: now,
            nextRenewalDate: now.addingTimeInterval(86400 * 365)
        )
        try await repo.saveSubscription(missingLedgerSub, initialRecords: [])

        // 2. 插入 1 条 0 元订阅（不应补录流水）
        let zeroSub = SubscriptionItem(
            name: "免费软件",
            categoryId: SubscriptionCategory.BuiltinID.productivity,
            templateId: TemplateDefinition.BuiltinID.softwareLicense,
            price: 0,
            currency: "CNY",
            billingCycleType: .oneTime,
            startDate: now,
            nextRenewalDate: now
        )
        try await repo.saveSubscription(zeroSub, initialRecords: [])

        try await db.setUserVersion(16)
        try await DatabaseMigrator.migrateIfNeeded(db)
        #expect(try await db.userVersion() == 21)

        let backfilled = try await repo.fetchBillingRecords(for: missingLedgerSub.id)
        #expect(backfilled.count == 1)
        #expect(backfilled.first?.amount == Decimal(string: "79.25"))
        #expect(backfilled.first?.source == .initialPurchase)

        let zeroRecords = try await repo.fetchBillingRecords(for: zeroSub.id)
        #expect(zeroRecords.isEmpty)
    }
}
