import Foundation
import ImageIO
import Testing

@testable import SubRadarCore

@Suite("Phase 2 ViewModel TDD 测试")
@MainActor
struct ViewModelPresetFeatureTests {
    @Test("Phase 6: 侧边栏直接增删改分类、按周月均折算与软件购买来源字段")
    func testSidebarCategoryCrudAndWeeklyAndSoftwareSource() async throws {
        let container = AppContainer.makeMock()
        let mainVM = MainViewModel(container: container)
        await mainVM.loadAll()

        let created = try await mainVM.createCategory(name: "开发服务", iconSymbol: "terminal", colorKey: .emerald)
        #expect(mainVM.categories.contains(where: { $0.id == created.id && $0.name == "开发服务" }))

        var updated = created
        updated.name = "云端与开发"
        updated.colorKey = .cyan
        try await mainVM.updateCategory(updated)
        #expect(mainVM.category(for: created.id)?.name == "云端与开发")

        // 添加按周付费订阅，校验月均估算
        let beforeMonthly = mainVM.monthlyEstimatedBaseSpend
        let weeklyItem = SubscriptionItem(
            name: "周付会员",
            categoryId: created.id,
            templateId: TemplateDefinition.BuiltinID.softwareLicense,
            price: 12,
            currency: "CNY",
            billingCycleType: .weekly,
            startDate: Date(),
            nextRenewalDate: Date()
        )
        try await container.repository.saveSubscription(weeklyItem, initialRecords: [])
        await mainVM.loadAll()
        let expectedDelta = Decimal(12) * Decimal(52) / Decimal(12)
        #expect(abs((mainVM.monthlyEstimatedBaseSpend - beforeMonthly) - expectedDelta) < Decimal(string: "0.01")!)

        // 删除自定义分类后，订阅回落到默认分类
        await mainVM.deleteCategory(updated)
        #expect(mainVM.categories.contains(where: { $0.id == created.id }) == false)

        // 验证软件模版包含 purchase_source
        let software = mainVM.templates.first(where: { $0.id == TemplateDefinition.BuiltinID.softwareLicense })
        #expect(software?.defaultFields.contains(where: { $0.key == "purchase_source" }) == true)
    }

    @Test("Phase 7: 常用软件预置库、AI 会员模版全量编辑与编辑器内联新建分类")
    func testPhase7PresetsTemplateEditAndInlineCategory() async throws {
        // 1. 验证国内外常用软件与 AI 服务预置库
        let presets = PopularSoftwarePresetManager.allPresets
        #expect(presets.count >= 24)
        #expect(
            PopularSoftwarePresetManager.search(query: "ChatGPT").first?.suggestedTemplateId
                == TemplateDefinition.BuiltinID.aiMembership)
        #expect(PopularSoftwarePresetManager.search(query: "copilot").contains(where: { $0.id == "github-copilot" }))
        let jetbrains = try #require(presets.first(where: { $0.id == "jetbrains" }))
        #expect(jetbrains.name == "JetBrains")
        #expect(jetbrains.group == .aiTools)
        #expect(jetbrains.presetFieldValues["manage_url"] == "https://account.jetbrains.com")
        #expect(PopularSoftwarePresetManager.search(query: "idea").contains(where: { $0.id == "jetbrains" }))
        #expect(PopularSoftwarePresetManager.search(query: "pycharm").contains(where: { $0.id == "jetbrains" }))
        #expect((PopularSoftwarePresetManager.bundledIconData(forPresetId: "jetbrains")?.count ?? 0) > 500)
        #expect(PopularSoftwarePresetManager.search(query: "哔哩哔哩").isEmpty == false)
        #expect(PopularSoftwarePresetManager.search(query: "QQ").isEmpty == false)

