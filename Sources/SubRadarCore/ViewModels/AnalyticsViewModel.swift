import Foundation
import Observation

/// 统计时间段预设选项
public enum AnalyticsRangePreset: String, CaseIterable, Identifiable, Sendable {
    case thisMonth
    case thisQuarter
    case thisYear
    case allTime
    case custom

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .thisMonth: return "本月"
        case .thisQuarter: return "本季度"
        case .thisYear: return "今年"
        case .allTime: return "全部历史"
        case .custom: return "自定义"
        }
    }
}

/// 自定义时间段消费分析 ViewModel
@Observable
@MainActor
public final class AnalyticsViewModel {
    let container: AppContainer
    let calendar: Calendar

    public var selectedRangePreset: AnalyticsRangePreset = .thisYear
    public var customStartDate: Date
    public var customEndDate: Date
    public var baseCurrency: String = "CNY"
    public var selectedCategoryFilterId: UUID?

    public var summary: ExpenseAnalyticsSummary?
    public var subscriptionNamesById: [UUID: String] = [:]
    public var categoriesById: [UUID: SubscriptionCategory] = [:]
    public var isLoading: Bool = false

    public init(container: AppContainer, calendar: Calendar = .current) {
        self.container = container
        self.calendar = calendar
        let now = Date()
        self.customEndDate = now
        self.customStartDate = calendar.date(byAdding: .year, value: -1, to: now) ?? now
    }

    public var filteredRecords: [BillingRecord] {
        guard let summary else { return [] }
        guard let filterCategoryId = selectedCategoryFilterId else {
            return summary.records
        }
        let matchingSubIds = Set(cachedSubscriptions.filter { $0.categoryId == filterCategoryId }.map(\.id))
        return summary.records.filter { matchingSubIds.contains($0.subscriptionId) }
    }

    private var cachedSubscriptions: [SubscriptionItem] = []

