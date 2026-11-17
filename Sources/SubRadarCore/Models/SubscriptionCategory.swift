import Foundation

/// 分类语义色彩 Key（用于在 UI DesignSystem 映射为对应 RGB）
public enum CategoryColorKey: String, Codable, CaseIterable, Identifiable, Sendable {
    case purple
    case cyan
    case emerald
    case amber
    case indigo
    case coral
    case pink

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .purple: return "魅影紫"
        case .cyan: return "极光青"
        case .emerald: return "翡翠绿"
        case .amber: return "琥珀橙"
        case .indigo: return "雷达蓝"
        case .coral: return "珊瑚红"
        case .pink: return "绯樱粉"
        }
    }
}

/// 订阅业务分类模型（与字段模版正交解耦，支持用户完全自定义）
public struct SubscriptionCategory: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var iconSymbol: String
    public var colorKey: CategoryColorKey
    public var isBuiltin: Bool
    public var sortOrder: Int
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        iconSymbol: String = "tag.fill",
        colorKey: CategoryColorKey = .indigo,
        isBuiltin: Bool = false,
        sortOrder: Int = 100,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.iconSymbol = iconSymbol
        self.colorKey = colorKey
        self.isBuiltin = isBuiltin
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }

    public enum BuiltinID {
        public static let streaming = UUID(uuidString: "00000000-0000-0000-0002-000000000001")!
        public static let cloudInfra = UUID(uuidString: "00000000-0000-0000-0002-000000000002")!
        public static let domainNetwork = UUID(uuidString: "00000000-0000-0000-0002-000000000003")!
        public static let productivity = UUID(uuidString: "00000000-0000-0000-0002-000000000004")!
        public static let aiTools = UUID(uuidString: "00000000-0000-0000-0002-000000000005")!
        public static let cloudStorage = UUID(uuidString: "00000000-0000-0000-0002-000000000006")!
    }
}

/// 系统预置分类管理器
public enum CategoryPresetManager {
    public static let builtinCategories: [SubscriptionCategory] = [
        SubscriptionCategory(
            id: SubscriptionCategory.BuiltinID.streaming,
            name: "影音娱乐",
            iconSymbol: "play.tv.fill",
            colorKey: .purple,
            isBuiltin: true,
            sortOrder: 0
        ),
        SubscriptionCategory(
            id: SubscriptionCategory.BuiltinID.aiTools,
            name: "AI 与 API 服务",
            iconSymbol: "sparkles",
            colorKey: .indigo,
            isBuiltin: true,
            sortOrder: 1
        ),
        SubscriptionCategory(
            id: SubscriptionCategory.BuiltinID.cloudStorage,
            name: "网盘存储",
            iconSymbol: "icloud.fill",
            colorKey: .pink,
            isBuiltin: true,
            sortOrder: 2
        ),
        SubscriptionCategory(
            id: SubscriptionCategory.BuiltinID.cloudInfra,
            name: "云服务器",
            iconSymbol: "server.rack",
            colorKey: .cyan,
            isBuiltin: true,
            sortOrder: 3
        ),
        SubscriptionCategory(
            id: SubscriptionCategory.BuiltinID.domainNetwork,
            name: "域名服务",
            iconSymbol: "globe",
            colorKey: .emerald,
            isBuiltin: true,
            sortOrder: 4
        ),
        SubscriptionCategory(
            id: SubscriptionCategory.BuiltinID.productivity,
            name: "软件工具",
            iconSymbol: "key.fill",
            colorKey: .amber,
            isBuiltin: true,
            sortOrder: 5
        )
    ]

    public static func category(for id: UUID, from categories: [SubscriptionCategory]) -> SubscriptionCategory? {
        categories.first(where: { $0.id == id }) ?? builtinCategories.first(where: { $0.id == id })
    }

    public static func defaultCategoryId(forTemplateId templateId: UUID) -> UUID {
        switch templateId {
        case TemplateDefinition.BuiltinID.streaming:
            return SubscriptionCategory.BuiltinID.streaming
        case TemplateDefinition.BuiltinID.vps:
            return SubscriptionCategory.BuiltinID.cloudInfra
        case TemplateDefinition.BuiltinID.domain:
            return SubscriptionCategory.BuiltinID.domainNetwork
        case TemplateDefinition.BuiltinID.softwareLicense:
            return SubscriptionCategory.BuiltinID.productivity
        case TemplateDefinition.BuiltinID.aiMembership, TemplateDefinition.BuiltinID.apiBalance:
            return SubscriptionCategory.BuiltinID.aiTools
        default:
            return SubscriptionCategory.BuiltinID.productivity
        }
    }
}
