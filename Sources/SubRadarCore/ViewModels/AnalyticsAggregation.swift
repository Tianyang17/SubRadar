import Foundation

extension AnalyticsViewModel {
    struct ExpiryMetricsResult {
        let upcoming30DaysBaseAmount: Decimal
        let overdueOrSoonCount: Int
        let expiryBuckets: [ExpenseAnalyticsSummary.ExpiryBucket]
        let upcomingRenewals: [ExpenseAnalyticsSummary.UpcomingRenewalItem]
        let oneTimeAssets: [ExpenseAnalyticsSummary.UpcomingRenewalItem]
    }

    func buildExpiryMetrics(
        from subscriptions: [SubscriptionItem],
        categoryById: [UUID: SubscriptionCategory],
        upperBase: String
    ) async -> ExpiryMetricsResult {
        let referenceNow = Date()
        let activeSubs = subscriptions.filter { $0.status == .active }
        var bucketCounts: [String: (count: Int, amount: Decimal)] = [
            "已逾期": (0, 0),
            "7天内": (0, 0),
            "8~30天": (0, 0),
            "31~90天": (0, 0),
            "90天+": (0, 0),
            "永久买断": (0, 0)
        ]
        var upcomingList: [ExpenseAnalyticsSummary.UpcomingRenewalItem] = []
        var oneTimeList: [ExpenseAnalyticsSummary.UpcomingRenewalItem] = []
        var upcoming30Base = Decimal.zero
        var overdueOrSoon = 0

        for item in activeSubs {
            let renewPrice = item.effectiveRenewalPrice
            let rate: Decimal
            if item.currency.uppercased() == upperBase {
                rate = 1
            } else {
                rate = await container.exchangeRateService.rate(
                    from: item.currency,
                    to: baseCurrency,
                    on: referenceNow
                )
            }
            let baseRenewal = renewPrice * rate
            let cat = categoryById[item.categoryId]
            let catName = cat?.name ?? "未分类"
            let catColor = cat?.colorKey.rawValue ?? "indigo"

            if item.billingCycleType == .oneTime {
                let oneTimeBase = item.price * rate
                var entry = bucketCounts["永久买断"] ?? (0, 0)
                entry.count += 1
                entry.amount += oneTimeBase
                bucketCounts["永久买断"] = entry
                oneTimeList.append(
                    ExpenseAnalyticsSummary.UpcomingRenewalItem(
                        subscriptionId: item.id,
                        name: item.name,
                        categoryName: catName,
                        categoryColorToken: catColor,
                        iconData: item.iconData,
                        nextBillingDate: item.startDate,
                        daysRemaining: Int.max,
                        renewalPrice: item.price,
                        currency: item.currency,
                        renewalBaseAmount: oneTimeBase,
                        isAutoRenew: false,
                        billingCycleType: item.billingCycleType,
                        billingCycleDays: item.billingCycleDays,
                        status: item.status,
                        windowLabel: "永久买断"
                    )
                )
                continue
            }

            let days = item.daysUntilRenewal(referenceDate: referenceNow, calendar: calendar)
            let willAutoCharge = item.status == .active && item.renewalMode != .doNotRenew
            let bucketLabel: String
            if days < 0 {
                bucketLabel = "已逾期"
                overdueOrSoon += 1
                if willAutoCharge { upcoming30Base += baseRenewal }
            } else if days <= 7 {
                bucketLabel = "7天内"
                overdueOrSoon += 1
                if willAutoCharge { upcoming30Base += baseRenewal }
            } else if days <= 30 {
                bucketLabel = "8~30天"
                if willAutoCharge { upcoming30Base += baseRenewal }
            } else if days <= 90 {
                bucketLabel = "31~90天"
            } else {
                bucketLabel = "90天+"
            }

            var entry = bucketCounts[bucketLabel] ?? (0, 0)
            entry.count += 1
            entry.amount += baseRenewal
            bucketCounts[bucketLabel] = entry

            upcomingList.append(
                ExpenseAnalyticsSummary.UpcomingRenewalItem(
                    subscriptionId: item.id,
                    name: item.name,
                    categoryName: catName,
                    categoryColorToken: catColor,
                    iconData: item.iconData,
                    nextBillingDate: item.nextRenewalDate,
                    daysRemaining: days,
                    renewalPrice: renewPrice,
                    currency: item.currency,
                    renewalBaseAmount: baseRenewal,
                    isAutoRenew: item.autoRenew,
                    billingCycleType: item.billingCycleType,
                    billingCycleDays: item.billingCycleDays,
                    status: item.status
                )
            )
        }

        upcomingList.sort {
            if $0.daysRemaining != $1.daysRemaining {
                return $0.daysRemaining < $1.daysRemaining
            }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }

        let bucketSpecs: [(String, String)] = [
            ("已逾期", "red"),
            ("7天内", "orange"),
            ("8~30天", "blue"),
            ("31~90天", "purple"),
            ("90天+", "green"),
            ("永久买断", "indigo")
        ]
        let expiryBuckets: [ExpenseAnalyticsSummary.ExpiryBucket] = bucketSpecs.map { label, colorToken in
            let info = bucketCounts[label] ?? (0, 0)
            return ExpenseAnalyticsSummary.ExpiryBucket(
                label: label,
                count: info.count,
                estimatedRenewalBaseAmount: info.amount,
                colorToken: colorToken
            )
        }

        return ExpiryMetricsResult(
            upcoming30DaysBaseAmount: upcoming30Base,
            overdueOrSoonCount: overdueOrSoon,
            expiryBuckets: expiryBuckets,
            upcomingRenewals: upcomingList,
            oneTimeAssets: oneTimeList.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        )
    }

