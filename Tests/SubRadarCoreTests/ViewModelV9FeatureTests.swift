import Foundation
import Testing

@testable import SubRadarCore

@Suite("Phase 8 V9/V10 体验改进与系统字段测试")
@MainActor
struct ViewModelV9FeatureTests {
    @Test("切换左侧分类时自动选中该分类首条订阅或置空")
    func testCategorySwitchSelectsFirstSubscriptionOrNil() async throws {
        let container = AppContainer.makeMock()
        let main = MainViewModel(container: container)
        await main.loadAll()

        main.sidebarSelection = .category(SubscriptionCategory.BuiltinID.cloudInfra)
        let firstInfra = try #require(main.filteredSubscriptions.first)
        #expect(main.selectedSubscriptionId == firstInfra.id)

        main.sidebarSelection = .category(SubscriptionCategory.BuiltinID.streaming)
        let firstStreaming = try #require(main.filteredSubscriptions.first)
        #expect(main.selectedSubscriptionId == firstStreaming.id)
        #expect(main.selectedSubscriptionId != firstInfra.id)

        let emptyCategory = try await main.createCategory(name: "空测试分类", iconSymbol: "tray", colorKey: .indigo)
        main.sidebarSelection = .category(emptyCategory.id)
        #expect(main.filteredSubscriptions.isEmpty)
        #expect(main.selectedSubscriptionId == nil)
    }

    @Test("应用常用软件预置时留空价格由用户填写")
    func testPresetLeavesPriceBlankForUserInput() throws {
        let container = AppContainer.makeMock()
        let editor = EditorViewModel(
            container: container,
            templates: TemplatePresetManager.builtinTemplates,
            categories: CategoryPresetManager.builtinCategories
        )
        let yecaoyun = try #require(PopularSoftwarePresetManager.allPresets.first(where: { $0.id == "yecaoyun" }))
        editor.applySoftwarePreset(yecaoyun)

        #expect(editor.name == "野草云")
        #expect(editor.priceText.isEmpty)
        #expect(editor.renewalPriceText.isEmpty)
        #expect(editor.customFields.first(where: { $0.key == "ssh_port" })?.value == "22")
        #expect(editor.customFields.contains(where: { $0.key == "operating_system" }))
    }

    @Test("模版来回切换清除上一模版残留字段并保留用户自定义字段")
    func testTemplateSwitchingStripsStaleSchemaFieldsPreservingCustomFields() {
        let container = AppContainer.makeMock()
        let editor = EditorViewModel(
            container: container,
            templates: TemplatePresetManager.builtinTemplates,
            categories: CategoryPresetManager.builtinCategories
        )

        editor.switchTemplate(to: TemplateDefinition.BuiltinID.vps)
        editor.addCustomField(label: "备注节点编号", type: .text)
        if let idx = editor.customFields.firstIndex(where: { $0.label == "备注节点编号" }) {
            editor.customFields[idx].value = "HK-BGP-01"
        }
        #expect(editor.customFields.contains(where: { $0.key == "operating_system" }))

        editor.switchTemplate(to: TemplateDefinition.BuiltinID.apiBalance)
        #expect(!editor.customFields.contains(where: { $0.key == "instance_type" }))
        #expect(!editor.customFields.contains(where: { $0.key == "operating_system" }))
        #expect(editor.customFields.contains(where: { $0.key == "provider_preset" }))
        #expect(editor.customFields.contains(where: { $0.label == "备注节点编号" }))

        editor.switchTemplate(to: TemplateDefinition.BuiltinID.streaming)
        #expect(!editor.customFields.contains(where: { $0.key == "provider_preset" }))
        #expect(!editor.customFields.contains(where: { $0.key == "api_endpoint" }))
        #expect(editor.customFields.contains(where: { $0.key == "plan_tier" }))
        #expect(editor.customFields.contains(where: { $0.label == "备注节点编号" }))
    }

    @Test("主机与域名切换及操作系统层级格式化")
    func testInfrastructureSwitchAndOperatingSystemCatalog() {
        let container = AppContainer.makeMock()
        let editor = EditorViewModel(
            container: container,
            templates: TemplatePresetManager.builtinTemplates,
            categories: CategoryPresetManager.builtinCategories
        )

        editor.applyInfrastructureKindChoice(isHost: true)
        #expect(editor.selectedTemplateId == TemplateDefinition.BuiltinID.vps)
        #expect(editor.customFields.contains(where: { $0.key == "operating_system" }))

        editor.applyInfrastructureKindChoice(isHost: false)
        #expect(editor.selectedTemplateId == TemplateDefinition.BuiltinID.domain)
        #expect(editor.customFields.contains(where: { $0.key == "domain_name" }))

        let linuxDistros = FieldOptionCatalog.osDistros(for: .linux)
        #expect(linuxDistros.contains(where: { $0.name == "Rocky Linux" && $0.versions.contains("9.4") }))
        #expect(
            FieldOptionCatalog.formatOperatingSystem(
                family: .linux,
                distro: "Rocky Linux",
                version: "9.4"
            ) == "Rocky Linux 9.4"
        )
        #expect(
            FieldOptionCatalog.formatOperatingSystem(
                family: .windows,
                distro: "Windows Server",
                version: "2022"
            ) == "Windows Server 2022"
        )
        #expect(
            FieldOptionCatalog.formatOperatingSystem(
                family: .macOS,
                distro: "macOS",
                version: "15 Sequoia"
            ) == "macOS 15 Sequoia"
        )
        #expect(FieldOptionCatalog.formatOperatingSystem(family: .unset, distro: "", version: "").isEmpty)
    }

    @Test("AI API 多次充值入账及大盘 API 账户余额统计")
    func testAPIMultiTopUpAndDashboardBalanceOverview() async throws {
        let container = AppContainer.makeMock()
        let editor = EditorViewModel(
            container: container,
            templates: TemplatePresetManager.builtinTemplates,
            categories: CategoryPresetManager.builtinCategories
        )
        editor.name = "Test API Recharge"
        editor.switchTemplate(to: TemplateDefinition.BuiltinID.apiBalance)
        editor.currency = "USD"
        editor.updatePurchasePriceText("25")
        editor.apiTopUpCountText = "3"

        let saved = try await editor.save(baseCurrency: "CNY")
        let records = try await container.repository.fetchBillingRecords(for: saved.id)
        #expect(records.count == 3)
        #expect(records.allSatisfy { $0.kind == BillingRecordKind.topUp && $0.amount == 25 })

        let analytics = AnalyticsViewModel(container: container)
        analytics.baseCurrency = "CNY"
        await analytics.reloadAnalytics()
        let summary = try #require(analytics.summary)
        #expect(!summary.apiBalanceItems.isEmpty)
        #expect(summary.totalAPIBalanceBaseAmount >= 0)
    }
}
