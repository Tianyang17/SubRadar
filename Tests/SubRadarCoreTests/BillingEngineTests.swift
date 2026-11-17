import Foundation
import Testing

@testable import SubRadarCore

@Suite("BillingEngine 核心计费引擎测试")
struct BillingEngineTests {
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        return cal
    }()

    private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 10))!
    }

    @Test("跨多年年付历史计费自动推算周期与金额")
    func testMultiYearAnnualHistoricalBilling() {
        let engine = BillingEngine(calendar: calendar)
        let start = makeDate(2021, 1, 1)
        let end = makeDate(2026, 1, 1)

        let preview = engine.previewHistoricalBilling(
            startDate: start,
            endDate: end,
            cycleType: .annually,
            customDays: nil,
            price: Decimal(string: "298.00")!
        )

        #expect(preview.cycleCount == 5)
        #expect(preview.totalAmount == Decimal(string: "1490.00")!)
        #expect(preview.billingDates.count == 5)
        #expect(calendar.component(.year, from: preview.billingDates[0]) == 2021)
        #expect(calendar.component(.year, from: preview.billingDates[4]) == 2025)
        #expect(preview.calculatedNextRenewalDate.map { calendar.component(.year, from: $0) } == 2026)
    }

    @Test("月底日期按月递增不发生日期漂移（含闰年2月29日）")
    func testMonthEndNoDriftAcrossLeapYear() {
        let engine = BillingEngine(calendar: calendar)
        let start = makeDate(2024, 1, 31)
        let end = makeDate(2024, 6, 1)

        let preview = engine.previewHistoricalBilling(
            startDate: start,
            endDate: end,
            cycleType: .monthly,
            customDays: nil,
            price: 15
        )

        // 1/31, 2/29(闰年), 3/31, 4/30, 5/31 共 5 个周期
        #expect(preview.cycleCount == 5)
        #expect(preview.totalAmount == 75)

        let days = preview.billingDates.map { calendar.component(.day, from: $0) }
        #expect(days == [31, 29, 31, 30, 31])
    }

    @Test("一次性买断模式计费")
    func testOneTimePurchase() {
        let engine = BillingEngine(calendar: calendar)
        let start = makeDate(2025, 5, 1)
        let preview = engine.previewHistoricalBilling(
            startDate: start,
            endDate: makeDate(2026, 11, 13),
            cycleType: .oneTime,
            customDays: nil,
            price: 99
        )

        #expect(preview.cycleCount == 1)
        #expect(preview.totalAmount == 99)
        #expect(preview.calculatedNextRenewalDate == nil)
    }

    @Test("确认续订后推进下次续订日并生成账单流水")
    func testProcessRenewal() {
        let engine = BillingEngine(calendar: calendar)
        let start = makeDate(2025, 11, 13)
        let next = makeDate(2026, 11, 13)

        let item = SubscriptionItem(
            name: "BandwagonHost",
            templateId: TemplateDefinition.BuiltinID.vps,
            price: Decimal(string: "89.99")!,
            currency: "USD",
            billingCycleType: .annually,
            startDate: start,
            nextRenewalDate: next
        )

        let (updated, record) = engine.processRenewal(
            for: item,
            actualPrice: nil,
            renewedAt: next,
            source: .manualRenew,
            rateToBase: Decimal(string: "7.2")!
        )

        #expect(calendar.component(.year, from: updated.nextRenewalDate) == 2027)
        #expect(record.amount == Decimal(string: "89.99")!)
        #expect(record.baseCurrencyAmount == Decimal(string: "89.99")! * Decimal(string: "7.2")!)
        #expect(record.source == .manualRenew)
    }

    @Test("Phase 6: 按周付费周期与完整周期枚举顺序验证")
    func testWeeklyBillingCycle() {
        #expect(
            BillingCycleType.allCases == [
                .weekly, .monthly, .quarterly, .semiannually, .annually, .customDays, .oneTime
            ])
        #expect(BillingCycleType.weekly.displayName == "按周")

        let engine = BillingEngine(calendar: calendar)
        let start = makeDate(2026, 3, 1)
        let end = makeDate(2026, 3, 22)  // 整 3 周：3/1, 3/8, 3/15
        let preview = engine.previewHistoricalBilling(
            startDate: start,
            endDate: end,
            cycleType: .weekly,
            customDays: nil,
            price: 12
        )

        #expect(preview.cycleCount == 3)
        #expect(preview.totalAmount == 36)
        #expect(calendar.component(.day, from: preview.calculatedNextRenewalDate ?? start) == 22)
    }

    @Test("Phase 7.7: 购买价格与续期价格分离推算及续订默认使用续期价格")
    func testPurchaseAndRenewalSeparatePrices() {
        let engine = BillingEngine(calendar: calendar)
        let start = makeDate(2024, 1, 1)
        let end = makeDate(2027, 1, 1)  // 2024(首购 99), 2025(续期 198), 2026(续期 198)

        let preview = engine.previewHistoricalBilling(
            startDate: start,
            endDate: end,
            cycleType: .annually,
            customDays: nil,
            price: Decimal(string: "99.00")!,
            renewalPrice: Decimal(string: "198.00")!
        )

        #expect(preview.cycleCount == 3)
        #expect(preview.totalAmount == Decimal(string: "495.00")!)

        let item = SubscriptionItem(
            name: "Cloud Server",
            templateId: TemplateDefinition.BuiltinID.vps,
            price: Decimal(string: "99.00")!,
            renewalPrice: Decimal(string: "198.00")!,
            currency: "CNY",
            billingCycleType: .annually,
            startDate: start,
            nextRenewalDate: end
        )
        #expect(item.effectiveRenewalPrice == Decimal(string: "198.00")!)

        let (_, record) = engine.processRenewal(
            for: item,
            actualPrice: nil,
            renewedAt: end,
            source: .manualRenew,
            rateToBase: 1
        )
        #expect(record.amount == Decimal(string: "198.00")!)
    }

    @Test("Phase 7.8: 统一多期计费周期（每 3 年 / 每 4 个月 / 每 2 周 / 传统 quarterly 兼容）")
    func testMergedMultiPeriodBillingCycles() {
        #expect(BillingCycleType.annually.formattedDisplayName(intervalCount: 1) == "按年")
        #expect(BillingCycleType.annually.formattedDisplayName(intervalCount: 3) == "每 3 年")
        #expect(BillingCycleType.monthly.formattedDisplayName(intervalCount: 4) == "每 4 个月")
        #expect(BillingCycleType.quarterly.normalizedUnitAndCount(intervalCount: nil) == (.month, 3))
        #expect(BillingCycleType.quarterly.formattedDisplayName(intervalCount: nil) == "每 3 个月")
        #expect(BillingCycleType.semiannually.normalizedUnitAndCount(intervalCount: nil) == (.month, 6))
        #expect(BillingCycleType.weekly.formattedDisplayName(intervalCount: 2) == "每 2 周")
        #expect(BillingCycleType.customDays.formattedDisplayName(intervalCount: 45) == "每 45 天")

        let engine = BillingEngine(calendar: calendar)
        // 每 3 年：2020-01-01 -> 2026-01-01 = 2 次续订（2020, 2023），下次 2026-01-01
        let start3Y = makeDate(2020, 1, 1)
        let end3Y = makeDate(2026, 1, 1)
        let preview3Y = engine.previewHistoricalBilling(
            startDate: start3Y,
            endDate: end3Y,
            cycleType: .annually,
            customDays: 3,
            price: 300
        )
        #expect(preview3Y.cycleCount == 2)
        #expect(preview3Y.totalAmount == 600)
        #expect(calendar.component(.year, from: preview3Y.calculatedNextRenewalDate ?? start3Y) == 2026)

        // 每 4 个月：2025-01-01 -> 2026-01-01 = 3 次（1月、5月、9月），下次 2026-01-01
        let preview4M = engine.previewHistoricalBilling(
            startDate: makeDate(2025, 1, 1),
            endDate: makeDate(2026, 1, 1),
            cycleType: .monthly,
            customDays: 4,
            price: 40
        )
        #expect(preview4M.cycleCount == 3)
        #expect(preview4M.totalAmount == 120)
        #expect(calendar.component(.year, from: preview4M.calculatedNextRenewalDate ?? start3Y) == 2026)

        // 月均折算系数：1200 元每 3 年（36 个月） -> 每月等效 33.333...
        let factor3Y = BillingCycleType.annually.monthlyEquivalenceFactor(intervalCount: 3)
        #expect(abs((Decimal(360) * factor3Y) - Decimal(10)) < Decimal(string: "0.001")!)

        // 每 4 个月（120 元）-> 每月等效 30 元
        let factor4M = BillingCycleType.monthly.monthlyEquivalenceFactor(intervalCount: 4)
        #expect(abs((Decimal(120) * factor4M) - Decimal(30)) < Decimal(string: "0.001")!)
    }
}
