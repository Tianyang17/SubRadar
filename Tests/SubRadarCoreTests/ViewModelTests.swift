import Foundation
import ImageIO
import Testing

@testable import SubRadarCore

@Suite("Phase 2 ViewModel TDD 测试")
@MainActor
struct ViewModelTests {
    @Test("MainViewModel 加载、搜索过滤（含动态字段IP/域名）与续订累加")
    func testMainViewModelLoadFilterAndRenew() async throws {
        let container = AppContainer.makeMock()
        let vm = MainViewModel(container: container)

        await vm.loadAll()

        #expect(vm.subscriptions.count == 7)
        #expect(vm.templates.count == 7)
        #expect(vm.selectedSubscription != nil)
        let usedTemplates = Set(vm.subscriptions.map(\.templateId))
        #expect(usedTemplates.count == 6)

        // 搜索动态字段中的 IP 地址应命中 Mock VPS
        vm.searchQuery = "198.51.100.24"
        #expect(vm.filteredSubscriptions.count == 1)
        #expect(vm.filteredSubscriptions.first?.name == "野草云 HK-BGP")

        // 清空搜索，筛选即将到期（7天内）应命中 QQ音乐(2天) 与 百度网盘(5天)
        vm.searchQuery = ""
        vm.sidebarSelection = .expiringSoon
        #expect(vm.filteredSubscriptions.count == 2)

        // 对百度网盘执行续订，验证下次续订年份推进 1 年且流水 +1
        let baidu = try #require(vm.subscriptions.first(where: { $0.name.contains("百度网盘") }))
        let beforeRecords = try await container.repository.fetchBillingRecords(for: baidu.id)
        let oldYear = Calendar.current.component(.year, from: baidu.nextRenewalDate)

        await vm.renewSubscription(baidu, actualPrice: 268)

        let updated = try #require(vm.subscriptions.first(where: { $0.id == baidu.id }))
        let newYear = Calendar.current.component(.year, from: updated.nextRenewalDate)
        let afterRecords = try await container.repository.fetchBillingRecords(for: baidu.id)

        #expect(newYear == oldYear + 1)
        #expect(afterRecords.count == beforeRecords.count + 1)
        #expect(afterRecords.first?.amount == 268)
    }

    @Test("EditorViewModel 模版切换、历史计费实时预览与保存新建")
    func testEditorViewModelTemplateAndHistoricalSave() async throws {
        let container = AppContainer.makeMock()
        let mainVM = MainViewModel(container: container)
        await mainVM.loadAll()

        let editorVM = EditorViewModel(
            container: container,
            templates: mainVM.templates,
            existingItem: nil
        )

        // 默认选中第一个模版，切换到 VPS 模版时应动态填充 VPS 字段
        editorVM.switchTemplate(to: TemplateDefinition.BuiltinID.vps)
        #expect(editorVM.customFields.contains(where: { $0.key == "ipv4" }))
        #expect(editorVM.customFields.contains(where: { $0.key == "ssh_port" }))

        // 添加自定义字段
        editorVM.addCustomField(label: "备用端口", type: .number)
        #expect(editorVM.customFields.contains(where: { $0.label == "备用端口" }))

        // 设置跨 3 年的订阅并勾选历史计费
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(from: DateComponents(year: 2023, month: 1, day: 1))!
        let end = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!

        editorVM.name = "自建云测试机"
        editorVM.priceText = "100"
        editorVM.currency = "CNY"
        editorVM.billingCycleType = .annually
        editorVM.startDate = start
        editorVM.nextRenewalDate = end
        editorVM.includeHistoricalBilling = true

        let preview = editorVM.historicalPreview
        #expect(preview.cycleCount == 3)
        #expect(preview.totalAmount == 300)

        let savedItem = try await editorVM.save()
        let records = try await container.repository.fetchBillingRecords(for: savedItem.id)
        #expect(records.count == 3)
    }

