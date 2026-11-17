import Foundation

/// Phase 7.8: 统一合并计费单位（天数 / 周数 / 月数 / 年数 / 一次性买断），与整数期数 N 组合支持多年/多月（如 每 3 年 / 每 4 个月）
public enum BillingCycleUnit: String, Codable, CaseIterable, Sendable, Identifiable {
    case day
    case week
    case month
    case year
    case oneTime = "one_time"

    public var id: String { rawValue }

    /// 下拉菜单与分段选择展示名
    public var selectionLabel: String {
        switch self {
        case .day: return "按天"
        case .week: return "按周"
        case .month: return "按月"
        case .year: return "按年"
        case .oneTime: return "买断"
        }
    }

    /// 搭配数量“每 N ___”使用的单位词
    public var intervalUnitLabel: String {
        switch self {
        case .day: return "天"
        case .week: return "周"
        case .month: return "月"
        case .year: return "年"
        case .oneTime: return "买断"
        }
    }

    /// 映射为持久化主周期枚举
    public var canonicalCycleType: BillingCycleType {
        switch self {
        case .day: return .customDays
        case .week: return .weekly
        case .month: return .monthly
        case .year: return .annually
        case .oneTime: return .oneTime
        }
    }
}

/// 付费周期类型（向后兼容历史 quarterly / semiannually 存储值）
public enum BillingCycleType: String, Codable, CaseIterable, Sendable, Identifiable {
    case weekly
    case monthly
    case quarterly
    case semiannually
    case annually
    case customDays = "custom_days"
    case oneTime = "one_time"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .weekly: return "按周"
        case .monthly: return "按月"
        case .quarterly: return "每 3 个月"
        case .semiannually: return "每 6 个月"
        case .annually: return "按年"
        case .customDays: return "按天"
        case .oneTime: return "买断"
        }
    }

    /// 归一化为统一的「计费单位 + 期数 N」（历史 quarterly->3个月，semiannually->6个月）
    public func normalizedUnitAndCount(intervalCount: Int? = nil) -> (unit: BillingCycleUnit, count: Int) {
        switch self {
        case .customDays:
            return (.day, max(1, intervalCount ?? 30))
        case .weekly:
            return (.week, max(1, intervalCount ?? 1))
        case .monthly:
            return (.month, max(1, intervalCount ?? 1))
        case .quarterly:
            return (.month, 3)
        case .semiannually:
            return (.month, 6)
        case .annually:
            return (.year, max(1, intervalCount ?? 1))
        case .oneTime:
            return (.oneTime, 1)
        }
    }

    /// 格式化展示多期周期名称（如 "按年" / "每 3 年" / "每 4 个月" / "按月" / "每 45 天"）
    public func formattedDisplayName(intervalCount: Int? = nil) -> String {
        let (unit, count) = normalizedUnitAndCount(intervalCount: intervalCount)
        switch unit {
        case .oneTime:
            return "买断"
        case .day:
            return "每 \(count) 天"
        case .week:
            return count == 1 ? "按周" : "每 \(count) 周"
        case .month:
            return count == 1 ? "按月" : "每 \(count) 个月"
        case .year:
            return count == 1 ? "按年" : "每 \(count) 年"
        }
    }

    /// 等效月度支出折算系数（多期订阅按期数摊销）
    public func monthlyEquivalenceFactor(intervalCount: Int? = nil) -> Decimal {
        let (unit, count) = normalizedUnitAndCount(intervalCount: intervalCount)
        switch unit {
        case .oneTime:
            return 0
        case .day:
            return Decimal(30) / Decimal(max(1, count))
        case .week:
            return Decimal(52) / Decimal(12 * max(1, count))
        case .month:
            return Decimal(1) / Decimal(max(1, count))
        case .year:
            return Decimal(1) / Decimal(12 * max(1, count))
        }
    }

    /// 每次续订推算时对应的日历单位及步长（customDays 与 oneTime 单独处理；支持每 N 天 / 周 / 月 / 年）
    public func nextDate(from date: Date, customDays: Int? = nil, calendar: Calendar = .current) -> Date? {
        let (unit, count) = normalizedUnitAndCount(intervalCount: customDays)
        switch unit {
        case .day:
            return calendar.date(byAdding: .day, value: count, to: date)
        case .week:
            return calendar.date(byAdding: .day, value: 7 * count, to: date)
        case .month:
            return calendar.date(byAdding: .month, value: count, to: date)
        case .year:
            return calendar.date(byAdding: .year, value: count, to: date)
        case .oneTime:
            return nil
        }
    }
}

/// 订阅运行状态
public enum SubscriptionStatus: String, Codable, CaseIterable, Sendable, Identifiable {
    case active
    case paused
    case cancelled
    case expired

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .active: return "运行中"
        case .paused: return "已暂停"
        case .cancelled: return "已退订"
        case .expired: return "已到期"
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        if let resolved = SubscriptionStatus(rawValue: raw) {
            self = resolved
        } else if raw == "pending_cancellation" {
            self = .active
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown SubscriptionStatus raw value: \(raw)"
            )
        }
    }
}

/// 常用货币配置
public enum CommonCurrency: String, Codable, CaseIterable, Sendable, Identifiable {
    case cny = "CNY"
    case usd = "USD"
    case eur = "EUR"
    case hkd = "HKD"
    case jpy = "JPY"
    case gbp = "GBP"

    public var id: String { rawValue }

    public var symbol: String {
        switch self {
        case .cny: return "¥"
        case .usd: return "$"
        case .eur: return "€"
        case .hkd: return "HK$"
        case .jpy: return "JP¥"
        case .gbp: return "£"
        }
    }

    public var displayName: String {
        switch self {
        case .cny: return "人民币 (CNY)"
        case .usd: return "美元 (USD)"
        case .eur: return "欧元 (EUR)"
        case .hkd: return "港元 (HKD)"
        case .jpy: return "日元 (JPY)"
        case .gbp: return "英镑 (GBP)"
        }
    }

    public static func symbol(for code: String) -> String {
        CommonCurrency(rawValue: code.uppercased())?.symbol ?? "\(code.uppercased()) "
    }
}
