import Foundation
import Testing

@testable import SubRadarCore

@Suite("编辑器交互与字段排序测试")
struct EditorFormInteractionsTests {
    @MainActor
    @Test("Phase 33: 详情字段拖拽重排 sortOrder 重建、增删协同与持久化")
    func testCustomFieldReorderingAndSortOrderPersistence() async throws {
        let db = try SQLiteDatabase(path: ":memory:")
        try await DatabaseMigrator.migrateIfNeeded(db)
        let repo = SQLiteSubscriptionRepository(database: db, secretStore: InMemorySecretStore())
        let container = AppContainer.makeMock(repository: repo)

        let editor = EditorViewModel(
            container: container,
            templates: TemplatePresetManager.builtinTemplates,
            categories: CategoryPresetManager.builtinCategories,
            defaultTemplateId: TemplateDefinition.BuiltinID.streaming
        )
        editor.name = "Spotify"
        editor.priceText = "35"

        // 流媒体模版默认 4 个字段：account, plan_tier, payment_method, manage_url
        #expect(editor.customFields.count == 4)
        editor.addCustomField(label: "备用节点", type: .text)
        #expect(editor.customFields.count == 5)

        let addedField = try #require(editor.customFields.last)
        let firstField = try #require(editor.customFields.first)
        // 把新增的最后一项拖拽到第一项位置
        editor.moveCustomField(fromId: addedField.id, toTargetId: firstField.id)

        #expect(editor.customFields.first?.id == addedField.id)
        #expect(editor.customFields.map(\.sortOrder) == [0, 1, 2, 3, 4])

        // 向下把原首项 account 移动到末尾 manage_url 之后
        let lastField = try #require(editor.customFields.last)
        editor.moveCustomField(fromId: firstField.id, toTargetId: lastField.id)
        #expect(editor.customFields.last?.id == firstField.id)
        #expect(editor.customFields.map(\.sortOrder) == [0, 1, 2, 3, 4])

        // 删除其中一项后，sortOrder 依然连续无空洞且不会越界
        let midId = editor.customFields[2].id
        editor.removeCustomField(id: midId)
        #expect(editor.customFields.count == 4)
        #expect(editor.customFields.map(\.sortOrder) == [0, 1, 2, 3])

        // 保存并重新读取，顺序完整保留
        let expectedOrderKeys = editor.customFields.map(\.key)
        let saved = try await editor.save(baseCurrency: "CNY")
        let fetched = try #require(try await repo.fetchSubscription(id: saved.id))
        let persistedKeys = fetched.customFields.sorted(by: { $0.sortOrder < $1.sortOrder }).map(\.key)
        #expect(persistedKeys == expectedOrderKeys)
    }

    @MainActor
    @Test("Phase 34: 新建订阅接入用户默认币种与提醒天数后，未编辑时无未保存变更提示")
    func testNewEditorWithCustomSettingsHasNoUnsavedChanges() throws {
        let container = try AppContainer.makeInMemoryProductionSync()
        let editor = EditorViewModel(
            container: container,
            templates: TemplatePresetManager.builtinTemplates,
            categories: CategoryPresetManager.builtinCategories,
            existingItem: nil,
            defaultCategoryId: nil,
            defaultCurrency: "USD",
            defaultReminderDays: 14
        )
        #expect(editor.currency == "USD")
        #expect(editor.reminderDaysBefore == 14)
        #expect(editor.hasUnsavedChanges == false)
        #expect(editor.changeSummaryLines.isEmpty)

        // 用户真实修改提醒天数后才应检出变更
        editor.reminderDaysBefore = 7
        #expect(editor.hasUnsavedChanges == true)
        #expect(editor.changeSummaryLines.contains("续订方式或到期提醒策略"))
    }