    @Test("AnalyticsViewModel 自定义时间段聚合统计")
    func testAnalyticsViewModelCustomRangeAggregation() async {
        let container = AppContainer.makeMock()
        let vm = AnalyticsViewModel(container: container)

        // 设为全部时间段加载
        vm.selectedRangePreset = .allTime
        await vm.reloadAnalytics()

        let summary = vm.summary
        #expect(summary != nil)
        #expect((summary?.totalBaseAmount ?? 0) > 0)
        #expect((summary?.categoryBreakdowns.isEmpty) == false)
        #expect((summary?.monthlyTrends.isEmpty) == false)

        // 测试自定义未来空区间（如 2099 年）应归零
        let futureStart = Date(timeIntervalSince1970: 4_070_908_800)  // 2099-01-01
        let futureEnd = Date(timeIntervalSince1970: 4_102_444_800)  // 2100-01-01
        vm.selectedRangePreset = .custom
        vm.customStartDate = futureStart
        vm.customEndDate = futureEnd
        await vm.reloadAnalytics()

        #expect(vm.summary?.totalBaseAmount == 0)
        #expect(vm.summary?.records.isEmpty == true)
    }

    @Test("TemplateManagerViewModel 新建自定义模版与禁止删除内置模版")
    func testTemplateManagerViewModel() async throws {
        let container = AppContainer.makeMock()
        let vm = TemplateManagerViewModel(container: container)
        await vm.loadTemplates()

        let initialCount = vm.templates.count
        let newTemplate = try await vm.createCustomTemplate(
            name: "AI API Key",
            iconSymbol: "cpu",
            fields: [
                FieldSchema(key: "api_key", label: "API Secret", type: .secret),
                FieldSchema(key: "endpoint", label: "Base URL", type: .url)
            ]
        )

        #expect(vm.templates.count == initialCount + 1)
        #expect(newTemplate.isBuiltin == false)

        // 删除自定义模版应生效
        await vm.deleteTemplate(newTemplate)
        #expect(vm.templates.count == initialCount)

        // 尝试删除内置模版应被忽略
        if let builtin = vm.templates.first(where: { $0.isBuiltin }) {
            await vm.deleteTemplate(builtin)
            #expect(vm.templates.count == initialCount)
        }
    }

    @Test("Phase 3: 默认进入费用统计大盘、左下角设置导航与暗黑主题切换")
    func testDefaultLandingAnalyticsAndSettingsTheme() async {
        let suiteName = "com.subradar.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettingsStore(userDefaults: defaults)
        #expect(settings.themeMode == .system)
        #expect(settings.baseCurrency == "CNY")
        #expect(settings.defaultReminderDays == 3)

        settings.themeMode = .dark
        settings.baseCurrency = "USD"
        settings.defaultReminderDays = 7

        // 重新实例化验证持久化
        let reloaded = AppSettingsStore(userDefaults: defaults)
        #expect(reloaded.themeMode == .dark)
        #expect(reloaded.baseCurrency == "USD")
        #expect(reloaded.defaultReminderDays == 7)

        let container = AppContainer.makeMock()
        let vm = MainViewModel(container: container, settings: reloaded)

        // 默认进入应为费用统计大盘
        #expect(vm.sidebarSelection == .analytics)
        #expect(vm.baseCurrency == "USD")

        // 左下角点击设置应切换到 .settings
        vm.openSettings()
        #expect(vm.sidebarSelection == .settings)

        // 一键切换主题
        vm.cycleTheme()
        #expect(reloaded.themeMode == .light)
    }

