import Foundation

/// SQLite 参数绑定值类型
public enum SQLiteValue: Sendable {
    case text(String)
    case integer(Int64)
    case double(Double)
    case blob(Data)
    case null
}

/// SQLite 操作错误
public enum SQLiteError: LocalizedError, Sendable {
    case openFailed(message: String)
    case prepareFailed(sql: String, message: String)
    case stepFailed(sql: String, message: String)
    case invalidColumnType

    public var errorDescription: String? {
        switch self {
        case .openFailed:
            return "本地数据库暂时无法打开，请检查应用数据目录权限后重试。"
        case .prepareFailed, .stepFailed:
            return "本地数据读写未成功，请重试；若问题持续，建议导出备份后重启应用。"
        case .invalidColumnType:
            return "读取本地数据格式时出现异常，请检查数据完整性。"
        }
    }
}

/// 单行查询结果视图
public struct SQLiteRow: Sendable {
    private let columns: [String: SQLiteValue]

    public init(columns: [String: SQLiteValue]) {
        self.columns = columns
    }

    public func string(_ name: String) -> String? {
        guard case .text(let value)? = columns[name] else { return nil }
        return value
    }

    public func int64(_ name: String) -> Int64? {
        guard case .integer(let value)? = columns[name] else { return nil }
        return value
    }

    public func int(_ name: String) -> Int? {
        int64(name).map(Int.init)
    }

    public func bool(_ name: String) -> Bool {
        (int64(name) ?? 0) != 0
    }

    public func double(_ name: String) -> Double? {
        switch columns[name] {
        case .double(let value):
            return value
        case .integer(let value):
            return Double(value)
        default:
            return nil
        }
    }

    public func decimal(_ name: String) -> Decimal? {
        if let str = string(name) {
            return Decimal(string: str)
        }
        if let dbl = double(name) {
            return Decimal(dbl)
        }
        return nil
    }

    public func data(_ name: String) -> Data? {
        guard case .blob(let value)? = columns[name] else { return nil }
        return value
    }

    public func date(_ name: String) -> Date? {
        guard let timestamp = double(name) else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }
}