        // 2. 验证任意模版（含系统内置模版）均可通过 ViewModel 编辑更新
        let container = AppContainer.makeMock()
        let tmVM = TemplateManagerViewModel(container: container)
        await tmVM.loadTemplates()
        guard var vpsTemplate = tmVM.templates.first(where: { $0.id == TemplateDefinition.BuiltinID.vps }) else {
            Issue.record("缺少 VPS 内置模版")
            return
        }
        vpsTemplate.name = "云服务器节点"
        vpsTemplate.defaultFields.append(FieldSchema(key: "panel_url", label: "探针地址", type: .url))
        try await tmVM.updateTemplate(vpsTemplate)
        #expect(tmVM.templates.first(where: { $0.id == TemplateDefinition.BuiltinID.vps })?.name == "云服务器节点")
        #expect(
            tmVM.templates.first(where: { $0.id == TemplateDefinition.BuiltinID.vps })?.defaultFields.contains(where: {
                $0.key == "panel_url"
            }) == true)

        // 3. 验证编辑器一键套用预设 + 内联新建分类并自动选中
        let editorVM = EditorViewModel(
            container: container,
            templates: tmVM.templates,
            categories: tmVM.categories
        )
        if let chatgpt = PopularSoftwarePresetManager.search(query: "ChatGPT").first {
            let fakeIcon = Data([0x89, 0x50, 0x4E, 0x47])
            editorVM.applySoftwarePreset(chatgpt, iconData: fakeIcon)
            #expect(editorVM.name == chatgpt.name)
            #expect(editorVM.selectedTemplateId == TemplateDefinition.BuiltinID.aiMembership)
            #expect(editorVM.billingCycleType == chatgpt.defaultBillingCycle)
            #expect(editorVM.iconData == fakeIcon)
        }

        let newCat = try await editorVM.createCategoryInline(
            name: "AI 订阅",
            iconSymbol: "sparkles",
            colorKey: .indigo
        )
        #expect(editorVM.selectedCategoryId == newCat.id)
        #expect(editorVM.categories.contains(where: { $0.id == newCat.id }))
    }

    @Test("Phase 7.5: 编辑器未保存变更检测与历史修改摘要（支持二次确认）")
    func testPhase75EditorUnsavedChangesAndDiffSummary() async throws {
        let container = AppContainer.makeMock()
        let mainVM = MainViewModel(container: container)
        await mainVM.loadAll()

        // 1. 新建模式：初始无修改，填写名称后感知变更
        let createVM = EditorViewModel(
            container: container,
            templates: mainVM.templates,
            categories: mainVM.categories
        )
        #expect(createVM.hasUnsavedChanges == false)
        createVM.name = "Cursor Pro"
        #expect(createVM.hasUnsavedChanges == true)

        // 2. 编辑已有订阅模式：初始无修改
        guard let existing = mainVM.subscriptions.first else {
            Issue.record("缺少 mock 订阅数据")
            return
        }
        let editVM = EditorViewModel(
            container: container,
            templates: mainVM.templates,
            categories: mainVM.categories,
            existingItem: existing
        )
        #expect(editVM.hasUnsavedChanges == false)
        #expect(editVM.changeSummaryLines.isEmpty)

        // 修改价格并新增自定义字段后应给出清晰的修改摘要
        editVM.priceText = "99.00"
        editVM.addCustomField(label: "备用邮箱", type: .text)
        #expect(editVM.hasUnsavedChanges == true)
        #expect(editVM.changeSummaryLines.contains(where: { $0.contains("购买价格") || $0.contains("单期金额") }))
        #expect(editVM.changeSummaryLines.contains(where: { $0.contains("订阅详情字段") }))
    }

    @Test("Phase 7.7: 预置真实图标与原品牌名、双价格同步、编辑态导入填充及概览动态汇率/到期雷达")
    func testPhase77PresetIconsDualPriceAndOverviewRadar() async throws {
        // 1. 全部 26 项预置均保留原品牌简洁名称，并内置真实 PNG 图标资源
        let presets = PopularSoftwarePresetManager.allPresets
        #expect(presets.count >= 26)
        #expect(presets.first(where: { $0.id == "chatgpt-plus" })?.name == "ChatGPT")
        #expect(presets.first(where: { $0.id == "claude-pro" })?.name == "Claude")
        #expect(presets.first(where: { $0.id == "qq-music" })?.name == "QQ音乐")
        for preset in presets {
            let iconData = PopularSoftwarePresetManager.bundledIconData(for: preset)
            #expect(iconData != nil && (iconData?.count ?? 0) > 500, "Preset \(preset.id) missing real icon PNG")
        }

        // 2. 新建双价格联动 & 独立修改续期价格持久化
        let container = AppContainer.makeMock()
        let mainVM = MainViewModel(container: container)
        await mainVM.loadAll()

        let createVM = EditorViewModel(
            container: container,
            templates: mainVM.templates,
            categories: mainVM.categories
        )
        createVM.updatePurchasePriceText("99")
        #expect(createVM.renewalPriceText == "99")
        createVM.updateRenewalPriceText("198")
        createVM.name = "Tencent Cloud"
        let saved = try await createVM.save()
        #expect(saved.price == 99)
        #expect(saved.renewalPrice == 198)

        // 3. 编辑态选取预置服务也应自动回填名称与真实图标
        let editVM = EditorViewModel(
            container: container,
            templates: mainVM.templates,
            categories: mainVM.categories,
            existingItem: saved
        )
        if let chatgpt = PopularSoftwarePresetManager.allPresets.first(where: { $0.id == "chatgpt-plus" }) {
            editVM.applySoftwarePreset(chatgpt)
            #expect(editVM.name == "ChatGPT")
            #expect(editVM.iconData != nil)
        }

        // 4. 订阅概览切换折算币种应按汇率重新折算金额，并输出到期分布桶与即将到期清单
        let analyticsVM = AnalyticsViewModel(container: container)
        analyticsVM.selectedRangePreset = .allTime
        analyticsVM.baseCurrency = "CNY"
        await analyticsVM.reloadAnalytics()
        let cnyTotal = try #require(analyticsVM.summary?.totalBaseAmount)
        #expect((analyticsVM.summary?.expiryBuckets.isEmpty) == false)
        #expect((analyticsVM.summary?.upcomingRenewals.isEmpty) == false)

        analyticsVM.baseCurrency = "USD"
        await analyticsVM.reloadAnalytics()
        let usdTotal = try #require(analyticsVM.summary?.totalBaseAmount)
        #expect(analyticsVM.summary?.baseCurrency == "USD")
        #expect(usdTotal < cnyTotal / 2)
    }

    @Test("Phase 32: 自定义空白模版 V18 迁移落库与切换后完全自由添加字段")
    func testCustomBlankTemplateMigrationAndSwitching() async throws {
        let db = try SQLiteDatabase(path: ":memory:")
        try await DatabaseMigrator.migrateIfNeeded(db)
        let repo = SQLiteSubscriptionRepository(database: db, secretStore: InMemorySecretStore())
        let container = AppContainer.makeMock(repository: repo)

        let templates = try await repo.fetchTemplates()
        #expect(templates.count == 7)
        let customTemplate = try #require(templates.first(where: { $0.id == TemplateDefinition.BuiltinID.custom }))
        #expect(customTemplate.name == "自定义")
        #expect(customTemplate.defaultFields.isEmpty)

        let editor = EditorViewModel(
            container: container,
            templates: templates,
            categories: CategoryPresetManager.builtinCategories,
            defaultTemplateId: TemplateDefinition.BuiltinID.vps
        )
        #expect(!editor.customFields.isEmpty)

        // 切换到自定义模版后预设字段全部清空，允许从零自由添加字段并持久化
        editor.switchTemplate(to: TemplateDefinition.BuiltinID.custom)
        #expect(editor.customFields.isEmpty)

        editor.name = "自建服务"
        editor.priceText = "88"
        editor.addCustomField(label: "授权节点", type: .text)
        editor.customFields[0].value = "东京节点"
        let saved = try await editor.save(baseCurrency: "CNY")
        #expect(saved.templateId == TemplateDefinition.BuiltinID.custom)

        let fetched = try #require(try await repo.fetchSubscription(id: saved.id))
        #expect(fetched.customFields.count == 1)
        #expect(fetched.customFields.first?.label == "授权节点")
        #expect(fetched.customFields.first?.value == "东京节点")
    }
}
