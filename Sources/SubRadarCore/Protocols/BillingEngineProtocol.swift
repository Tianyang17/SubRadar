import Foundation

/// 历史推算预览结果
public struct HistoricalBillingPreview: Sendable, Equatable {
    public let cycleCount: Int
    public let totalAmount: Decimal
    public let billingDates: [Date]
    public let calculatedNextRenewalDate: Date?

    public init(
        cycleCount: Int,
        totalAmount: Decimal,
        billingDates: [Date],
        calculatedNextRenewalDate: Date?
    ) {
        self.cycleCount = cycleCount
        self.totalAmount = totalAmount
        self.billingDates = billingDates
        self.calculatedNextRenewalDate = calculatedNextRenewalDate
    }
}

/// 核心计费与周期推演引擎协议
public protocol BillingEngineProtocol: Sendable {
    /// 当用户录入跨多年订阅并勾选"历史计费"时，推算周期数与各期账单日期（支持首期购买价与后续续期价分离）
    func previewHistoricalBilling(
        startDate: Date,
        endDate: Date,
        cycleType: BillingCycleType,
        customDays: Int?,
        price: Decimal,
        renewalPrice: Decimal?
    ) -> HistoricalBillingPreview

    /// 根据预览生成标准扣费流水（支持传入日期对应的汇率转换闭包）
    func generateHistoricalRecords(
        for item: SubscriptionItem,
        endDate: Date,
        rateToBaseProvider: @Sendable (Date, String) async -> Decimal
    ) async -> [BillingRecord]

    /// 执行一次续订操作：返回推进下次续订日后的新订阅实体与新流水记录
    func processRenewal(
        for item: SubscriptionItem,
        actualPrice: Decimal?,
        renewedAt: Date,
        source: BillingRecordSource,
        rateToBase: Decimal
    ) -> (updatedItem: SubscriptionItem, record: BillingRecord)
}

extension BillingEngineProtocol {
    public func previewHistoricalBilling(
        startDate: Date,
        endDate: Date,
        cycleType: BillingCycleType,
        customDays: Int?,
        price: Decimal
    ) -> HistoricalBillingPreview {
        previewHistoricalBilling(
            startDate: startDate,
            endDate: endDate,
            cycleType: cycleType,
            customDays: customDays,
            price: price,
            renewalPrice: nil
        )
    }
}