    public func reloadAnalytics() async {
        isLoading = true
        defer { isLoading = false }

        let (start, end) = resolvedDateRange()
        let subscriptions = (try? await container.repository.fetchSubscriptions()) ?? []
        let categories = (try? await container.repository.fetchCategories()) ?? CategoryPresetManager.builtinCategories
        let records = (try? await container.repository.fetchBillingRecords(from: start, to: end)) ?? []

        cachedSubscriptions = subscriptions
        subscriptionNamesById = Dictionary(uniqueKeysWithValues: subscriptions.map { ($0.id, $0.name) })

        let subById = Dictionary(uniqueKeysWithValues: subscriptions.map { ($0.id, $0) })
        let categoryById = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        categoriesById = categoryById

        var totalBase = Decimal.zero
        var categoryTotals: [UUID: (amount: Decimal, count: Int)] = [:]
        var monthTotals: [String: (monthDate: Date, categoryId: UUID, amount: Decimal)] = [:]
        var convertedRecords: [BillingRecord] = []
        convertedRecords.reserveCapacity(records.count)

        let upperBase = baseCurrency.uppercased()
        for record in records {
            let convertedBase: Decimal
            let effectiveRate: Decimal
            if record.currency.uppercased() == upperBase {
                effectiveRate = 1
                convertedBase = record.amount
            } else {
                effectiveRate = await container.exchangeRateService.rate(
                    from: record.currency,
                    to: baseCurrency,
                    on: record.billedAt
                )
                convertedBase = record.amount * effectiveRate
            }

            convertedRecords.append(
                BillingRecord(
                    id: record.id,
                    subscriptionId: record.subscriptionId,
                    amount: record.amount,
                    currency: record.currency,
                    baseCurrencyAmount: convertedBase,
                    billedAt: record.billedAt,
                    source: record.source,
                    kind: record.kind,
                    note: record.note
                )
            )

            let signedBase = convertedBase * record.kind.signMultiplier
            totalBase += signedBase

            let categoryId = subById[record.subscriptionId]?.categoryId ?? SubscriptionCategory.BuiltinID.streaming
            var catEntry = categoryTotals[categoryId] ?? (0, 0)
            catEntry.amount += signedBase
            catEntry.count += 1
            categoryTotals[categoryId] = catEntry

            let comps = calendar.dateComponents([.year, .month], from: record.billedAt)
            let yearMonth = String(format: "%04d-%02d", comps.year ?? 2026, comps.month ?? 1)
            let monthDate =
                calendar.date(from: DateComponents(year: comps.year, month: comps.month, day: 1)) ?? record.billedAt
            let trendKey = "\(yearMonth)|\(categoryId.uuidString)"
            var trendEntry = monthTotals[trendKey] ?? (monthDate, categoryId, 0)
            trendEntry.amount += signedBase
            monthTotals[trendKey] = trendEntry
        }

        let breakdowns: [ExpenseAnalyticsSummary.CategoryBreakdown] = categoryTotals.compactMap { categoryId, info in
            guard info.amount > 0 else { return nil }
            let name = categoryById[categoryId]?.name ?? "其他分类"
            return ExpenseAnalyticsSummary.CategoryBreakdown(
                categoryId: categoryId,
                categoryName: name,
                totalBaseAmount: info.amount,
                recordCount: info.count
            )
        }
        .sorted { $0.totalBaseAmount > $1.totalBaseAmount }

        let trends: [ExpenseAnalyticsSummary.MonthlyTrendPoint] = monthTotals.compactMap { key, info in
            let ym = String(key.split(separator: "|").first ?? "")
            let name = categoryById[info.categoryId]?.name ?? "其他分类"
            return ExpenseAnalyticsSummary.MonthlyTrendPoint(
                yearMonth: ym,
                monthDate: info.monthDate,
                categoryId: info.categoryId,
                categoryName: name,
                totalBaseAmount: max(0, info.amount)
            )
        }
        .sorted { $0.monthDate < $1.monthDate }

        let expiryMetrics = await buildExpiryMetrics(
            from: subscriptions,
            categoryById: categoryById,
            upperBase: upperBase
        )

        let effectiveStart: Date
        let effectiveEnd: Date
        if selectedRangePreset == .allTime, let minDate = convertedRecords.map(\.billedAt).min(),
            let maxDate = convertedRecords.map(\.billedAt).max()
        {
            effectiveStart = minDate
            effectiveEnd = max(maxDate, Date())
        } else {
            effectiveStart = start
            effectiveEnd = end
        }

        let daySpan = max(
            1,
            (calendar.dateComponents(
                [.day], from: calendar.startOfDay(for: effectiveStart), to: calendar.startOfDay(for: effectiveEnd)
            ).day ?? 0) + 1)
        let dailyAvg = totalBase / Decimal(daySpan)
        let activeCount = subscriptions.filter { $0.status == .active }.count
        let apiBalanceItems = await buildAPIBalanceItems(
            from: subscriptions,
            upperBase: upperBase
        )

        summary = ExpenseAnalyticsSummary(
            startDate: effectiveStart,
            endDate: effectiveEnd,
            baseCurrency: upperBase,
            totalBaseAmount: totalBase,
            dailyAverageBaseAmount: dailyAvg,
            activeSubscriptionCount: activeCount,
            categoryBreakdowns: breakdowns,
            monthlyTrends: trends,
            records: convertedRecords,
            upcoming30DaysBaseAmount: expiryMetrics.upcoming30DaysBaseAmount,
            overdueOrSoonCount: expiryMetrics.overdueOrSoonCount,
            expiryBuckets: expiryMetrics.expiryBuckets,
            upcomingRenewals: expiryMetrics.upcomingRenewals,
            oneTimeAssets: expiryMetrics.oneTimeAssets,
            apiBalanceItems: apiBalanceItems
        )
    }

    public func resolvedDateRange(referenceDate: Date = Date()) -> (Date, Date) {
        let endOfToday = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: referenceDate) ?? referenceDate
        switch selectedRangePreset {
        case .thisMonth:
            let start =
                calendar.date(from: calendar.dateComponents([.year, .month], from: referenceDate)) ?? referenceDate
            return (start, endOfToday)
        case .thisQuarter:
            let comps = calendar.dateComponents([.year, .month], from: referenceDate)
            let month = comps.month ?? 1
            let quarterStartMonth = ((month - 1) / 3) * 3 + 1
            let start =
                calendar.date(from: DateComponents(year: comps.year, month: quarterStartMonth, day: 1)) ?? referenceDate
            return (start, endOfToday)
        case .thisYear:
            let year = calendar.component(.year, from: referenceDate)
            let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? referenceDate
            return (start, endOfToday)
        case .allTime:
            return (Date(timeIntervalSince1970: 0), endOfToday)
        case .custom:
            let start = calendar.startOfDay(for: min(customStartDate, customEndDate))
            let end =
                calendar.date(bySettingHour: 23, minute: 59, second: 59, of: max(customStartDate, customEndDate))
                ?? customEndDate
            return (start, end)
        }
    }
}
