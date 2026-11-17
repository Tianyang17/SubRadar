import Foundation
import UserNotifications

/// macOS 原生本地通知调度服务
public final class LocalNotificationService: NotificationServiceProtocol, Sendable {
    private let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    private var canUseUserNotifications: Bool {
        Bundle.main.bundleIdentifier != nil
    }

    public func requestAuthorization() async -> Bool {
        guard canUseUserNotifications else { return false }
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    public func scheduleReminder(for item: SubscriptionItem) async {
        guard canUseUserNotifications else { return }
        let center = UNUserNotificationCenter.current()
        let identifier = notificationIdentifier(for: item.id)

        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        guard item.status == .active,
            item.billingCycleType != .oneTime,
            item.reminderDaysBefore >= 0,
            let triggerDate = computeTriggerDate(
                nextRenewal: item.nextRenewalDate, daysBefore: item.reminderDaysBefore),
            triggerDate > Date()
        else {
            return
        }

        let content = UNMutableNotificationContent()
        let symbol = CommonCurrency.symbol(for: item.currency)
        let priceStr = NSDecimalNumber(decimal: item.effectiveRenewalPrice).stringValue
        content.title = "订阅到期提醒：\(item.name)"
        if item.reminderDaysBefore == 0 {
            content.body = "今日即将到期/续费（\(symbol)\(priceStr)），请注意核对是否继续保留。"
        } else {
            content.body = "将在 \(item.reminderDaysBefore) 天后到期/续费（\(symbol)\(priceStr)），别忘防背刺检查。"
        }
        content.sound = .default

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        try? await center.add(request)
    }

    public func cancelReminder(for subscriptionId: UUID) async {
        guard canUseUserNotifications else { return }
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [notificationIdentifier(for: subscriptionId)])
    }

    public func syncAllReminders(for items: [SubscriptionItem]) async {
        guard canUseUserNotifications else { return }
        for item in items {
            await scheduleReminder(for: item)
        }
    }

    public func notifyLowBalance(for item: SubscriptionItem, currentBalance: Decimal, threshold: Decimal) async {
        guard canUseUserNotifications else { return }
        let content = UNMutableNotificationContent()
        let symbol = CommonCurrency.symbol(for: item.currency)
        let balStr = NSDecimalNumber(decimal: currentBalance).stringValue
        let thrStr = NSDecimalNumber(decimal: threshold).stringValue
        content.title = "API 余额低预警：\(item.name)"
        content.body = "当前剩余余额 \(symbol)\(balStr)，已低于预设阈值 \(symbol)\(thrStr)，请及时充值以免影响调用。"
        content.sound = .default

        let id = "subradar.lowbalance.\(item.id.uuidString)"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }

    public func sendTestNotification(title: String, body: String) async -> NotificationDeliveryReport {
        if canUseUserNotifications {
            let center = UNUserNotificationCenter.current()
            let granted = await requestAuthorization()
            let settings = await center.notificationSettings()
            let status = settings.authorizationStatus
            guard granted || status == .authorized || status == .provisional else {
                return NotificationDeliveryReport(
                    delivered: false,
                    channel: "UNUserNotificationCenter",
                    detail: "系统通知权限未开启，请在「系统设置 → 通知」中允许 SubRadar 发送通知。"
                )
            }

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: "subradar.test.\(UUID().uuidString)",
                content: content,
                trigger: nil
            )
            do {
                try await center.add(request)
                return NotificationDeliveryReport(
                    delivered: true,
                    channel: "SubRadar 系统通知",
                    detail: "已向 macOS 通知中心发布测试通知（若未弹窗请检查勿扰模式）。"
                )
            } catch {
                return NotificationDeliveryReport(
                    delivered: false,
                    channel: "SubRadar 系统通知",
                    detail: "发送系统通知失败，请检查「系统设置 -> 通知」中 SubRadar 的通知权限。"
                )
            }
        }

        return postSystemNotificationFallback(title: title, body: body)
    }

    private func postSystemNotificationFallback(title: String, body: String) -> NotificationDeliveryReport {
        let escapedTitle = escapeAppleScriptString(title)
        let escapedBody = escapeAppleScriptString(body)
        let script = "display notification \"\(escapedBody)\" with title \"\(escapedTitle)\""

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        let errorPipe = Pipe()
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                return NotificationDeliveryReport(
                    delivered: true,
                    channel: "SubRadar 系统通知",
                    detail: "已发布测试通知，若未弹出请检查系统通知权限或勿扰模式。"
                )
            }
            return NotificationDeliveryReport(
                delivered: false,
                channel: "SubRadar 系统通知",
                detail: "未能弹出系统通知，请检查「系统设置 -> 通知」权限设置。"
            )
        } catch {
            return NotificationDeliveryReport(
                delivered: false,
                channel: "SubRadar 系统通知",
                detail: "无法调用系统通知服务，请确认系统通知权限设置正常。"
            )
        }
    }

    private func escapeAppleScriptString(_ raw: String) -> String {
        raw.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: " ")
    }

    /// 供单元测试验证通知触发日期推算（默认在提前第 N 天上午 09:30 提醒）
    public func computeTriggerDate(nextRenewal: Date, daysBefore: Int) -> Date? {
        guard let targetDay = calendar.date(byAdding: .day, value: -daysBefore, to: nextRenewal) else {
            return nil
        }
        return calendar.date(bySettingHour: 9, minute: 30, second: 0, of: targetDay)
    }

    private func notificationIdentifier(for id: UUID) -> String {
        "subradar.reminder.\(id.uuidString)"
    }
}