    @Test("Phase 35: 日期字符串解析与日历年月手动编辑校验")
    func testDateInputAndYearMonthParsing() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let standard = SubRadarFormatter.parseDateInput("2026-11-03", calendar: cal)
        #expect(
            standard.map { cal.dateComponents([.year, .month, .day], from: $0) }
                == DateComponents(year: 2026, month: 11, day: 3))

        let slashShort = SubRadarFormatter.parseDateInput("2026/3/9", calendar: cal)
        #expect(
            slashShort.map { cal.dateComponents([.year, .month, .day], from: $0) }
                == DateComponents(year: 2026, month: 3, day: 9))

        let compact = SubRadarFormatter.parseDateInput("20280229", calendar: cal)
        #expect(
            compact.map { cal.dateComponents([.year, .month, .day], from: $0) }
                == DateComponents(year: 2028, month: 2, day: 29))

        // 非法日历日期应严格返回 nil 而非溢出进位
        #expect(SubRadarFormatter.parseDateInput("2026-02-29", calendar: cal) == nil)
        #expect(SubRadarFormatter.parseDateInput("2026-02-30", calendar: cal) == nil)
        #expect(SubRadarFormatter.parseDateInput("2026-13-01", calendar: cal) == nil)
        #expect(SubRadarFormatter.parseDateInput("1899-12-31", calendar: cal) == nil)
        #expect(SubRadarFormatter.parseDateInput("invalid", calendar: cal) == nil)

        // 年月跳月校验
        let jumped = SubRadarFormatter.resolveYearMonth(yearText: "2024", monthText: "7", calendar: cal)
        #expect(
            jumped.map { cal.dateComponents([.year, .month, .day], from: $0) }
                == DateComponents(year: 2024, month: 7, day: 1))
        #expect(SubRadarFormatter.resolveYearMonth(yearText: "2024", monthText: "13", calendar: cal) == nil)
        #expect(SubRadarFormatter.resolveYearMonth(yearText: "20", monthText: "11", calendar: cal) == nil)
    }

    @MainActor
    @Test("Phase 36: 手动历史开销自动按 空白 -> 最近日期 -> 最远日期 排列")
    func testManualHistoryAutoOrderingBlankNewestToOldest() throws {
        let container = try AppContainer.makeInMemoryProductionSync()
        let editor = EditorViewModel(
            container: container,
            templates: TemplatePresetManager.builtinTemplates,
            categories: CategoryPresetManager.builtinCategories
        )

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let today = cal.date(from: DateComponents(year: 2026, month: 11, day: 16))!
        let olderNov03 = cal.date(from: DateComponents(year: 2026, month: 11, day: 3))!
        let oldestOct01 = cal.date(from: DateComponents(year: 2026, month: 10, day: 1))!

        // 1. 新增两条空白条目并把其中一条改为更早日期（尚未填金额），应自动排到后面
        editor.addManualHistoryEntry(billedAt: today)
        let firstBlankId = try #require(editor.manualHistoryEntries.first?.id)
        editor.addManualHistoryEntry(billedAt: today)
        let secondBlankId = try #require(editor.manualHistoryEntries.first?.id)

        // 把顶部刚添加的条目的日期改成 2026-11-03：未修改过日期的空白草稿应留在最上方
        editor.updateManualHistoryDate(id: secondBlankId, to: olderNov03)
        #expect(editor.manualHistoryEntries.map(\.id) == [firstBlankId, secondBlankId])

        // 2. 给 firstBlankId 填入日期 2026-11-16 与金额，并再新添一条更早 2026-10-01 条目
        editor.updateManualHistoryDate(id: firstBlankId, to: today)
        if let idx = editor.manualHistoryEntries.firstIndex(where: { $0.id == firstBlankId }) {
            editor.manualHistoryEntries[idx].amountText = "50"
        }
        editor.addManualHistoryEntry(billedAt: oldestOct01, amountText: "120")
        let octId = try #require(editor.manualHistoryEntries.first(where: { $0.amountText == "120" })?.id)

        // 再点击新增一行纯空白草稿
        editor.addManualHistoryEntry(billedAt: today)
        let freshBlankId = try #require(editor.manualHistoryEntries.first?.id)

        // 从上到下应严格为：[空白, 最近(2026-11-16), 中间(2026-11-03), 最远(2026-10-01)]
        #expect(editor.manualHistoryEntries.map(\.id) == [freshBlankId, firstBlankId, secondBlankId, octId])
    }

    @MainActor
    @Test("Phase 37: 软件与激活码新增多选平台字段与 V19 迁移")
    func testSoftwarePlatformMultiSelectAndV19Migration() async throws {
        #expect(FieldOptionCatalog.softwarePlatforms == ["Mac", "iPhone", "iPad", "Android", "Windows", "Linux"])

        let toggled1 = FieldOptionCatalog.togglingPlatform("Linux", in: "")
        #expect(toggled1 == "Linux")
        let toggled2 = FieldOptionCatalog.togglingPlatform("Mac", in: toggled1)
        #expect(toggled2 == "Mac / Linux")
        let toggled3 = FieldOptionCatalog.togglingPlatform("iPad", in: toggled2)
        #expect(toggled3 == "Mac / iPad / Linux")
        let toggled4 = FieldOptionCatalog.togglingPlatform("iPad", in: toggled3)
        #expect(toggled4 == "Mac / Linux")

        let db = try SQLiteDatabase(path: ":memory:")
        try await DatabaseMigrator.migrateIfNeeded(db)
        #expect(try await db.userVersion() >= 19)

        let repo = SQLiteSubscriptionRepository(database: db, secretStore: InMemorySecretStore())
        let templates = try await repo.fetchTemplates()
        let softwareTemplate = try #require(
            templates.first(where: { $0.id == TemplateDefinition.BuiltinID.softwareLicense })
        )
        let platformSchema = try #require(
            softwareTemplate.defaultFields.first(where: { $0.key == "supported_platforms" })
        )
        #expect(platformSchema.label == "平台")

        let container = AppContainer.makeMock(repository: repo)
        let editor = EditorViewModel(
            container: container,
            templates: templates,
            categories: CategoryPresetManager.builtinCategories,
            defaultTemplateId: TemplateDefinition.BuiltinID.softwareLicense
        )
        editor.name = "1Password"
        editor.priceText = "99"
        editor.updatePurchaseSource("App Store")
        #expect(editor.customFields.contains(where: { $0.key == "supported_platforms" }))

        if let idx = editor.customFields.firstIndex(where: { $0.key == "supported_platforms" }) {
            editor.customFields[idx].value = toggled3
        }
        let saved = try await editor.save(baseCurrency: "CNY")
        let fetched = try #require(try await repo.fetchSubscription(id: saved.id))
        #expect(fetched.fieldValue(forKey: "supported_platforms") == "Mac / iPad / Linux")
    }

    @MainActor
    @Test("Phase 39 & 42: 自定义模版恒置末尾、V21 清理历史内置 VPN 分类与模版")
    func testTemplateCustomAlwaysLastAndV21Cleanup() async throws {
        let db = try SQLiteDatabase(path: ":memory:")
        try await DatabaseMigrator.migrateIfNeeded(db)
        try await db.performTransaction { conn in
            // 模拟存量库中曾存在旧内置 VPN 分类/模版，且 custom 时间戳更早
            try conn.execute(
                """
                INSERT OR IGNORE INTO categories (id, name, icon_symbol, color_key, is_builtin, sort_order, created_at)
                VALUES ('00000000-0000-0000-0002-000000000008', 'VPN', 'shield.lefthalf.filled', 'cyan', 1, 6, 1500);
                """
            )
            try conn.execute(
                """
                INSERT OR IGNORE INTO templates (id, name, icon_symbol, is_builtin, default_fields_json, created_at)
                VALUES ('00000000-0000-0000-0000-000000000008', 'VPN', 'shield.lefthalf.filled', 1, '[]', 2000);
                """
            )
            try conn.execute(
                "UPDATE templates SET created_at = 1000 WHERE id = ?;",
                bindings: [.text(TemplateDefinition.BuiltinID.custom.uuidString)]
            )
            try conn.execute("PRAGMA user_version = 20;")
        }
        try await DatabaseMigrator.migrateIfNeeded(db)
        #expect(try await db.userVersion() == 21)

        let repo = SQLiteSubscriptionRepository(database: db, secretStore: InMemorySecretStore())
        let categories = try await repo.fetchCategories()
        #expect(categories.count == 6)
        #expect(!categories.contains(where: { $0.id.uuidString == "00000000-0000-0000-0002-000000000008" }))

        try await repo.saveTemplate(
            TemplateDefinition(
                name: "用户自建模版",
                iconSymbol: "star.fill",
                isBuiltin: false,
                defaultFields: [FieldSchema(key: "k1", label: "K1", type: .text)]
            )
        )

        let templates = try await repo.fetchTemplates()
        #expect(templates.count == 8)
        #expect(!templates.contains(where: { $0.id.uuidString == "00000000-0000-0000-0000-000000000008" }))
        #expect(templates.last?.id == TemplateDefinition.BuiltinID.custom)

        #expect(!PopularSoftwarePresetManager.allPresets.contains(where: { $0.id == "ss-id" }))
        #expect(PopularSoftwareGroup.allCases.count == 6)
    }

    @Test("Phase 40: SUBRADAR_DB_PATH 环境变量支持隔离数据库路径")
    func testDatabaseURLRespectsIsolatedOverrideEnvironment() throws {
        let customPath = NSTemporaryDirectory() + "subradar-override-\(UUID().uuidString)/demo.sqlite"
        let resolved = try SQLiteDatabase.defaultDatabaseURL(environment: ["SUBRADAR_DB_PATH": customPath])
        #expect(resolved.path == customPath)
        try? FileManager.default.removeItem(at: resolved.deletingLastPathComponent())
    }
}
