import Foundation

@testable import SubRadarCore

extension MockSampleData {
    static func makeAISampleItems(referenceDate: Date, calendar: Calendar) -> [SubscriptionItem] {
        // 6. AI 会员与额度 Cursor Pro（按月，12 天后到期）
        let cursorId = UUID(uuidString: "10000000-0000-0000-0000-000000000006")!
        let cursorStart = calendar.date(byAdding: .month, value: -4, to: referenceDate) ?? referenceDate
        let cursorNext = calendar.date(byAdding: .day, value: 12, to: referenceDate) ?? referenceDate
        let cursorItem = SubscriptionItem(
            id: cursorId,
            name: "Cursor Pro",
            categoryId: SubscriptionCategory.BuiltinID.aiTools,
            templateId: TemplateDefinition.BuiltinID.aiMembership,
            iconData: PopularSoftwarePresetManager.bundledIconData(forPresetId: "cursor-pro"),
            price: 20,
            currency: "USD",
            billingCycleType: .monthly,
            startDate: cursorStart,
            nextRenewalDate: cursorNext,
            autoRenew: true,
            status: .active,
            reminderDaysBefore: 3,
            notes: "日常主力 AI 编程 IDE，按月自动续费",
            customFields: [
                CustomField(
                    subscriptionId: cursorId, key: "account", label: "登录账号", type: .text, value: "dev@subradar.app",
                    sortOrder: 0),
                CustomField(
                    subscriptionId: cursorId, key: "account_password", label: "登录密码", type: .secret,
                    value: "CursorDemo!2026", sortOrder: 1),
                CustomField(
                    subscriptionId: cursorId, key: "plan_tier", label: "套餐档位", type: .text, value: "Pro", sortOrder: 2),
                CustomField(
                    subscriptionId: cursorId, key: "account_source", label: "来源", type: .text, value: "官网直充",
                    sortOrder: 3),
                CustomField(
                    subscriptionId: cursorId, key: "warranty_policy", label: "质保与售后说明", type: .text, value: "官方账号长期可用",
                    sortOrder: 4),
                CustomField(
                    subscriptionId: cursorId, key: "account_alive_status", label: "存活状态", type: .text, value: "正常存活",
                    sortOrder: 5),
                CustomField(
                    subscriptionId: cursorId, key: "manage_url", label: "官网地址", type: .url,
                    value: "https://www.cursor.com/dashboard", sortOrder: 6)
            ]
        )

        // 7. AI API 与余额监控 DeepSeek（按量充值，演示低余额状态）
        let deepseekId = UUID(uuidString: "10000000-0000-0000-0000-000000000007")!
        let deepseekStart = calendar.date(byAdding: .month, value: -2, to: referenceDate) ?? referenceDate
        let deepseekItem = SubscriptionItem(
            id: deepseekId,
            name: "DeepSeek API",
            categoryId: SubscriptionCategory.BuiltinID.aiTools,
            templateId: TemplateDefinition.BuiltinID.apiBalance,
            iconData: PopularSoftwarePresetManager.bundledIconData(forPresetId: "deepseek"),
            price: 100,
            currency: "CNY",
            billingCycleType: .oneTime,
            startDate: deepseekStart,
            nextRenewalDate: deepseekStart,
            autoRenew: false,
            status: .active,
            reminderDaysBefore: -1,
            notes: "演示 API 余额监控（实付充值 100 元，当前余额低于 10 元触发低余额标记）",
            customFields: [
                CustomField(
                    subscriptionId: deepseekId, key: "provider_preset", label: "API 平台", type: .text, value: "deepseek",
                    sortOrder: 0),
                CustomField(
                    subscriptionId: deepseekId, key: "api_endpoint", label: "余额查询接口", type: .url,
                    value: "https://api.deepseek.com/user/balance", sortOrder: 1),
                CustomField(
                    subscriptionId: deepseekId, key: "api_key", label: "API Key / 鉴权令牌", type: .secret,
                    value: "sk-demo-mock-deepseek-key", sortOrder: 2),
                CustomField(
                    subscriptionId: deepseekId, key: "parse_rule", label: "余额解析规则", type: .text,
                    value: "balance_infos[0].total_balance", sortOrder: 3),
                CustomField(
                    subscriptionId: deepseekId, key: "current_balance", label: "当前账户余额", type: .number, value: "4.20",
                    sortOrder: 4),
                CustomField(
                    subscriptionId: deepseekId, key: "low_balance_threshold", label: "低余额告警阈值", type: .number,
                    value: "10", sortOrder: 5),
                CustomField(
                    subscriptionId: deepseekId, key: "account_source", label: "来源", type: .text, value: "官网直充",
                    sortOrder: 6),
                CustomField(
                    subscriptionId: deepseekId, key: "warranty_policy", label: "质保与售后说明", type: .text,
                    value: "官方直充，长期有效", sortOrder: 7),
                CustomField(
                    subscriptionId: deepseekId, key: "console_url", label: "控制台地址", type: .url,
                    value: "https://platform.deepseek.com", sortOrder: 8)
            ]
        )

        return [cursorItem, deepseekItem]
    }

    static func buildSampleRecords(for items: [SubscriptionItem], billingEngine: BillingEngine) -> [BillingRecord] {
        var allRecords: [BillingRecord] = []

        for item in items {
            let rate = Decimal(ExchangeRateService.staticFallbackRate(from: item.currency, to: "CNY"))
            let endBoundary = item.billingCycleType == .oneTime ? item.startDate : item.nextRenewalDate
            let preview = billingEngine.previewHistoricalBilling(
                startDate: item.startDate,
                endDate: endBoundary,
                cycleType: item.billingCycleType,
                customDays: item.billingCycleDays,
                price: item.price
            )
            let isApiBalance = item.templateId == TemplateDefinition.BuiltinID.apiBalance
            for date in preview.billingDates {
                allRecords.append(
                    BillingRecord(
                        subscriptionId: item.id,
                        amount: item.price,
                        currency: item.currency,
                        baseCurrencyAmount: item.price * rate,
                        billedAt: date,
                        source: isApiBalance
                            ? .manualLedger : (item.billingCycleType == .oneTime ? .initialPurchase : .historicalAuto),
                        kind: isApiBalance ? .topUp : .charge,
                        note: isApiBalance ? "API 账户充值" : (item.billingCycleType == .oneTime ? "一次性购买" : "历史账单")
                    )
                )
            }
        }
        return allRecords
    }
}
