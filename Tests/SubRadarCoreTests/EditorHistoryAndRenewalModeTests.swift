import Foundation
import Testing

@testable import SubRadarCore

@Suite("Phase 13: RenewalMode 自定义续订方式与编辑器手动历史开销")
struct EditorHistoryAndRenewalModeTests {
    @Test("RenewalMode 向后兼容旧 JSON 备份与 autoRenew 默认推导")
    func testRenewalModeCodableAndBackwardCompatibility() throws {
        let legacyJSON = """
            {
              "id": "00000000-0000-0000-0000-000000000111",
              "name": "Legacy Sub",
              "categoryId": "00000000-0000-0000-0002-000000000001",
              "templateId": "00000000-0000-0000-0001-000000000001",
              "price": 15,
              "currency": "CNY",
              "billingCycleType": "monthly",
              "startDate": 1700000000,
              "nextRenewalDate": 1702592000,
              "autoRenew": true,
              "status": "active",
              "reminderDaysBefore": 3,
              "notes": "",
              "customFields": [],
              "createdAt": 1700000000,
              "updatedAt": 1700000000
            }
            """
        let decoded = try JSONDecoder().decode(SubscriptionItem.self, from: Data(legacyJSON.utf8))
        #expect(decoded.renewalMode == .automatic)
        #expect(decoded.customRenewalNote == "")
        #expect(decoded.renewalModeDisplayText == "自动续费")

        let customItem = SubscriptionItem(
            name: "Custom VPS",
            templateId: TemplateDefinition.BuiltinID.vps,
            price: 99,
            currency: "CNY",
            billingCycleType: .annually,
            nextRenewalDate: Date(),
            autoRenew: true,
            renewalMode: .custom,
            customRenewalNote: "到期发工单联系客服续费"
        )
        #expect(customItem.autoRenew == false)
        #expect(customItem.renewalMode == .custom)
        #expect(customItem.renewalModeDisplayText == "到期发工单联系客服续费")

        let emptyCustom = SubscriptionItem(
            name: "Blank Custom",
            templateId: TemplateDefinition.BuiltinID.streaming,
            price: 10,
            nextRenewalDate: Date(),
            renewalMode: .custom,
            customRenewalNote: "   "
        )
        #expect(emptyCustom.renewalModeDisplayText == "自定义")
    }

    @Test("SQLite V16 迁移自动回填历史 auto_renew 且支持保存读取自定义续订方式")
    func testSQLiteV16RenewalModeMigrationAndPersistence() async throws {
        let db = try SQLiteDatabase(path: ":memory:")
        try await DatabaseMigrator.migrateIfNeeded(db)
        #expect(try await db.userVersion() == 21)

        let secretStore = InMemorySecretStore()
        let repo = SQLiteSubscriptionRepository(database: db, secretStore: secretStore)

        let item = SubscriptionItem(
            name: "拼车 Notion",
            templateId: TemplateDefinition.BuiltinID.streaming,
            price: 45,
            currency: "CNY",
            billingCycleType: .annually,
            startDate: Date(),
            nextRenewalDate: Calendar.current.date(byAdding: .year, value: 1, to: Date())!,
            renewalMode: .custom,
            customRenewalNote: "每年黑五联系群主转账续订"
        )
        try await repo.saveSubscription(item, initialRecords: [])

        let fetched = try await repo.fetchSubscription(id: item.id)
        #expect(fetched?.renewalMode == .custom)
        #expect(fetched?.autoRenew == false)
        #expect(fetched?.customRenewalNote == "每年黑五联系群主转账续订")
    }

    @Test("编辑器支持在新建与编辑态手动添加多笔历史开销，并与周期自动累加安全共存")
    @MainActor
    func testEditorManualHistoricalExpensesNewAndEdit() async throws {
        let db = try SQLiteDatabase(path: ":memory:")
        try await DatabaseMigrator.migrateIfNeeded(db)
        let repo = SQLiteSubscriptionRepository(database: db, secretStore: InMemorySecretStore())
        let container = AppContainer.makeMock(repository: repo)

        let categories = try await repo.fetchCategories()
        let templates = try await repo.fetchTemplates()

        let cal = Calendar.current
        let now = Date()
        let twoYearsAgo = cal.date(byAdding: .year, value: -2, to: now)!
        let oneYearAgo = cal.date(byAdding: .year, value: -1, to: now)!

        // 1. 新建态：关闭按周期自动累加，仅手动添加 2 笔不同金额与类型的历史开销
        let vm = EditorViewModel(container: container, templates: templates, categories: categories)
        vm.name = "云盘会员"
        vm.priceText = "168"
        vm.currency = "CNY"
        vm.billingCycleType = .annually
        vm.startDate = twoYearsAgo
        vm.nextRenewalDate = cal.date(byAdding: .year, value: 1, to: now)!
        vm.renewalMode = .custom
        vm.customRenewalNote = "微信扫码手动续订"

        vm.addManualHistoryEntry(
            billedAt: twoYearsAgo,
            amountText: "118",
            currency: "CNY",
            kind: .charge,
            note: "首年双十一优惠"
        )
        vm.addManualHistoryEntry(
            billedAt: oneYearAgo,
            amountText: "20",
            currency: "CNY",
            kind: .refund,
            note: "活动差价退款"
        )
        #expect(vm.manualHistoryEntries.count == 2)
        #expect(vm.manualHistoryEntries.first?.note == "活动差价退款")
        #expect(vm.manualHistoryEntries.last?.note == "首年双十一优惠")
        #expect(vm.hasUnsavedChanges == true)
        #expect(vm.manualHistoryEstimatedTotal == Decimal(98))

        let saved = try await vm.save(baseCurrency: "CNY")
        #expect(saved.renewalMode == .custom)
        #expect(saved.customRenewalNote == "微信扫码手动续订")

        let recordsAfterCreate = try await repo.fetchBillingRecords(for: saved.id)
        #expect(recordsAfterCreate.count == 2)
        #expect(recordsAfterCreate.allSatisfy { $0.source == .manualLedger })

        // 2. 编辑态：再追加 1 笔手动历史开销并验证非法金额校验
        let editVM = EditorViewModel(
            container: container,
            templates: templates,
            categories: categories,
            existingItem: saved
        )
        #expect(editVM.hasUnsavedChanges == false)
        editVM.addManualHistoryEntry(
            billedAt: now.addingTimeInterval(-3600),
            amountText: "-5",
            currency: "CNY",
            kind: .charge,
            note: "非法负数"
        )
        #expect(editVM.hasUnsavedChanges == true)
        do {
            _ = try await editVM.save(baseCurrency: "CNY")
            Issue.record("预期负数历史开销应校验失败")
        } catch {
            #expect(editVM.validationErrorMessage?.isEmpty == false)
        }

        if let id = editVM.manualHistoryEntries.first?.id {
            editVM.removeManualHistoryEntry(id)
        }
        editVM.addManualHistoryEntry(
            billedAt: now.addingTimeInterval(-3600),
            amountText: "148",
            currency: "CNY",
            kind: .charge,
            note: "次年续费"
        )
        _ = try await editVM.save(baseCurrency: "CNY")

        let recordsAfterEdit = try await repo.fetchBillingRecords(for: saved.id)
        #expect(recordsAfterEdit.count == 3)
    }

