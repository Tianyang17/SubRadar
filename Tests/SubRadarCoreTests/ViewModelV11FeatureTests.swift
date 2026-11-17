import Foundation
import Testing

@testable import SubRadarCore

@Suite("Phase 8 V11 体验修复与充值/GPU/跨模版继承测试")
@MainActor
struct ViewModelV11FeatureTests {
    @Test("跨模版切换时主机/VPS 与域名资产互转保留官网 URL 与购买来源")
    func testCrossTemplateCarryOverPreservesURL() throws {
        let container = AppContainer.makeMock()
        let editor = EditorViewModel(
            container: container,
            templates: TemplatePresetManager.builtinTemplates,
            categories: CategoryPresetManager.builtinCategories
        )

        let yecaoyun = try #require(PopularSoftwarePresetManager.allPresets.first(where: { $0.id == "yecaoyun" }))
        editor.applySoftwarePreset(yecaoyun)
        #expect(editor.selectedTemplateId == TemplateDefinition.BuiltinID.vps)
        #expect(editor.customFields.first(where: { $0.key == "panel_url" })?.value == "https://my.yecaoyun.com")

        editor.applyInfrastructureKindChoice(isHost: false)
        #expect(editor.selectedTemplateId == TemplateDefinition.BuiltinID.domain)
        #expect(editor.customFields.first(where: { $0.key == "manage_url" })?.value == "https://my.yecaoyun.com")

        editor.applyInfrastructureKindChoice(isHost: true)
        #expect(editor.selectedTemplateId == TemplateDefinition.BuiltinID.vps)
        #expect(editor.customFields.first(where: { $0.key == "panel_url" })?.value == "https://my.yecaoyun.com")
    }

    @Test("AI API 支持逐笔不同金额充值以及按总额自动平均分摊")
    func testAPIVariablePerRechargeAndAverageSplit() async throws {
        let container = AppContainer.makeMock()
        let editor = EditorViewModel(
            container: container,
            templates: TemplatePresetManager.builtinTemplates,
            categories: CategoryPresetManager.builtinCategories
        )
        editor.name = "Variable Recharge API"
        editor.switchTemplate(to: TemplateDefinition.BuiltinID.apiBalance)
        editor.currency = "USD"
        editor.updateAPITopUpCount(3)
        editor.updateAPITopUpAmount("20", at: 0)
        editor.updateAPITopUpAmount("35", at: 1)
        editor.updateAPITopUpAmount("45", at: 2)

        #expect(editor.estimatedTotalTopUpAmount == 100)
        let saved = try await editor.save(baseCurrency: "CNY")
        let records = try await container.repository.fetchBillingRecords(for: saved.id)
        #expect(records.count == 3)
        #expect(Set(records.map(\.amount)) == Set([Decimal(20), Decimal(35), Decimal(45)]))
        #expect(records.reduce(Decimal.zero) { $0 + $1.amount } == 100)

        let avgEditor = EditorViewModel(
            container: container,
            templates: TemplatePresetManager.builtinTemplates,
            categories: CategoryPresetManager.builtinCategories
        )
        avgEditor.name = "Averaged Recharge API"
        avgEditor.switchTemplate(to: TemplateDefinition.BuiltinID.apiBalance)
        avgEditor.currency = "USD"
        avgEditor.updateAPITopUpCount(3)
        avgEditor.setAPITopUpAverageMode(true)
        avgEditor.apiTopUpTotalText = "100"

        let splitPreview = avgEditor.previewAPITopUpAmounts
        #expect(splitPreview.count == 3)
        #expect(splitPreview.reduce(Decimal.zero, +) == 100)

        let savedAvg = try await avgEditor.save(baseCurrency: "CNY")
        let avgRecords = try await container.repository.fetchBillingRecords(for: savedAvg.id)
        #expect(avgRecords.count == 3)
        #expect(avgRecords.reduce(Decimal.zero) { $0 + $1.amount } == 100)
    }

    @Test("选项目录精简、GPU 格式化与 V11 下拉默认首选项校验")
    func testCatalogDefaultsAndGPUSpecFormatting() {
        #expect(FieldOptionCatalog.accountSources.contains("官网直充"))
        #expect(!FieldOptionCatalog.accountSources.contains("官网自注册"))
        #expect(FieldOptionCatalog.purchaseSources.first == "官网直购")
        #expect(FieldOptionCatalog.defaultVRAM(forGPUModel: "H100") == "80G")
        #expect(
            FieldOptionCatalog.formatGPUSpec(count: "2x", model: "RTX 4090", vram: "24G")
                == "2x RTX 4090 24G"
        )

