import Foundation

/// 敏感字段（VPS 密码、激活码等）安全存取与生物识别鉴权协议
public protocol SecretStoreProtocol: Sendable {
    func saveSecret(_ value: String, forKey key: String) throws
    func loadSecret(forKey key: String) throws -> String?
    func deleteSecret(forKey key: String) throws
    func authenticateUser(reason: String) async -> Bool
}
