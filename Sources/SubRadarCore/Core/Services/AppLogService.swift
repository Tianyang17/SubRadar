import Foundation

public enum AppLogLevel: String, Sendable {
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"
}

public enum AppLogCategory: String, Sendable {
    case balance = "Balance"
    case update = "Update"
    case app = "App"
}

public enum LogSanitizer {
    private static let bearerRegex = try? NSRegularExpression(
        pattern: "(?i)Bearer\\s+[A-Za-z0-9\\-_.~+/=]+"
    )
    private static let prefixedKeyRegex = try? NSRegularExpression(
        pattern: "(?i)\\b(sk|rk|pk)-[A-Za-z0-9_\\-]{6,}"
    )
    private static let querySecretRegex = try? NSRegularExpression(
        pattern: "(?i)(api_key|apikey|key|token|secret|password|auth)=([^&\\s]+)"
    )

    public static func sanitize(_ raw: String) -> String {
        var result =
            raw
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")

        if let bearerRegex {
            let range = NSRange(result.startIndex..., in: result)
            result = bearerRegex.stringByReplacingMatches(
                in: result,
                options: [],
                range: range,
                withTemplate: "Bearer ***"
            )
        }
        if let prefixedKeyRegex {
            let range = NSRange(result.startIndex..., in: result)
            result = prefixedKeyRegex.stringByReplacingMatches(
                in: result,
                options: [],
                range: range,
                withTemplate: "$1-***"
            )
        }
        if let querySecretRegex {
            let range = NSRange(result.startIndex..., in: result)
            result = querySecretRegex.stringByReplacingMatches(
                in: result,
                options: [],
                range: range,
                withTemplate: "$1=***"
            )
        }
        return result
    }

    public static func sanitizeURL(_ url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return sanitize(url.absoluteString)
        }
        components.user = nil
        components.password = nil
        if let items = components.queryItems, !items.isEmpty {
            let sensitiveKeys: Set<String> = [
                "api_key", "apikey", "key", "token", "secret", "password", "auth"
            ]
            components.queryItems = items.map { item in
                if sensitiveKeys.contains(item.name.lowercased()) {
                    return URLQueryItem(name: item.name, value: "***")
                }
                return item
            }
        }
        return components.string ?? sanitize(url.absoluteString)
    }
}

public actor AppLogService {
    public static let shared = AppLogService()

    public nonisolated let directoryURL: URL
    private let retentionDays: Int
    private let nowProvider: @Sendable () -> Date
    private var lastPrunedDayStamp: String?

    public static func defaultLogDirectoryURL() -> URL {
        let baseLibrary =
            FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(
                "Library",
                isDirectory: true
            )
        return
            baseLibrary
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("SubRadar", isDirectory: true)
    }

    public init(
        directoryURL: URL = AppLogService.defaultLogDirectoryURL(),
        retentionDays: Int = 7,
        nowProvider: @escaping @Sendable () -> Date = Date.init
    ) {
        self.directoryURL = directoryURL
        self.retentionDays = max(1, retentionDays)
        self.nowProvider = nowProvider
    }

    @discardableResult
    public func ensureDirectoryExists() throws -> URL {
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        return directoryURL
    }

    public func logFileURL(for date: Date? = nil) -> URL {
        let targetDate = date ?? nowProvider()
        let stamp = Self.dayStamp(from: targetDate)
        return directoryURL.appendingPathComponent("subradar-\(stamp).log")
    }

    public func log(_ level: AppLogLevel, category: AppLogCategory, _ message: String) {
        let now = nowProvider()
        let dayStamp = Self.dayStamp(from: now)
        let timestamp = Self.timestampString(from: now)
        let cleanMessage = LogSanitizer.sanitize(message)
        let line = "[\(timestamp)] [\(level.rawValue)] [\(category.rawValue)] \(cleanMessage)\n"

        do {
            _ = try ensureDirectoryExists()
            let fileURL = directoryURL.appendingPathComponent("subradar-\(dayStamp).log")
            let data = Data(line.utf8)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let handle = try FileHandle(forWritingTo: fileURL)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
            } else {
                try data.write(to: fileURL, options: .atomic)
            }
            if lastPrunedDayStamp != dayStamp {
                lastPrunedDayStamp = dayStamp
                pruneExpiredFiles(referenceDate: now)
            }
        } catch {
            // 磁盘日志写入失败不应中断主业务流程
        }
    }

    private func pruneExpiredFiles(referenceDate: Date) {
        guard
            let files = try? FileManager.default.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
        else {
            return
        }
        let cutoffDate =
            Calendar(identifier: .gregorian).date(
                byAdding: .day,
                value: -(retentionDays - 1),
                to: Calendar(identifier: .gregorian).startOfDay(for: referenceDate)
            ) ?? referenceDate

        for fileURL in files where fileURL.pathExtension == "log" {
            let name = fileURL.deletingPathExtension().lastPathComponent
            guard name.hasPrefix("subradar-") else { continue }
            let datePart = String(name.dropFirst("subradar-".count))
            guard let fileDate = Self.parseDayStamp(datePart), fileDate < cutoffDate else {
                continue
            }
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    private static func dayStamp(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func parseDayStamp(_ raw: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: raw)
    }

    private static func timestampString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
}
