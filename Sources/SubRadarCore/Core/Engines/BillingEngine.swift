import Foundation

/// 纯 Swift 计费与日历周期推演引擎
public final class BillingEngine: BillingEngineProtocol, Sendable {
    private let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func previewHistoricalBilling(
        startDate: Date,
        endDate: Date,
        cycleType: BillingCycleType,
        customDays: Int?,
        price: Decimal,
        renewalPrice: Decimal? = nil
    ) -> HistoricalBillingPreview {
        let normalizedPurchasePrice = max(0, price)
        let normalizedRenewalPrice = max(0, renewalPrice ?? price)
        let startDay = calendar.startOfDay(for: startDate)
        let endDay = calendar.startOfDay(for: endDate)

        guard endDay >= startDay else {
            return HistoricalBillingPreview(
                cycleCount: 0,
                totalAmount: 0,
                billingDates: [],
                calculatedNextRenewalDate: endDate
            )
        }

        if cycleType == .oneTime {
            return HistoricalBillingPreview(
                cycleCount: 1,
                totalAmount: normalizedPurchasePrice,
                billingDates: [startDate],
                calculatedNextRenewalDate: nil
            )
        }

        var billingDates: [Date] = []
        let maxCycles = 1200  // 防御上限：100年按月计费
        var cycleIndex = 0
        var nextBoundary = startDate

        while cycleIndex < maxCycles {
            guard
                let cycleDate = dateByAdding(
                    cycles: cycleIndex, from: startDate, cycleType: cycleType, customDays: customDays)
            else {
                break
            }
            let cycleDay = calendar.startOfDay(for: cycleDate)
            if cycleDay >= endDay {
                nextBoundary = cycleDate
                break
            }
            billingDates.append(cycleDate)
            cycleIndex += 1
            nextBoundary =
                dateByAdding(cycles: cycleIndex, from: startDate, cycleType: cycleType, customDays: customDays)
                ?? endDate
        }

        let total: Decimal =
            if billingDates.isEmpty {
                0
            } else {
                normalizedPurchasePrice + Decimal(billingDates.count - 1) * normalizedRenewalPrice
            }
        return HistoricalBillingPreview(
            cycleCount: billingDates.count,
            totalAmount: total,
            billingDates: billingDates,
            calculatedNextRenewalDate: billingDates.isEmpty ? endDate : nextBoundary
        )
    }

    public func generateHistoricalRecords(
        for item: SubscriptionItem,
        endDate: Date,
        rateToBaseProvider: @Sendable (Date, String) async -> Decimal
    ) async -> [BillingRecord] {
        let effectiveRenewal = item.billingCycleType == .oneTime ? nil : item.effectiveRenewalPrice
        let preview = previewHistoricalBilling(
            startDate: item.startDate,
            endDate: endDate,
            cycleType: item.billingCycleType,
            customDays: item.billingCycleDays,
            price: item.price,
            renewalPrice: effectiveRenewal
        )

        var records: [BillingRecord] = []
        records.reserveCapacity(preview.billingDates.count)

        for (index, date) in preview.billingDates.enumerated() {
            let unitAmount = (index == 0 || item.billingCycleType == .oneTime) ? item.price : item.effectiveRenewalPrice
            let rate = await rateToBaseProvider(date, item.currency)
            let baseAmount = unitAmount * rate
            let source: BillingRecordSource
            let note: String
            if item.billingCycleType == .oneTime {
                source = .initialPurchase
                note = "一次性购买"
            } else if index == 0 {
                source = .initialPurchase
                note = "首次购买"
            } else {
                source = .historicalAuto
                note = "历史计费自动推算"
            }
            records.append(
                BillingRecord(
                    subscriptionId: item.id,
                    amount: unitAmount,
                    currency: item.currency,
                    baseCurrencyAmount: baseAmount,
                    billedAt: date,
                    source: source,
                    note: note
                )
            )
        }
        return records
    }

    public func processRenewal(
        for item: SubscriptionItem,
        actualPrice: Decimal?,
        renewedAt: Date = Date(),
        source: BillingRecordSource = .manualRenew,
        rateToBase: Decimal = 1
    ) -> (updatedItem: SubscriptionItem, record: BillingRecord) {
        let effectivePrice = max(0, actualPrice ?? item.effectiveRenewalPrice)
        let baseAmount = effectivePrice * rateToBase

        let record = BillingRecord(
            subscriptionId: item.id,
            amount: effectivePrice,
            currency: item.currency,
            baseCurrencyAmount: baseAmount,
            billedAt: renewedAt,
            source: source,
            note: source.displayName
        )

        var updated = item
        if item.billingCycleType != .oneTime,
            let nextDate = item.billingCycleType.nextDate(
                from: item.nextRenewalDate,
                customDays: item.billingCycleDays,
                calendar: calendar
            )
        {
            updated.nextRenewalDate = nextDate
        }
        updated.status = .active
        updated.updatedAt = Date()

        return (updated, record)
    }

    /// 始终以初始 startDate 为锚点按倍数递增，杜绝月底（如 1月31日 -> 2月28日 -> 3月28日）日期漂移（支持每 N 天 / 周 / 月 / 年）
    private func dateByAdding(
        cycles: Int,
        from startDate: Date,
        cycleType: BillingCycleType,
        customDays: Int?
    ) -> Date? {
        if cycles == 0 { return startDate }
        let (unit, count) = cycleType.normalizedUnitAndCount(intervalCount: customDays)
        switch unit {
        case .day:
            return calendar.date(byAdding: .day, value: cycles * count, to: startDate)
        case .week:
            return calendar.date(byAdding: .day, value: cycles * 7 * count, to: startDate)
        case .month:
            return calendar.date(byAdding: .month, value: cycles * count, to: startDate)
        case .year:
            return calendar.date(byAdding: .year, value: cycles * count, to: startDate)
        case .oneTime:
            return nil
        }
    }
}
