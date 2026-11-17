import Foundation

public struct NotificationDeliveryReport: Equatable, Sendable {
    public let delivered: Bool
    public let channel: String
    public let detail: String

    public init(delivered: Bool, channel: String, detail: String) {
        self.delivered = delivered
        self.channel = channel
        self.detail = detail
    }
}

/// 到期前本地提醒服务协议
public protocol NotificationServiceProtocol: Sendable {
    func requestAuthorization() async -> Bool
    func scheduleReminder(for item: SubscriptionItem) async
    func cancelReminder(for subscriptionId: UUID) async
    func syncAllReminders(for items: [SubscriptionItem]) async
    func notifyLowBalance(for item: SubscriptionItem, currentBalance: Decimal, threshold: Decimal) async
    func sendTestNotification(title: String, body: String) async -> NotificationDeliveryReport
}
