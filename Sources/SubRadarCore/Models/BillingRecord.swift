import Foundation

/// 账单流水记账方向
public enum BillingRecordKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case charge = "charge"
    case topUp = "top_up"
    case refund = "refund"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .charge: return "扣费 / 购买"
        case .topUp: return "充值"
        case .refund: return "退款"
        }
    }

    public var signMultiplier: Decimal {
        switch self {
        case .charge, .topUp: return 1
        case .refund: return -1
        }
    }
}

/// 扣费流水来源
public enum BillingRecordSource: String, Codable, CaseIterable, Sendable {
    case historicalAuto = "historical_auto"
    case manualRenew = "manual_renew"
    case autoRenew = "auto_renew"
    case initialPurchase = "initial_purchase"
    case manualLedger = "manual_ledger"

    public var displayName: String {
        switch self {
        case .historicalAuto: return "历史推算生成"
        case .manualRenew: return "手动确认续订"
        case .autoRenew: return "周期自动续订"
        case .initialPurchase: return "首次购买"
        case .manualLedger: return "手动记账"
        }
    }
}

/// 每次计费 / 续订 / 充值 / 退款产生的流水记录
public struct BillingRecord: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var subscriptionId: UUID
    public var amount: Decimal
    public var currency: String
    /// 按当时汇率折算后的基准货币金额（加速跨时间段聚合查询）
    public var baseCurrencyAmount: Decimal
    public var billedAt: Date
    public var source: BillingRecordSource
    public var kind: BillingRecordKind
    public var note: String

    public var signedAmount: Decimal {
        amount * kind.signMultiplier
    }

    public var signedBaseCurrencyAmount: Decimal {
        baseCurrencyAmount * kind.signMultiplier
    }

    public init(
        id: UUID = UUID(),
        subscriptionId: UUID,
        amount: Decimal,
        currency: String,
        baseCurrencyAmount: Decimal,
        billedAt: Date,
        source: BillingRecordSource,
        kind: BillingRecordKind = .charge,
        note: String = ""
    ) {
        self.id = id
        self.subscriptionId = subscriptionId
        self.amount = amount
        self.currency = currency.uppercased()
        self.baseCurrencyAmount = baseCurrencyAmount
        self.billedAt = billedAt
        self.source = source
        self.kind = kind
        self.note = note
    }
}

/// 单条订阅跨币种流水汇总（折算至订阅主币种 + 原币分组摘要）
public struct SubscriptionSpendSummary: Hashable, Sendable {
    public let convertedTotal: Decimal
    public let hasForeignCurrencyRecords: Bool
    public let originalCurrencySummaryText: String

    public init(
        convertedTotal: Decimal,
        hasForeignCurrencyRecords: Bool,
        originalCurrencySummaryText: String
    ) {
        self.convertedTotal = convertedTotal
        self.hasForeignCurrencyRecords = hasForeignCurrencyRecords
        self.originalCurrencySummaryText = originalCurrencySummaryText
    }
}
