import Foundation

/// App Store 搜索结果模型（来自 iTunes Search API）
public struct AppStoreSearchItem: Codable, Hashable, Identifiable, Sendable {
    public var id: Int { trackId }
    public let trackId: Int
    public let trackName: String
    public let artworkUrl100: String?
    public let artworkUrl512: String?
    public let artistName: String?
    public let bundleId: String?

    public var bestArtworkURL: URL? {
        if let urlStr = artworkUrl512 ?? artworkUrl100 {
            return URL(string: urlStr)
        }
        return nil
    }

    public init(
        trackId: Int,
        trackName: String,
        artworkUrl100: String? = nil,
        artworkUrl512: String? = nil,
        artistName: String? = nil,
        bundleId: String? = nil
    ) {
        self.trackId = trackId
        self.trackName = trackName
        self.artworkUrl100 = artworkUrl100
        self.artworkUrl512 = artworkUrl512
        self.artistName = artistName
        self.bundleId = bundleId
    }
}

/// 自定义时间段消费统计聚合结果（按业务分类聚合）
public struct ExpenseAnalyticsSummary: Sendable, Equatable {
    public struct CategoryBreakdown: Identifiable, Sendable, Equatable {
        public var id: UUID { categoryId }
        public let categoryId: UUID
        public let categoryName: String
        public let totalBaseAmount: Decimal
        public let recordCount: Int
    }

    public struct MonthlyTrendPoint: Identifiable, Sendable, Equatable {
        public var id: String { "\(yearMonth)-\(categoryId.uuidString)" }
        public let yearMonth: String
        public let monthDate: Date
        public let categoryId: UUID
        public let categoryName: String
        public let totalBaseAmount: Decimal
    }

    public struct ExpiryBucket: Identifiable, Sendable, Equatable {
        public var id: String { label }
        public let label: String
        public let count: Int
        public let estimatedRenewalBaseAmount: Decimal
        public let colorToken: String

        public init(
            label: String,
            count: Int,
            estimatedRenewalBaseAmount: Decimal,
            colorToken: String
        ) {
            self.label = label
            self.count = count
            self.estimatedRenewalBaseAmount = estimatedRenewalBaseAmount
            self.colorToken = colorToken
        }
    }

    public struct UpcomingRenewalItem: Identifiable, Sendable, Equatable {
        public var id: UUID { subscriptionId }
        public let subscriptionId: UUID
        public let name: String
        public let categoryName: String
        public let categoryColorToken: String
        public let iconData: Data?
        public let nextBillingDate: Date
        public let daysRemaining: Int
        public let renewalPrice: Decimal
        public let currency: String
        public let renewalBaseAmount: Decimal
        public let isAutoRenew: Bool
        public let billingCycleType: BillingCycleType
        public let billingCycleDays: Int?
        public let status: SubscriptionStatus
        public let windowLabel: String

        public var cycleDisplayText: String {
            billingCycleType.formattedDisplayName(intervalCount: billingCycleDays)
        }

        public init(
            subscriptionId: UUID,
            name: String,
            categoryName: String,
            categoryColorToken: String,
            iconData: Data?,
            nextBillingDate: Date,
            daysRemaining: Int,
            renewalPrice: Decimal,
            currency: String,
            renewalBaseAmount: Decimal,
            isAutoRenew: Bool,
            billingCycleType: BillingCycleType,
            billingCycleDays: Int? = nil,
            status: SubscriptionStatus = .active,
            windowLabel: String? = nil
        ) {
            self.subscriptionId = subscriptionId
            self.name = name
            self.categoryName = categoryName
            self.categoryColorToken = categoryColorToken
            self.iconData = iconData
            self.nextBillingDate = nextBillingDate
            self.daysRemaining = daysRemaining
            self.renewalPrice = renewalPrice
            self.currency = currency
            self.renewalBaseAmount = renewalBaseAmount
            self.isAutoRenew = isAutoRenew
            self.billingCycleType = billingCycleType
            self.billingCycleDays = billingCycleDays
            self.status = status
            if let windowLabel {
                self.windowLabel = windowLabel
            } else if billingCycleType == .oneTime {
                self.windowLabel = "永久买断"
            } else if daysRemaining < 0 {
                self.windowLabel = "已逾期"
            } else if daysRemaining <= 7 {
                self.windowLabel = "7天内"
            } else if daysRemaining <= 30 {
                self.windowLabel = "8~30天"
            } else if daysRemaining <= 90 {
                self.windowLabel = "31~90天"
            } else {
                self.windowLabel = "90天+"
            }
        }
    }

