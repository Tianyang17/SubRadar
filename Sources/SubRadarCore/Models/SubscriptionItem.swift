import Foundation

/// 订阅条目数据校验错误
public enum SubscriptionValidationError: LocalizedError, Sendable, Equatable {
    case emptyName
    case negativePrice
    case invalidDateRange
    case invalidCustomCycleDays

    public var errorDescription: String? {
        switch self {
        case .emptyName:
            return "订阅名称不能为空"
        case .negativePrice:
            return "订阅金额不能为负数"
        case .invalidDateRange:
            return "下次续订日期不能早于订阅开始日期"
        case .invalidCustomCycleDays:
            return "自定义周期天数必须大于 0"
        }
    }
}

/// 订阅续订方式
public enum RenewalMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case automatic
    case manual
    case doNotRenew
    case custom

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .automatic: return "自动续费"
        case .manual: return "手动续费"
        case .doNotRenew: return "不再续费"
        case .custom: return "自定义"
        }
    }
}

/// 核心订阅与数字资产实体
public struct SubscriptionItem: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    /// 所属业务分类 ID（用于侧边栏归类与统计聚合，可自定义）
    public var categoryId: UUID
    /// 表单扩展字段模版 ID（决定专属字段结构）
    public var templateId: UUID
    public var iconData: Data?
    /// 首期购买价格（买断制下即买断价格）
    public var price: Decimal
    /// 后续续期价格（非买断制下有效；若为 nil 则默认与购买价格一致）
    public var renewalPrice: Decimal?
    public var currency: String
    public var billingCycleType: BillingCycleType
    public var billingCycleDays: Int?
    public var startDate: Date
    public var nextRenewalDate: Date
    public var autoRenew: Bool
    public var renewalMode: RenewalMode
    public var customRenewalNote: String
    public var status: SubscriptionStatus
    /// 提前提醒天数：-1 表示不提醒，0 表示到期当天
    public var reminderDaysBefore: Int
    public var notes: String
    public var customFields: [CustomField]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        categoryId: UUID? = nil,
        templateId: UUID,
        iconData: Data? = nil,
        price: Decimal,
        renewalPrice: Decimal? = nil,
        currency: String = "CNY",
        billingCycleType: BillingCycleType = .annually,
        billingCycleDays: Int? = nil,
        startDate: Date = Date(),
        nextRenewalDate: Date,
        autoRenew: Bool = true,
        renewalMode: RenewalMode? = nil,
        customRenewalNote: String = "",
        status: SubscriptionStatus = .active,
        reminderDaysBefore: Int = 3,
        notes: String = "",
        customFields: [CustomField] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        let resolvedMode = renewalMode ?? (autoRenew ? .automatic : .manual)
        self.id = id
        self.name = name
        self.categoryId = categoryId ?? CategoryPresetManager.defaultCategoryId(forTemplateId: templateId)
        self.templateId = templateId
        self.iconData = iconData
        self.price = price
        self.renewalPrice = billingCycleType == .oneTime ? nil : renewalPrice
        self.currency = currency.uppercased()
        self.billingCycleType = billingCycleType
        self.billingCycleDays = billingCycleDays
        self.startDate = startDate
        self.nextRenewalDate = nextRenewalDate
        self.renewalMode = resolvedMode
        self.customRenewalNote = customRenewalNote
        self.autoRenew = (resolvedMode == .automatic)
        self.status = status
        self.reminderDaysBefore = reminderDaysBefore
        self.notes = notes
        self.customFields = customFields
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let autoRenewDecoded = try c.decodeIfPresent(Bool.self, forKey: .autoRenew) ?? true
        let modeDecoded =
            try c.decodeIfPresent(RenewalMode.self, forKey: .renewalMode)
            ?? (autoRenewDecoded ? .automatic : .manual)
        let cycleDecoded = try c.decode(BillingCycleType.self, forKey: .billingCycleType)
        let renewalPriceDecoded = try c.decodeIfPresent(Decimal.self, forKey: .renewalPrice)

        self.id = try c.decode(UUID.self, forKey: .id)
        self.name = try c.decode(String.self, forKey: .name)
        self.categoryId = try c.decode(UUID.self, forKey: .categoryId)
        self.templateId = try c.decode(UUID.self, forKey: .templateId)
        self.iconData = try c.decodeIfPresent(Data.self, forKey: .iconData)
        self.price = try c.decode(Decimal.self, forKey: .price)
        self.renewalPrice = cycleDecoded == .oneTime ? nil : renewalPriceDecoded
        self.currency = try c.decode(String.self, forKey: .currency).uppercased()
        self.billingCycleType = cycleDecoded
        self.billingCycleDays = try c.decodeIfPresent(Int.self, forKey: .billingCycleDays)
        self.startDate = try c.decode(Date.self, forKey: .startDate)
        self.nextRenewalDate = try c.decode(Date.self, forKey: .nextRenewalDate)
        self.renewalMode = modeDecoded
        self.customRenewalNote = try c.decodeIfPresent(String.self, forKey: .customRenewalNote) ?? ""
        self.autoRenew = (modeDecoded == .automatic)
        self.status = try c.decode(SubscriptionStatus.self, forKey: .status)
        self.reminderDaysBefore = try c.decodeIfPresent(Int.self, forKey: .reminderDaysBefore) ?? 3
        self.notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        self.customFields = try c.decodeIfPresent([CustomField].self, forKey: .customFields) ?? []
        self.createdAt = try c.decode(Date.self, forKey: .createdAt)
        self.updatedAt = try c.decode(Date.self, forKey: .updatedAt)
    }

    public var renewalModeDisplayText: String {
        switch renewalMode {
        case .automatic, .manual, .doNotRenew:
            return renewalMode.displayName
        case .custom:
            let trimmed = customRenewalNote.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? RenewalMode.custom.displayName : trimmed
        }
    }

    /// 有效续期价格（买断制返回购买/买断价；其余周期优先使用独立设置的续期价，否则回退购买价）
    public var effectiveRenewalPrice: Decimal {
        billingCycleType == .oneTime ? price : (renewalPrice ?? price)
    }

    /// 归一化后的计费单位与期数
    public var billingCycleUnitAndCount: (unit: BillingCycleUnit, count: Int) {
        billingCycleType.normalizedUnitAndCount(intervalCount: billingCycleDays)
    }

    /// 统一展示的付费周期描述（如 "按月"、"每 4 个月"、"每 3 年"、"买断"）
    public var cycleDisplayName: String {
        billingCycleType.formattedDisplayName(intervalCount: billingCycleDays)
    }

    /// 业务合法性校验（对应 Pydantic Schema Validator）
    public func validate() throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SubscriptionValidationError.emptyName
        }
        guard price >= 0, (renewalPrice ?? 0) >= 0 else {
            throw SubscriptionValidationError.negativePrice
        }
        if billingCycleType != .oneTime && nextRenewalDate < startDate {
            throw SubscriptionValidationError.invalidDateRange
        }
        if billingCycleType == .customDays && (billingCycleDays ?? 0) <= 0 {
            throw SubscriptionValidationError.invalidCustomCycleDays
        }
        if let days = billingCycleDays, billingCycleType != .oneTime && days <= 0 {
            throw SubscriptionValidationError.invalidCustomCycleDays
        }
    }

    /// 距离下次续订剩余天数（按日历天数计算，负值表示已逾期）
    public func daysUntilRenewal(referenceDate: Date = Date(), calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: referenceDate)
        let target = calendar.startOfDay(for: nextRenewalDate)
        return calendar.dateComponents([.day], from: start, to: target).day ?? 0
    }

    /// 获取指定 key 的动态字段值
    public func fieldValue(forKey key: String) -> String? {
        customFields.first(where: { $0.key == key })?.value
    }

    /// 若包含 IPv4/SSH 字段，构造标准 ssh:// 协议链接与终端命令
    public var sshCommand: String? {
        guard let ipv4 = fieldValue(forKey: "ipv4")?.trimmingCharacters(in: .whitespacesAndNewlines),
            !ipv4.isEmpty
        else {
            return nil
        }
        let user = fieldValue(forKey: "ssh_user")?.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveUser = (user?.isEmpty == false) ? user! : "root"
        let port = fieldValue(forKey: "ssh_port")?.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectivePort = (port?.isEmpty == false) ? port! : "22"
        if effectivePort == "22" {
            return "ssh \(effectiveUser)@\(ipv4)"
        }
        return "ssh \(effectiveUser)@\(ipv4) -p \(effectivePort)"
    }

    public var sshURL: URL? {
        guard let ipv4 = fieldValue(forKey: "ipv4")?.trimmingCharacters(in: .whitespacesAndNewlines),
            !ipv4.isEmpty
        else {
            return nil
        }
        let user = fieldValue(forKey: "ssh_user")?.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveUser = (user?.isEmpty == false) ? user! : "root"
        let port = fieldValue(forKey: "ssh_port")?.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectivePort = (port?.isEmpty == false) ? port! : "22"
        return URL(string: "ssh://\(effectiveUser)@\(ipv4):\(effectivePort)")
    }

    public static let reminderDayOptions: [Int] = [-1, 0, 1, 3, 7, 14, 30]

    public static func reminderOptionLabel(_ days: Int) -> String {
        switch days {
        case -1: return "不提醒"
        case 0: return "到期当天"
        default: return "提前 \(days) 天"
        }
    }
}