    func buildAPIBalanceItems(
        from subscriptions: [SubscriptionItem],
        upperBase: String
    ) async -> [ExpenseAnalyticsSummary.APIBalanceOverviewItem] {
        let apiSubs =
            subscriptions
            .filter { $0.templateId == TemplateDefinition.BuiltinID.apiBalance && $0.status != .cancelled }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        guard !apiSubs.isEmpty else { return [] }

        var result: [ExpenseAnalyticsSummary.APIBalanceOverviewItem] = []
        result.reserveCapacity(apiSubs.count)

        for item in apiSubs {
            let balanceRaw = item.customFields.first(where: { $0.key == "current_balance" })?.value
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let currentBalance = balanceRaw.flatMap { Decimal(string: $0) }

            let thresholdRaw = item.customFields.first(where: { $0.key == "low_balance_threshold" })?.value
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let lowThreshold = thresholdRaw.flatMap { Decimal(string: $0) }

            let providerRaw = item.customFields.first(where: { $0.key == "provider_preset" })?.value ?? ""
            let providerName = APIBalanceProviderPreset(raw: providerRaw).displayName

            let currentRate: Decimal
            if item.currency.uppercased() == upperBase {
                currentRate = 1
            } else {
                currentRate = await container.exchangeRateService.rate(
                    from: item.currency,
                    to: baseCurrency,
                    on: Date()
                )
            }
            let balanceBaseAmount = currentBalance.map { $0 * currentRate }

            let subRecords = (try? await container.repository.fetchBillingRecords(for: item.id)) ?? []
            var netOrig = Decimal.zero
            var netBase = Decimal.zero
            var topUpCount = 0
            for rec in subRecords {
                let mult = rec.kind.signMultiplier
                netOrig += rec.amount * mult
                if rec.currency.uppercased() == upperBase {
                    netBase += rec.amount * mult
                } else {
                    let recRate = await container.exchangeRateService.rate(
                        from: rec.currency,
                        to: baseCurrency,
                        on: rec.billedAt
                    )
                    netBase += rec.amount * recRate * mult
                }
                if rec.kind == .topUp {
                    topUpCount += 1
                }
            }
            if subRecords.isEmpty && item.price > 0 {
                netOrig = item.price
                netBase = item.price * currentRate
                topUpCount = 1
            }

            let isLowBalance: Bool =
                if let bal = currentBalance, let threshold = lowThreshold {
                    bal <= threshold
                } else {
                    false
                }

            result.append(
                ExpenseAnalyticsSummary.APIBalanceOverviewItem(
                    subscriptionId: item.id,
                    name: item.name,
                    providerName: providerName,
                    iconData: item.iconData,
                    currency: item.currency,
                    currentBalance: currentBalance,
                    balanceBaseAmount: balanceBaseAmount,
                    lowThreshold: lowThreshold,
                    isLowBalance: isLowBalance,
                    netRechargedBaseAmount: max(0, netBase),
                    netRechargedOriginalAmount: max(0, netOrig),
                    topUpCount: topUpCount
                )
            )
        }
        return result
    }
}