    public struct APIBalanceOverviewItem: Identifiable, Sendable, Equatable {
        public var id: UUID { subscriptionId }
        public let subscriptionId: UUID
        public let name: String
        public let providerName: String
        public let iconData: Data?
        public let currency: String
        public let currentBalance: Decimal?
        public let balanceBaseAmount: Decimal?
        public let lowThreshold: Decimal?
        public let isLowBalance: Bool
        public let netRechargedBaseAmount: Decimal
        public let netRechargedOriginalAmount: Decimal
        public let topUpCount: Int

        public init(
            subscriptionId: UUID,
            name: String,
            providerName: String,
            iconData: Data?,
            currency: String,
            currentBalance: Decimal?,
            balanceBaseAmount: Decimal?,
            lowThreshold: Decimal?,
            isLowBalance: Bool,
            netRechargedBaseAmount: Decimal,
            netRechargedOriginalAmount: Decimal,
            topUpCount: Int
        ) {
            self.subscriptionId = subscriptionId
            self.name = name
            self.providerName = providerName
            self.iconData = iconData
            self.currency = currency
            self.currentBalance = currentBalance
            self.balanceBaseAmount = balanceBaseAmount
            self.lowThreshold = lowThreshold
            self.isLowBalance = isLowBalance
            self.netRechargedBaseAmount = netRechargedBaseAmount
            self.netRechargedOriginalAmount = netRechargedOriginalAmount
            self.topUpCount = topUpCount
        }
    }

    public let startDate: Date
    public let endDate: Date
    public let baseCurrency: String
    public let totalBaseAmount: Decimal
    public let dailyAverageBaseAmount: Decimal
    public let activeSubscriptionCount: Int
    public let categoryBreakdowns: [CategoryBreakdown]
    public let monthlyTrends: [MonthlyTrendPoint]
    public let records: [BillingRecord]
    public let upcoming30DaysBaseAmount: Decimal
    public let overdueOrSoonCount: Int
    public let expiryBuckets: [ExpiryBucket]
    public let upcomingRenewals: [UpcomingRenewalItem]
    public let oneTimeAssets: [UpcomingRenewalItem]
    public let apiBalanceItems: [APIBalanceOverviewItem]

    public var totalAPIBalanceBaseAmount: Decimal {
        apiBalanceItems.compactMap(\.balanceBaseAmount).reduce(0, +)
    }

    public init(
        startDate: Date,
        endDate: Date,
        baseCurrency: String,
        totalBaseAmount: Decimal,
        dailyAverageBaseAmount: Decimal,
        activeSubscriptionCount: Int,
        categoryBreakdowns: [CategoryBreakdown],
        monthlyTrends: [MonthlyTrendPoint],
        records: [BillingRecord],
        upcoming30DaysBaseAmount: Decimal = 0,
        overdueOrSoonCount: Int = 0,
        expiryBuckets: [ExpiryBucket] = [],
        upcomingRenewals: [UpcomingRenewalItem] = [],
        oneTimeAssets: [UpcomingRenewalItem] = [],
        apiBalanceItems: [APIBalanceOverviewItem] = []
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.baseCurrency = baseCurrency
        self.totalBaseAmount = totalBaseAmount
        self.dailyAverageBaseAmount = dailyAverageBaseAmount
        self.activeSubscriptionCount = activeSubscriptionCount
        self.categoryBreakdowns = categoryBreakdowns
        self.monthlyTrends = monthlyTrends
        self.records = records
        self.upcoming30DaysBaseAmount = upcoming30DaysBaseAmount
        self.overdueOrSoonCount = overdueOrSoonCount
        self.expiryBuckets = expiryBuckets
        self.upcomingRenewals = upcomingRenewals
        self.oneTimeAssets = oneTimeAssets
        self.apiBalanceItems = apiBalanceItems
    }
}
