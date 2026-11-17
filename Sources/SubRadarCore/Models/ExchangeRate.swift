import Foundation

/// 按日期维度缓存的汇率条目（基准货币默认为 CNY）
public struct ExchangeRate: Codable, Hashable, Sendable {
    public var currencyCode: String
    /// yyyy-MM-dd 格式日期字符串，历史日期一旦拉取则永久有效
    public var rateDate: String
    /// 1 单位 currencyCode 可兑换多少基准货币 (例如 1 USD = 7.20 CNY)
    public var rateToBase: Double
    public var baseCurrency: String
    public var updatedAt: Date

    public init(
        currencyCode: String,
        rateDate: String,
        rateToBase: Double,
        baseCurrency: String = "CNY",
        updatedAt: Date = Date()
    ) {
        self.currencyCode = currencyCode.uppercased()
        self.rateDate = rateDate
        self.rateToBase = rateToBase
        self.baseCurrency = baseCurrency.uppercased()
        self.updatedAt = updatedAt
    }
}
