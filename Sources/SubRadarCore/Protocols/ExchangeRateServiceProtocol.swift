import Foundation

/// 汇率查询与按日期缓存服务协议
public protocol ExchangeRateServiceProtocol: Sendable {
    /// 获取指定币种在特定日期兑换为基准货币的汇率（自动优先查本地缓存，未命中则联网按需拉取并永久缓存）
    func rate(from currency: String, to baseCurrency: String, on date: Date) async -> Decimal

    /// 批量预热某段时间区间内的汇率（用于跨多年历史计费一次性加速查询）
    func prefetchRates(from currency: String, to baseCurrency: String, startDate: Date, endDate: Date) async
}
