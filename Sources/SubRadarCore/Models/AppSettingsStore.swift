import Foundation
import Observation

/// 应用外观主题模式
public enum ThemeMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色主题"
        case .dark: return "暗黑主题"
        }
    }

    public var iconSymbol: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.stars.fill"
        }
    }
}

/// 应用偏好设置持久化存储
@Observable
@MainActor
public final class AppSettingsStore {
    private enum Keys {
        static let themeMode = "subradar.settings.themeMode"
        static let baseCurrency = "subradar.settings.baseCurrency"
        static let defaultReminderDays = "subradar.settings.defaultReminderDays"
        static let keepRunningInMenuBar = "subradar.settings.keepRunningInMenuBar"
        static let hideDockWhenWindowClosed = "subradar.settings.hideDockWhenWindowClosed"
        static let autoCheckForUpdates = "subradar.settings.autoCheckForUpdates"
        static let skippedUpdateVersion = "subradar.settings.skippedUpdateVersion"
        static let customUpdateFeedURL = "subradar.settings.customUpdateFeedURL"
    }

    private let userDefaults: UserDefaults

    public var themeMode: ThemeMode {
        didSet { userDefaults.set(themeMode.rawValue, forKey: Keys.themeMode) }
    }

    public var baseCurrency: String {
        didSet { userDefaults.set(baseCurrency.uppercased(), forKey: Keys.baseCurrency) }
    }

    public var defaultReminderDays: Int {
        didSet { userDefaults.set(defaultReminderDays, forKey: Keys.defaultReminderDays) }
    }

    public var keepRunningInMenuBar: Bool {
        didSet { userDefaults.set(keepRunningInMenuBar, forKey: Keys.keepRunningInMenuBar) }
    }

    public var hideDockWhenWindowClosed: Bool {
        didSet { userDefaults.set(hideDockWhenWindowClosed, forKey: Keys.hideDockWhenWindowClosed) }
    }

    public var autoCheckForUpdates: Bool {
        didSet { userDefaults.set(autoCheckForUpdates, forKey: Keys.autoCheckForUpdates) }
    }

    public var skippedUpdateVersion: String {
        didSet { userDefaults.set(skippedUpdateVersion, forKey: Keys.skippedUpdateVersion) }
    }

    public var customUpdateFeedURL: String {
        didSet { userDefaults.set(customUpdateFeedURL, forKey: Keys.customUpdateFeedURL) }
    }

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        if let rawTheme = userDefaults.string(forKey: Keys.themeMode),
            let parsedTheme = ThemeMode(rawValue: rawTheme)
        {
            self.themeMode = parsedTheme
        } else {
            self.themeMode = .system
        }

        let storedCurrency = (userDefaults.string(forKey: Keys.baseCurrency) ?? "CNY").uppercased()
        self.baseCurrency = CommonCurrency(rawValue: storedCurrency)?.rawValue ?? "CNY"

        if userDefaults.object(forKey: Keys.defaultReminderDays) != nil {
            self.defaultReminderDays = userDefaults.integer(forKey: Keys.defaultReminderDays)
        } else {
            self.defaultReminderDays = 3
        }

        if userDefaults.object(forKey: Keys.keepRunningInMenuBar) != nil {
            self.keepRunningInMenuBar = userDefaults.bool(forKey: Keys.keepRunningInMenuBar)
        } else {
            self.keepRunningInMenuBar = true
        }

        if userDefaults.object(forKey: Keys.hideDockWhenWindowClosed) != nil {
            self.hideDockWhenWindowClosed = userDefaults.bool(forKey: Keys.hideDockWhenWindowClosed)
        } else {
            self.hideDockWhenWindowClosed = false
        }

        if userDefaults.object(forKey: Keys.autoCheckForUpdates) != nil {
            self.autoCheckForUpdates = userDefaults.bool(forKey: Keys.autoCheckForUpdates)
        } else {
            self.autoCheckForUpdates = true
        }

        self.skippedUpdateVersion = userDefaults.string(forKey: Keys.skippedUpdateVersion) ?? ""
        self.customUpdateFeedURL = userDefaults.string(forKey: Keys.customUpdateFeedURL) ?? ""
    }

    public func cycleTheme() {
        switch themeMode {
        case .system: themeMode = .dark
        case .dark: themeMode = .light
        case .light: themeMode = .system
        }
    }
}