    @Test("Phase 5: 分类与模版正交解耦、自定义分类过滤及按分类大盘统计")
    func testCategoryTemplateDecouplingAndAnalytics() async throws {
        let container = AppContainer.makeMock()
        let tmVM = TemplateManagerViewModel(container: container)
        await tmVM.loadTemplates()

        let initialCatCount = tmVM.categories.count
        let aiCategory = try await tmVM.createCustomCategory(
            name: "AI 大模型",
            iconSymbol: "sparkles",
            colorKey: .cyan
        )
        #expect(tmVM.categories.count == initialCatCount + 1)
        #expect(aiCategory.isBuiltin == false)

        // 编辑器中：先选自定义分类 "AI 大模型"，再切换不同模版，分类归属不应被模版覆盖
        let editorVM = EditorViewModel(
            container: container,
            templates: tmVM.templates,
            categories: tmVM.categories,
            defaultCategoryId: aiCategory.id
        )
        #expect(editorVM.selectedCategoryId == aiCategory.id)

        editorVM.switchTemplate(to: TemplateDefinition.BuiltinID.vps)
        #expect(editorVM.selectedTemplateId == TemplateDefinition.BuiltinID.vps)
        #expect(editorVM.selectedCategoryId == aiCategory.id)

        editorVM.name = "OpenAI API"
        editorVM.priceText = "20"
        let saved = try await editorVM.save()
        #expect(saved.categoryId == aiCategory.id)
        #expect(saved.templateId == TemplateDefinition.BuiltinID.vps)

        // MainViewModel 按分类筛选
        let mainVM = MainViewModel(container: container)
        await mainVM.loadAll()
        mainVM.sidebarSelection = .category(aiCategory.id)
        #expect(mainVM.filteredSubscriptions.contains(where: { $0.id == saved.id }))
        #expect(mainVM.count(for: .category(aiCategory.id)) == 1)

        // AnalyticsViewModel 按 categoryId 聚合统计
        let analyticsVM = AnalyticsViewModel(container: container)
        analyticsVM.selectedRangePreset = .allTime
        await analyticsVM.reloadAnalytics()
        #expect(
            analyticsVM.summary?.categoryBreakdowns.contains(where: {
                $0.categoryId == SubscriptionCategory.BuiltinID.cloudInfra
            }) == true)
    }

    @Test("Phase 20: 提醒选项包含提前 14 天且共享格式化文案与触发日计算正确")
    func testReminderOptionsInclude14Days() async throws {
        #expect(SubscriptionItem.reminderDayOptions == [-1, 0, 1, 3, 7, 14, 30])
        #expect(SubscriptionItem.reminderOptionLabel(-1) == "不提醒")
        #expect(SubscriptionItem.reminderOptionLabel(0) == "到期当天")
        #expect(SubscriptionItem.reminderOptionLabel(14) == "提前 14 天")

        let calendar = Calendar(identifier: .gregorian)
        let renewal = calendar.date(from: DateComponents(year: 2026, month: 11, day: 30))!
        let notif = LocalNotificationService(calendar: calendar)
        let trigger = try #require(notif.computeTriggerDate(nextRenewal: renewal, daysBefore: 14))
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: trigger)
        #expect(comps.year == 2026)
        #expect(comps.month == 11)
        #expect(comps.day == 16)
        #expect(comps.hour == 9)
        #expect(comps.minute == 30)

        let container = AppContainer.makeMock()
        let mainVM = MainViewModel(container: container)
        await mainVM.loadAll()
        let editorVM = EditorViewModel(container: container, templates: mainVM.templates, categories: mainVM.categories)
        editorVM.name = "测试 14 天提醒"
        editorVM.priceText = "50"
        editorVM.reminderDaysBefore = 14
        let saved = try await editorVM.save()
        #expect(saved.reminderDaysBefore == 14)
    }

    @Test("Phase 21: 移除 TWD 与 TRY 币种并保证旧偏好安全回退 CNY")
    func testRemovedTWDAndTRYCurrenciesWithSafeFallback() {
        let codes = CommonCurrency.allCases.map(\.rawValue)
        #expect(codes == ["CNY", "USD", "EUR", "HKD", "JPY", "GBP"])
        #expect(!codes.contains("TWD"))
        #expect(!codes.contains("TRY"))
        #expect(CommonCurrency.symbol(for: "TWD") == "TWD ")
        #expect(CommonCurrency.symbol(for: "try") == "TRY ")

        let suiteName = "subradar.test.phase21.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set("TWD", forKey: "subradar.settings.baseCurrency")
        let twdStore = AppSettingsStore(userDefaults: defaults)
        #expect(twdStore.baseCurrency == "CNY")

        defaults.set("try", forKey: "subradar.settings.baseCurrency")
        let tryStore = AppSettingsStore(userDefaults: defaults)
        #expect(tryStore.baseCurrency == "CNY")

        defaults.set("usd", forKey: "subradar.settings.baseCurrency")
        let usdStore = AppSettingsStore(userDefaults: defaults)
        #expect(usdStore.baseCurrency == "USD")
    }
}
