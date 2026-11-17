import Foundation
import ImageIO
import Testing

@testable import SubRadarCore

@Suite("Phase 2 ViewModel TDD 测试")
@MainActor
struct ViewModelLedgerFeatureTests {
    @Test("Phase 7.8: 512px 高清图标资源、预置分类分组筛选与编辑器合并多期计费周期")
    func testPhase78PresetGroupsHighResIconsAndMergedBillingUnits() async throws {
        // 1. 验证五大分组均非空且每项预置均包含 512x512 高清 PNG
        for group in PopularSoftwareGroup.allCases {
            let groupItems = PopularSoftwarePresetManager.groupedPresets(query: "", groupFilter: group)
            #expect(groupItems.isEmpty == false, "Group \(group.rawValue) should not be empty")
        }
        #expect(
            PopularSoftwarePresetManager.groupedPresets(query: "Claude", groupFilter: .aiTools).first?.id
                == "claude-pro")
        #expect(
            PopularSoftwarePresetManager.groupedPresets(query: "Claude", groupFilter: .entertainment).isEmpty == true)

        for preset in PopularSoftwarePresetManager.allPresets {
            let data = try #require(
                PopularSoftwarePresetManager.bundledIconData(for: preset), "Missing icon for \(preset.id)")
            if let source = CGImageSourceCreateWithData(data as CFData, nil),
                let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                let width = props[kCGImagePropertyPixelWidth] as? Int,
                let height = props[kCGImagePropertyPixelHeight] as? Int
            {
                #expect(width >= 512 && height >= 512, "Icon \(preset.id) is \(width)x\(height), expected >= 512x512")
            } else {
                Issue.record("Invalid PNG metadata for \(preset.id)")
            }
        }

        // 2. 验证 EditorViewModel 合并计费单位 + 期数（每 3 年 / 每 4 个月）保存与月均折算
        let container = AppContainer.makeMock()
        let mainVM = MainViewModel(container: container)
        await mainVM.loadAll()
        let beforeMonthly = mainVM.monthlyEstimatedBaseSpend

        let editorVM = EditorViewModel(
            container: container,
            templates: mainVM.templates,
            categories: mainVM.categories
        )
        editorVM.name = "JetBrains 3年续约"
        editorVM.currency = "CNY"
        editorVM.updatePurchasePriceText("360")
        editorVM.billingCycleUnit = .year
        editorVM.billingCycleIntervalText = "3"
        #expect(editorVM.billingCycleType == .annually)
        #expect(editorVM.billingCycleDisplayName == "每 3 年")

        let saved3Y = try await editorVM.save()
        #expect(saved3Y.billingCycleType == .annually)
        #expect(saved3Y.billingCycleDays == 3)
        #expect(saved3Y.cycleDisplayName == "每 3 年")

        await mainVM.loadAll()
        #expect(abs((mainVM.monthlyEstimatedBaseSpend - beforeMonthly) - Decimal(10)) < Decimal(string: "0.02")!)

        // 3. 验证 AnalyticsViewModel 输出多期周期文本
        let analyticsVM = AnalyticsViewModel(container: container)
        analyticsVM.baseCurrency = "CNY"
        await analyticsVM.reloadAnalytics()
        let upcoming = analyticsVM.summary?.upcomingRenewals.first(where: { $0.subscriptionId == saved3Y.id })
        #expect(upcoming?.cycleDisplayText == "每 3 年")
    }

    @Test("Phase 7.9 Batch A: 6组预置软件、增删清单、英文A-Z+中文拼音排序及去退订化官方链接")
    func testPhase79BatchAPresetsSortingAndUrls() throws {
        // 1. 6 大分组全存在且均非空
        #expect(PopularSoftwareGroup.allCases.count == 6)
        #expect(PopularSoftwareGroup.allCases.contains(.aiApiBalance))
        for group in PopularSoftwareGroup.allCases {
            let items = PopularSoftwarePresetManager.groupedPresets(query: "", groupFilter: group)
            #expect(items.isEmpty == false, "Group \(group.rawValue) should not be empty")
        }

        // 2. 验证移除项已下线，新增项均已就绪
        let allIds = Set(PopularSoftwarePresetManager.allPresets.map(\.id))
        #expect(!allIds.contains("cleanshot-x"))
        #expect(!allIds.contains("setapp"))
        #expect(!allIds.contains("bandwagonhost"))
        for requiredId in [
            "microsoft-365", "mango-tv", "youku", "oppo-cloud",
            "dedirock", "spaceship", "xiaotu-cloud", "yecaoyun",
            "deepseek", "openrouter", "siliconflow", "new-api", "sub2api", "custom-api"
        ] {
            #expect(allIds.contains(requiredId), "Missing required preset \(requiredId)")
        }

        // 3. 验证分组内部严格遵守「英文 A-Z 在前、中文拼音 A-Z 在后」排序
        let entertainment = PopularSoftwarePresetManager.groupedPresets(query: "", groupFilter: .entertainment).map(
            \.name)
        #expect(entertainment == ["Netflix", "QQ音乐", "Spotify", "YouTube", "爱奇艺", "哔哩哔哩", "芒果TV", "网易云音乐", "优酷"])

        let storage = PopularSoftwarePresetManager.groupedPresets(query: "", groupFilter: .cloudStorage).map(\.name)
        #expect(storage == ["iCloud+", "OPPO 云空间", "阿里云盘", "百度网盘", "夸克网盘"])

        let infra = PopularSoftwarePresetManager.groupedPresets(query: "", groupFilter: .infrastructure).map(\.name)
        #expect(infra == ["Cloudflare", "DediRock", "Namecheap", "Spaceship", "小兔互联", "野草云"])

        let apiGroup = PopularSoftwarePresetManager.groupedPresets(query: "", groupFilter: .aiApiBalance).map(\.name)
        #expect(apiGroup == ["DeepSeek", "New API", "OpenRouter", "SiliconFlow", "Sub2API", "纯自定义 API"])

        // 4. 验证 Microsoft 365 alias 可搜索命中
        #expect(PopularSoftwarePresetManager.search(query: "office 365").first?.id == "microsoft-365")

        // 5. 验证 6 大内置模版与预置字段均不再包含“退订链接”文案
        for template in TemplatePresetManager.builtinTemplates {
            for field in template.defaultFields {
                #expect(!field.label.contains("退订"))
            }
        }
    }

    @Test("Phase 7.9 Batch B: 手动补录历史/充值/退款账本与单条编删")
    func testPhase79BatchBManualLedgerAndPendingCancellation() async throws {
        let container = AppContainer.makeMock()
        let mainVM = MainViewModel(container: container)
        await mainVM.loadAll()

        let qq = try #require(mainVM.subscriptions.first(where: { $0.name.contains("QQ音乐") }))
        await mainVM.selectSubscription(qq.id)
        let beforeNet = mainVM.selectedRecords.reduce(Decimal.zero) { $0 + $1.signedAmount }

        // 1. 新增手动充值/历史扣费 + 退款，校验净消费变化
        await mainVM.addManualBillingRecord(
            for: qq,
            amount: 50,
            currency: "CNY",
            kind: .charge,
            billedAt: Date(),
            note: "升档差价"
        )
        await mainVM.addManualBillingRecord(
            for: qq,
            amount: 15,
            currency: "CNY",
            kind: .refund,
            billedAt: Date(),
            note: "首月返现"
        )
        let afterNet = mainVM.selectedRecords.reduce(Decimal.zero) { $0 + $1.signedAmount }
        #expect(afterNet == beforeNet + 35)

        // 2. 编辑退款并删除之
        let refundRecord = try #require(mainVM.selectedRecords.first(where: { $0.kind == .refund }))
        await mainVM.updateBillingRecord(
            refundRecord,
            newAmount: 25,
            currency: "CNY",
            kind: .refund,
            billedAt: refundRecord.billedAt,
            note: "多退调整"
        )
        #expect(mainVM.selectedRecords.reduce(Decimal.zero) { $0 + $1.signedAmount } == beforeNet + 25)

        let updatedRefund = try #require(mainVM.selectedRecords.first(where: { $0.id == refundRecord.id }))
        await mainVM.deleteBillingRecord(updatedRefund)
        #expect(mainVM.selectedRecords.reduce(Decimal.zero) { $0 + $1.signedAmount } == beforeNet + 50)

        // 3. AnalyticsViewModel 补记一笔退款后，总净支出应减少对应折算金额
        let analyticsVM = AnalyticsViewModel(container: container)
        analyticsVM.selectedRangePreset = .allTime
        analyticsVM.baseCurrency = "CNY"
        await analyticsVM.reloadAnalytics()
        let totalBeforeRefund = try #require(analyticsVM.summary?.totalBaseAmount)

        await mainVM.addManualBillingRecord(
            for: qq,
            amount: 40,
            currency: "CNY",
            kind: .refund,
            billedAt: Date(),
            note: "官方退款"
        )
        await analyticsVM.reloadAnalytics()
        let totalAfterRefund = try #require(analyticsVM.summary?.totalBaseAmount)
        #expect(totalAfterRefund == totalBeforeRefund - 40)
    }

    @Test("Phase 30: 订阅详情历史累计净支出跨币种按日汇率折算并输出原币汇总")
    @MainActor
    func testSubscriptionDetailMultiCurrencyNetSpendConversion() async throws {
        let container = AppContainer.makeMock(repository: MockSubscriptionRepository(useSampleData: false))
        let now = Date()
        let sub = SubscriptionItem(
            name: "Spaceship",
            categoryId: SubscriptionCategory.BuiltinID.domainNetwork,
            templateId: TemplateDefinition.BuiltinID.domain,
            price: Decimal(string: "10.88")!,
            currency: "USD",
            billingCycleType: .annually,
            startDate: now,
            nextRenewalDate: Calendar.current.date(byAdding: .year, value: 1, to: now)!
        )
        let r1 = BillingRecord(
            subscriptionId: sub.id,
            amount: Decimal(string: "10.38")!,
            currency: "USD",
            baseCurrencyAmount: Decimal(string: "10.38")!,
            billedAt: now,
            source: .manualLedger,
            kind: .charge,
            note: "域名转移到 Spaceship"
        )
        let r2 = BillingRecord(
            subscriptionId: sub.id,
            amount: Decimal(string: "109.95")!,
            currency: "CNY",
            baseCurrencyAmount: Decimal(string: "109.95")!,
            billedAt: now.addingTimeInterval(-86400),
            source: .manualLedger,
            kind: .charge,
            note: "初始购买记录"
        )
        try await container.repository.saveSubscription(sub, initialRecords: [r1, r2])

        let mainVM = MainViewModel(container: container)
        await mainVM.loadAll()

        let convertedTotal = try #require(mainVM.totalSpentBySubscriptionId[sub.id])
        // 绝不能直接无视币种相加成 120.33；CNY->USD 约 1/7.2 = 15.27，合计约 25.65
        #expect(convertedTotal < Decimal(40))
        #expect(convertedTotal > Decimal(20))

        let summary = try #require(mainVM.totalSpentSummaryBySubscriptionId[sub.id])
        #expect(summary.hasForeignCurrencyRecords == true)
        #expect(summary.originalCurrencySummaryText == "$10.38 + ¥109.95")
    }
}
