import Foundation
import Observation

extension EditorViewModel {
    public func updatePurchasePriceText(_ value: String) {
        priceText = value
        if apiTopUpAmounts.isEmpty {
            apiTopUpAmounts = [value]
        } else if apiTopUpAmounts.count == 1 {
            apiTopUpAmounts[0] = value
        }
        if !isEditing && !hasEditedRenewalPrice {
            renewalPriceText = value
        }
    }

    public func updateAPITopUpCount(_ count: Int) {
        let clamped = max(1, min(50, count))
        apiTopUpCountText = String(clamped)
        syncAPITopUpRowsToCount(clamped)
    }

    public func syncAPITopUpCountText(_ text: String) {
        apiTopUpCountText = text
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsed = Int(trimmed), parsed >= 1 else { return }
        let clamped = min(50, parsed)
        if clamped != parsed {
            apiTopUpCountText = String(clamped)
        }
        syncAPITopUpRowsToCount(clamped)
    }

    public func updateAPITopUpAmount(_ text: String, at index: Int) {
        syncAPITopUpRowsToCount(parsedAPITopUpCount)
        guard apiTopUpAmounts.indices.contains(index) else { return }
        apiTopUpAmounts[index] = text
        if index == 0 {
            priceText = text
        }
    }

    public func setAPITopUpAverageMode(_ enabled: Bool) {
        guard isAPITopUpAverageMode != enabled else { return }
        if enabled {
            if apiTopUpTotalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let currentSum = previewAPITopUpAmounts.reduce(0, +)
                if currentSum > 0 {
                    apiTopUpTotalText = NSDecimalNumber(decimal: currentSum).stringValue
                }
            }
        } else {
            let split = resolvedAPITopUpAmounts(allowZeroFallback: false) ?? []
            if !split.isEmpty {
                apiTopUpAmounts = split.map { NSDecimalNumber(decimal: $0).stringValue }
                priceText = apiTopUpAmounts.first ?? priceText
            }
        }
        isAPITopUpAverageMode = enabled
    }

    func syncAPITopUpRowsToCount(_ targetCount: Int) {
        if apiTopUpAmounts.count < targetCount {
            while apiTopUpAmounts.count < targetCount {
                apiTopUpAmounts.append("")
            }
        } else if apiTopUpAmounts.count > targetCount {
            apiTopUpAmounts = Array(apiTopUpAmounts.prefix(targetCount))
        }
    }

    public func resolvedAPITopUpAmounts(allowZeroFallback: Bool) -> [Decimal]? {
        let count = parsedAPITopUpCount
        if isAPITopUpAverageMode {
            let trimmed = apiTopUpTotalText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, let total = Decimal(string: trimmed), total >= 0 else {
                return allowZeroFallback ? Array(repeating: 0, count: count) : nil
            }
            return Self.splitDecimalTotal(total, count: count)
        }

        let trimmedLegacyPrice = priceText.trimmingCharacters(in: .whitespacesAndNewlines)
        let allRowsUneditedOrSingle =
            apiTopUpAmounts.count <= 1
            && (apiTopUpAmounts.first?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
                || apiTopUpAmounts.first == priceText)
        if allRowsUneditedOrSingle && count > 1,
            !trimmedLegacyPrice.isEmpty,
            let single = Decimal(string: trimmedLegacyPrice),
            single >= 0
        {
            return Array(repeating: single, count: count)
        }

        var result: [Decimal] = []
        for idx in 0..<count {
            let raw = (idx < apiTopUpAmounts.count ? apiTopUpAmounts[idx] : "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if raw.isEmpty {
                if allowZeroFallback {
                    result.append(0)
                    continue
                }
                return nil
            }
            guard let val = Decimal(string: raw), val >= 0 else {
                if allowZeroFallback {
                    result.append(0)
                    continue
                }
                return nil
            }
            result.append(val)
        }
        return result
    }

    private static func splitDecimalTotal(_ total: Decimal, count: Int) -> [Decimal] {
        guard count > 1 else { return [total] }
        let behavior = NSDecimalNumberHandler(
            roundingMode: .bankers,
            scale: 2,
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: false
        )
        let unit =
            (total as NSDecimalNumber)
            .dividing(by: NSDecimalNumber(value: count), withBehavior: behavior) as Decimal
        var rows = Array(repeating: unit, count: count - 1)
        let tail = max(0, total - unit * Decimal(count - 1))
        rows.append(tail)
        return rows
    }

    public func updateRenewalPriceText(_ value: String) {
        renewalPriceText = value
        hasEditedRenewalPrice = !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 当前合并后的计费单位（按天 / 按周 / 按月 / 按年 / 买断）
    public var billingCycleUnit: BillingCycleUnit {
        get { billingCycleType.normalizedUnitAndCount(intervalCount: nil).unit }
        set { updateBillingUnit(newValue) }
    }

    /// 格式化的当前付费频率标签（如 "按年" / "每 3 年" / "每 4 个月" / "按月"）
    public var billingCycleDisplayName: String {
        billingCycleType.formattedDisplayName(intervalCount: parsedCustomDays)
    }

    public func updateBillingUnit(_ newUnit: BillingCycleUnit) {
        let oldUnit = billingCycleUnit
        billingCycleType = newUnit.canonicalCycleType
        switch newUnit {
        case .oneTime:
            billingCycleIntervalText = "1"
        case .day:
            if oldUnit != .day && (Int(billingCycleIntervalText) ?? 1) <= 1 {
                billingCycleIntervalText = "30"
            }
        case .week, .month, .year:
            if oldUnit == .day && billingCycleIntervalText == "30" {
                billingCycleIntervalText = "1"
            } else if billingCycleIntervalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                billingCycleIntervalText = "1"
            }
        }
        syncNextRenewalDateAfterCycleChangeIfNeeded()
    }

    public func updateBillingIntervalText(_ value: String) {
        billingCycleIntervalText = value
        syncNextRenewalDateAfterCycleChangeIfNeeded()
    }

    func syncNextRenewalDateAfterCycleChangeIfNeeded() {
        guard !isEditing else { return }
        if billingCycleUnit == .oneTime {
            nextRenewalDate = startDate
        } else if let computedNext = billingCycleType.nextDate(from: startDate, customDays: parsedCustomDays) {
            nextRenewalDate = computedNext
        }
    }

    public var parsedCustomDays: Int? {
        let trimmed = billingCycleIntervalText.trimmingCharacters(in: .whitespacesAndNewlines)
        switch billingCycleUnit {
        case .oneTime:
            return nil
        case .day:
            return Int(trimmed)
        case .week, .month, .year:
            guard !trimmed.isEmpty, let count = Int(trimmed) else { return nil }
            if count <= 0 { return count }  // 保留非正数以触发合法性校验报错
            return count == 1 ? nil : count
        }
    }

    /// 实时计算历史计费预览（勾选“历史计费”时即时反馈）
    public var historicalPreview: HistoricalBillingPreview {
        container.billingEngine.previewHistoricalBilling(
            startDate: startDate,
            endDate: nextRenewalDate,
            cycleType: billingCycleType,
            customDays: parsedCustomDays,
            price: parsedPrice,
            renewalPrice: parsedRenewalPrice
        )
    }
}
