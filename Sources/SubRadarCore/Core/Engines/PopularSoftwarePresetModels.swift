import Foundation

/// Phase 7.9: 预置软件与服务六大清晰分类分组
public enum PopularSoftwareGroup: String, CaseIterable, Identifiable, Hashable, Sendable {
    case aiTools = "AI 与编程"
    case aiApiBalance = "AI API 余额"
    case productivity = "效率与办公"
    case entertainment = "影音娱乐"
    case cloudStorage = "网盘与存储"
    case infrastructure = "主机与域名"

    public var id: String { rawValue }

    public var symbolName: String {
        switch self {
        case .aiTools: return "sparkles"
        case .aiApiBalance: return "gauge.with.dots.needle.33percent"
        case .productivity: return "bolt.fill"
        case .entertainment: return "play.tv.fill"
        case .cloudStorage: return "icloud.fill"
        case .infrastructure: return "server.rack"
        }
    }
}

/// 国内外常用软件 / 会员 / AI 账号 / API 余额预设条目
public struct PopularSoftwarePreset: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let aliases: [String]
    public let group: PopularSoftwareGroup
    public let monogram: String
    public let accentHex: String
    public let symbolName: String
    public let websiteDomain: String
    public let suggestedCategoryId: UUID
    public let suggestedTemplateId: UUID
    public let defaultBillingCycle: BillingCycleType
    public let defaultPrice: String
    public let defaultCurrency: String
    public let presetFieldValues: [String: String]

    public init(
        id: String,
        name: String,
        aliases: [String] = [],
        group: PopularSoftwareGroup? = nil,
        monogram: String,
        accentHex: String,
        symbolName: String,
        websiteDomain: String,
        suggestedCategoryId: UUID,
        suggestedTemplateId: UUID,
        defaultBillingCycle: BillingCycleType,
        defaultPrice: String = "",
        defaultCurrency: String = "CNY",
        presetFieldValues: [String: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.aliases = aliases
        self.group =
            group
            ?? Self.inferGroup(
                id: id,
                templateId: suggestedTemplateId,
                categoryId: suggestedCategoryId
            )
        self.monogram = monogram
        self.accentHex = accentHex
        self.symbolName = symbolName
        self.websiteDomain = websiteDomain
        self.suggestedCategoryId = suggestedCategoryId
        self.suggestedTemplateId = suggestedTemplateId
        self.defaultBillingCycle = defaultBillingCycle
        self.defaultPrice = defaultPrice
        self.defaultCurrency = defaultCurrency
        self.presetFieldValues = presetFieldValues
    }

    private static func inferGroup(
        id: String,
        templateId: UUID,
        categoryId: UUID
    ) -> PopularSoftwareGroup {
        if templateId == TemplateDefinition.BuiltinID.apiBalance {
            return .aiApiBalance
        }
        switch id {
        case "chatgpt-plus", "claude-pro", "gemini-advanced", "github-copilot", "cursor-pro", "jetbrains":
            return .aiTools
        case "baidu-netdisk", "aliyun-drive", "quark-drive", "icloud-plus", "oppo-cloud":
            return .cloudStorage
        case "dedirock", "spaceship", "xiaotu-cloud", "yecaoyun", "cloudflare", "namecheap":
            return .infrastructure
        case "qq-music", "netease-music", "bilibili-vip", "iqiyi-vip", "mango-tv", "youku", "spotify", "netflix",
            "youtube-premium":
            return .entertainment
        default:
            if templateId == TemplateDefinition.BuiltinID.aiMembership {
                return .aiTools
            }
            if templateId == TemplateDefinition.BuiltinID.vps || templateId == TemplateDefinition.BuiltinID.domain {
                return .infrastructure
            }
            if categoryId == SubscriptionCategory.BuiltinID.streaming {
                return .entertainment
            }
            return .productivity
        }
    }
}
