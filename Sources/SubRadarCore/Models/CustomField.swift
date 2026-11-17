import Foundation

/// 动态字段输入类型
public enum CustomFieldType: String, Codable, CaseIterable, Sendable, Identifiable {
    case text
    case number
    case secret
    case url
    case date

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .text: return "文本"
        case .number: return "数字"
        case .secret: return "密码 / 激活码"
        case .url: return "URL 链接"
        case .date: return "日期"
        }
    }

    public var isSensitiveByDefault: Bool {
        self == .secret
    }
}

/// 模版中的字段骨架定义
public struct FieldSchema: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var key: String
    public var label: String
    public var type: CustomFieldType
    public var placeholder: String
    public var isRequired: Bool
    public var defaultValue: String

    public init(
        id: UUID = UUID(),
        key: String,
        label: String,
        type: CustomFieldType,
        placeholder: String = "",
        isRequired: Bool = false,
        defaultValue: String = ""
    ) {
        self.id = id
        self.key = key
        self.label = label
        self.type = type
        self.placeholder = placeholder
        self.isRequired = isRequired
        self.defaultValue = defaultValue
    }

    private enum CodingKeys: String, CodingKey {
        case id, key, label, type, placeholder, isRequired, defaultValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        key = try container.decode(String.self, forKey: .key)
        label = try container.decode(String.self, forKey: .label)
        type = try container.decode(CustomFieldType.self, forKey: .type)
        placeholder = try container.decodeIfPresent(String.self, forKey: .placeholder) ?? ""
        isRequired = try container.decodeIfPresent(Bool.self, forKey: .isRequired) ?? false
        defaultValue = try container.decodeIfPresent(String.self, forKey: .defaultValue) ?? ""
    }

    /// 根据骨架实例化具体订阅条目上的字段
    public func instantiate(subscriptionId: UUID, sortOrder: Int) -> CustomField {
        CustomField(
            subscriptionId: subscriptionId,
            key: key,
            label: label,
            type: type,
            value: defaultValue,
            sortOrder: sortOrder
        )
    }
}

/// 订阅条目挂载的动态扩展字段值
public struct CustomField: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var subscriptionId: UUID
    public var key: String
    public var label: String
    public var type: CustomFieldType
    public var value: String
    public var sortOrder: Int

    public var isSensitive: Bool {
        type == .secret
    }

    public init(
        id: UUID = UUID(),
        subscriptionId: UUID,
        key: String,
        label: String,
        type: CustomFieldType,
        value: String = "",
        sortOrder: Int = 0
    ) {
        self.id = id
        self.subscriptionId = subscriptionId
        self.key = key
        self.label = label
        self.type = type
        self.value = value
        self.sortOrder = sortOrder
    }
}