    @Test("Phase 24: 手动历史开销待入账净额按实际条目币种及多币种汇总显示")
    @MainActor
    func testManualHistoryNetSummaryTextMultiCurrency() {
        let container = AppContainer.makeMock()
        let vm = EditorViewModel(container: container, templates: [], categories: [])
        vm.currency = "USD"

        // 1. 仅存在空白条目时使用首条或主币种
        vm.addManualHistoryEntry(amountText: "", currency: "USD")
        #expect(vm.manualHistoryNetSummaryText == "$0.00")

        // 2. 主订阅 USD 下填入一条 CNY 109.95 且另有空行 USD，仍准确显示 ¥109.95
        vm.addManualHistoryEntry(amountText: "109.95", currency: "CNY", kind: .charge)
        #expect(vm.manualHistoryNetSummaryText == "¥109.95")

        // 3. 同一币种退款冲红
        vm.addManualHistoryEntry(amountText: "9.95", currency: "CNY", kind: .refund)
        #expect(vm.manualHistoryNetSummaryText == "¥100.00")

        // 4. 多币种有效条目分币种拼接展示
        vm.addManualHistoryEntry(amountText: "20", currency: "USD", kind: .charge)
        #expect(vm.manualHistoryNetSummaryText == "$20.00 + ¥100.00")

        // 5. 纯退款净额为负时负号置于符号前
        let refundVM = EditorViewModel(container: container, templates: [], categories: [])
        refundVM.currency = "USD"
        refundVM.addManualHistoryEntry(amountText: "20", currency: "CNY", kind: .refund)
        #expect(refundVM.manualHistoryNetSummaryText == "-¥20.00")
    }

    @Test("Phase 26: RenewalMode.doNotRenew 持久化并从未来待续开销与月均估算中剔除")
    @MainActor
    func testDoNotRenewModePersistenceAndSpendExclusion() async throws {
        #expect(RenewalMode.allCases == [.automatic, .manual, .doNotRenew, .custom])
        #expect(RenewalMode.doNotRenew.displayName == "不再续费")

        let db = try SQLiteDatabase(path: ":memory:")
        try await DatabaseMigrator.migrateIfNeeded(db)
        let repo = SQLiteSubscriptionRepository(database: db, secretStore: InMemorySecretStore())
        let container = AppContainer.makeMock(repository: repo)

        let now = Date()
        let nextWeek = Calendar.current.date(byAdding: .day, value: 5, to: now)!

        let doNotRenewItem = SubscriptionItem(
            name: "临期不续 VPS",
            templateId: TemplateDefinition.BuiltinID.vps,
            price: 100,
            currency: "CNY",
            billingCycleType: .monthly,
            startDate: now,
            nextRenewalDate: nextWeek,
            renewalMode: .doNotRenew,
            status: .active
        )
        #expect(doNotRenewItem.autoRenew == false)
        #expect(doNotRenewItem.renewalModeDisplayText == "不再续费")
        try await repo.saveSubscription(doNotRenewItem, initialRecords: [])

        let fetched = try await repo.fetchSubscription(id: doNotRenewItem.id)
        #expect(fetched?.renewalMode == .doNotRenew)
        #expect(fetched?.autoRenew == false)

        let renewingItem = SubscriptionItem(
            name: "正常自动续费工具",
            templateId: TemplateDefinition.BuiltinID.streaming,
            price: 30,
            currency: "CNY",
            billingCycleType: .monthly,
            startDate: now,
            nextRenewalDate: nextWeek,
            renewalMode: .automatic,
            status: .active
        )
        try await repo.saveSubscription(renewingItem, initialRecords: [])

        let mainVM = MainViewModel(container: container)
        await mainVM.loadAll()
        #expect(mainVM.monthlyEstimatedBaseSpend == Decimal(30))

        let analyticsVM = AnalyticsViewModel(container: container)
        await analyticsVM.reloadAnalytics()
        let summary = try #require(analyticsVM.summary)
        #expect(summary.upcoming30DaysBaseAmount == Decimal(30))
        #expect(summary.upcomingRenewals.contains(where: { $0.subscriptionId == doNotRenewItem.id }))
    }
}