        let vpsTemplate = TemplatePresetManager.template(
            for: TemplateDefinition.BuiltinID.vps,
            from: TemplatePresetManager.builtinTemplates
        )
        #expect(vpsTemplate?.defaultFields.first(where: { $0.key == "region" })?.defaultValue == "")

        let softwareTemplate = TemplatePresetManager.template(
            for: TemplateDefinition.BuiltinID.softwareLicense,
            from: TemplatePresetManager.builtinTemplates
        )
        #expect(softwareTemplate?.defaultFields.first(where: { $0.key == "purchase_source" })?.defaultValue == "")
    }

    @Test("Phase 25: VPS 规格与流量格式化空白零预填、支持部分填写与不限流量")
    func testVPSSpecAndTrafficNoPrefillFormatting() {
        // 1. 全部为空时不虚构任何默认数字
        #expect(
            FieldOptionCatalog.formatVPSSpec(
                cpuCores: "",
                memoryGB: "",
                storageAmount: "",
                storageUnit: "G SSD",
                hasGPU: false,
                gpuSpec: ""
            ) == ""
        )

        // 2. 仅填部分规格时仅按实际输入拼装
        #expect(
            FieldOptionCatalog.formatVPSSpec(
                cpuCores: "2",
                memoryGB: "4",
                storageAmount: "",
                storageUnit: "G SSD",
                hasGPU: false,
                gpuSpec: ""
            ) == "2C / 4G RAM / No GPU"
        )

        // 3. 完整规格与 GPU 规格
        #expect(
            FieldOptionCatalog.formatVPSSpec(
                cpuCores: "4",
                memoryGB: "16",
                storageAmount: "100",
                storageUnit: "G NVMe",
                hasGPU: true,
                gpuSpec: "1x RTX 4090 24G"
            ) == "4C / 16G RAM / 100G NVMe / 1x RTX 4090 24G"
        )

        // 4. 流量与带宽全部为空时不预填默认 100 / 1
        #expect(
            FieldOptionCatalog.formatVPSTraffic(
                bandwidthAmount: "",
                bandwidthUnit: "Mbps",
                isLimited: true,
                quotaAmount: "",
                quotaUnit: "TB/mo"
            ) == ""
        )

        // 5. 仅填带宽、或仅选 Unlimited、或完整填写
        #expect(
            FieldOptionCatalog.formatVPSTraffic(
                bandwidthAmount: "1000",
                bandwidthUnit: "Mbps",
                isLimited: true,
                quotaAmount: "1",
                quotaUnit: "TB/mo"
            ) == "1000 Mbps / 1 TB/mo"
        )
        #expect(
            FieldOptionCatalog.formatVPSTraffic(
                bandwidthAmount: "",
                bandwidthUnit: "Mbps",
                isLimited: false,
                quotaAmount: "",
                quotaUnit: "TB/mo"
            ) == "Unlimited"
        )
        #expect(
            FieldOptionCatalog.formatVPSTraffic(
                bandwidthAmount: "1",
                bandwidthUnit: "Gbps",
                isLimited: false,
                quotaAmount: "",
                quotaUnit: "TB/mo"
            ) == "1 Gbps / Unlimited"
        )
    }

    @Test("Phase 28: 来源枚举收口为3项且选中渠道代充/第三方合租时联动具体渠道来源字段")
    func testAccountSourceEnumAndDetailFieldSync() async throws {
        #expect(FieldOptionCatalog.accountSources == ["官网直充", "渠道代充", "第三方合租"])
        #expect(!FieldOptionCatalog.accountSources.contains("自建中转"))

        let db = try SQLiteDatabase(path: ":memory:")
        try await DatabaseMigrator.migrateIfNeeded(db)
        let repo = SQLiteSubscriptionRepository(database: db, secretStore: InMemorySecretStore())
        let container = AppContainer.makeMock(repository: repo)

        let editor = EditorViewModel(
            container: container,
            templates: TemplatePresetManager.builtinTemplates,
            categories: CategoryPresetManager.builtinCategories,
            defaultTemplateId: TemplateDefinition.BuiltinID.aiMembership
        )
        editor.name = "Claude Pro 拼车"
        editor.priceText = "65"
        #expect(!editor.customFields.contains(where: { $0.key == "account_source_detail" }))

        editor.updateAccountSource("渠道代充")
        let sourceIdx = try #require(editor.customFields.firstIndex(where: { $0.key == "account_source" }))
        let detailIdx = try #require(editor.customFields.firstIndex(where: { $0.key == "account_source_detail" }))
        #expect(detailIdx == sourceIdx + 1)
        #expect(editor.customFields[detailIdx].label == "具体渠道来源")

        editor.customFields[detailIdx].value = "某某发卡网"

        // 切换到第三方合租时保留用户填写的具体渠道来源
        editor.updateAccountSource("第三方合租")
        #expect(editor.customFields.first(where: { $0.key == "account_source_detail" })?.value == "某某发卡网")

        // 切换为官网直充或自定义时自动移除附加字段
        editor.updateAccountSource("官网直充")
        #expect(!editor.customFields.contains(where: { $0.key == "account_source_detail" }))

        // 重新选回第三方合租填入并保存持久化
        editor.updateAccountSource("第三方合租")
        let newDetailIdx = try #require(editor.customFields.firstIndex(where: { $0.key == "account_source_detail" }))
        editor.customFields[newDetailIdx].value = "TG 合租大群"
        let saved = try await editor.save(baseCurrency: "CNY")

        let fetched = try #require(try await repo.fetchSubscription(id: saved.id))
        #expect(fetched.fieldValue(forKey: "account_source") == "第三方合租")
        #expect(fetched.fieldValue(forKey: "account_source_detail") == "TG 合租大群")
    }

    @Test("Phase 29: 购买来源拆分、渠道/合租联动来源字段及 App Store 自动精简清除")
    func testPurchaseSourceSplitDetailAndAppStoreFieldPruning() async throws {
        #expect(FieldOptionCatalog.purchaseSources == ["官网直购", "App Store", "Steam", "渠道代充", "第三方合租"])
        #expect(!FieldOptionCatalog.purchaseSources.contains("MacUpdate"))
        #expect(!FieldOptionCatalog.purchaseSources.contains("合租 / 渠道"))

        let db = try SQLiteDatabase(path: ":memory:")
        try await DatabaseMigrator.migrateIfNeeded(db)
        let repo = SQLiteSubscriptionRepository(database: db, secretStore: InMemorySecretStore())
        let container = AppContainer.makeMock(repository: repo)

        let editor = EditorViewModel(
            container: container,
            templates: TemplatePresetManager.builtinTemplates,
            categories: CategoryPresetManager.builtinCategories,
            defaultTemplateId: TemplateDefinition.BuiltinID.softwareLicense
        )
        editor.name = "Raycast"
        editor.priceText = "99"

        // 先填入密码、激活码与授权设备数
        for key in ["account_password", "license_key", "device_limit"] {
            if let idx = editor.customFields.firstIndex(where: { $0.key == key }) {
                editor.customFields[idx].value = "legacy-\(key)"
            }
        }

        // 选中 App Store：密码、激活码与授权设备数应移除且历史填写直接清除
        editor.updatePurchaseSource("App Store")
        #expect(!editor.customFields.contains(where: { $0.key == "account_password" }))
        #expect(!editor.customFields.contains(where: { $0.key == "license_key" }))
        #expect(!editor.customFields.contains(where: { $0.key == "device_limit" }))
        #expect(editor.customFields.contains(where: { $0.key == "username" }))

        // 切换为渠道代充：补回空白授权字段，同时紧邻下方出现「来源」明细字段且不回填先前密码/激活码
        editor.updatePurchaseSource("渠道代充")
        #expect(editor.customFields.first(where: { $0.key == "account_password" })?.value == "")
        #expect(editor.customFields.first(where: { $0.key == "license_key" })?.value == "")
        #expect(editor.customFields.first(where: { $0.key == "device_limit" })?.value == "")
        let srcIdx = try #require(editor.customFields.firstIndex(where: { $0.key == "purchase_source" }))
        let detIdx = try #require(editor.customFields.firstIndex(where: { $0.key == "purchase_source_detail" }))
        #expect(detIdx == srcIdx + 1)
        #expect(editor.customFields[detIdx].label == "来源")
        editor.customFields[detIdx].value = "某数码店"

        // 切回官网直购：来源明细字段直接清除，再次切回第三方合租应为空白
        editor.updatePurchaseSource("官网直购")
        #expect(!editor.customFields.contains(where: { $0.key == "purchase_source_detail" }))
        editor.updatePurchaseSource("第三方合租")
        #expect(editor.customFields.first(where: { $0.key == "purchase_source_detail" })?.value == "")
    }
}
