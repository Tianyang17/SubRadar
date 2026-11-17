import Foundation

/// 订阅模版定义（含系统内置模版与用户自定义模版）
public struct TemplateDefinition: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var iconSymbol: String
    public var isBuiltin: Bool
    public var defaultFields: [FieldSchema]
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        iconSymbol: String,
        isBuiltin: Bool = false,
        defaultFields: [FieldSchema] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.iconSymbol = iconSymbol
        self.isBuiltin = isBuiltin
        self.defaultFields = defaultFields
        self.createdAt = createdAt
    }

    public enum BuiltinID {
        public static let streaming = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        public static let vps = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        public static let domain = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
        public static let softwareLicense = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!
        public static let aiMembership = UUID(uuidString: "00000000-0000-0000-0000-000000000005")!
        public static let apiBalance = UUID(uuidString: "00000000-0000-0000-0000-000000000006")!
        public static let custom = UUID(uuidString: "00000000-0000-0000-0000-000000000007")!
    }
}
