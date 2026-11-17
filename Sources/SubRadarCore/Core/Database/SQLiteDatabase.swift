import Foundation
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

private final class SQLiteHandleBox: @unchecked Sendable {
    let pointer: OpaquePointer
    init(pointer: OpaquePointer) {
        self.pointer = pointer
    }
    deinit {
        sqlite3_close_v2(pointer)
    }
}

/// 线程安全的原生 SQLite3 Swift 6 Actor 封装
public actor SQLiteDatabase {
    private let handleBox: SQLiteHandleBox
    public let path: String

    public init(path: String, onOpen: (@Sendable (SQLiteConnection) throws -> Void)? = nil) throws {
        self.path = path
        if path != ":memory:" {
            let url = URL(fileURLWithPath: path)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        }

        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(path, &handle, flags, nil) != SQLITE_OK {
            let errMsg = handle.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "Unknown error"
            sqlite3_close(handle)
            throw SQLiteError.openFailed(message: errMsg)
        }
        guard let openedHandle = handle else {
            throw SQLiteError.openFailed(message: "Null sqlite handle")
        }

        let box = SQLiteHandleBox(pointer: openedHandle)
        let conn = SQLiteConnection(db: openedHandle)
        try conn.execute("PRAGMA foreign_keys = ON;")
        if path != ":memory:" {
            try conn.execute("PRAGMA journal_mode = WAL;")
        }
        try onOpen?(conn)
        self.handleBox = box
    }

    /// 获取默认数据库沙盒路径（支持通过 `SUBRADAR_DB_PATH` 环境变量隔离切换演示库）
    public static func defaultDatabaseURL(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> URL {
        if let rawOverride = environment["SUBRADAR_DB_PATH"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !rawOverride.isEmpty
        {
            let overrideURL = URL(fileURLWithPath: rawOverride)
            try FileManager.default.createDirectory(
                at: overrideURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            return overrideURL
        }
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let folder = appSupport.appendingPathComponent("SubRadar", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("subradar.sqlite")
    }

    /// 执行非查询 SQL（INSERT / UPDATE / DELETE / DDL）
    public func execute(_ sql: String, bindings: [SQLiteValue] = []) throws {
        try executeSync(sql, bindings: bindings)
    }

    /// 执行查询并返回行集
    public func query(_ sql: String, bindings: [SQLiteValue] = []) throws -> [SQLiteRow] {
        try querySync(sql, bindings: bindings)
    }

    /// 在事务中原子化执行多步操作（失败自动回滚）
    public func inTransaction<T>(_ block: @Sendable () throws -> T) throws -> T {
        try executeSync("BEGIN IMMEDIATE TRANSACTION;")
        do {
            let result = try block()
            try executeSync("COMMIT TRANSACTION;")
            return result
        } catch {
            try? executeSync("ROLLBACK TRANSACTION;")
            throw error
        }
    }

    /// 直接通过回调进行批量事务操作（允许同步调用内部 execute/query）
    public func performTransaction<T: Sendable>(_ block: @Sendable (SQLiteConnection) throws -> T) throws -> T {
        try executeSync("BEGIN IMMEDIATE TRANSACTION;")
        let connection = SQLiteConnection(db: handleBox.pointer)
        do {
            let result = try block(connection)
            try executeSync("COMMIT TRANSACTION;")
            return result
        } catch {
            try? executeSync("ROLLBACK TRANSACTION;")
            throw error
        }
    }

    public func userVersion() throws -> Int {
        let rows = try querySync("PRAGMA user_version;")
        return rows.first?.int("user_version") ?? 0
    }

    public func setUserVersion(_ version: Int) throws {
        try executeSync("PRAGMA user_version = \(version);")
    }

    // MARK: - Private Sync Helpers

    private func executeSync(_ sql: String, bindings: [SQLiteValue] = []) throws {
        try SQLiteConnection(db: handleBox.pointer).execute(sql, bindings: bindings)
    }

    private func querySync(_ sql: String, bindings: [SQLiteValue] = []) throws -> [SQLiteRow] {
        try SQLiteConnection(db: handleBox.pointer).query(sql, bindings: bindings)
    }
}

/// 在已加锁的 actor 事务内部或初始化握手期间使用的同步连接句柄
public struct SQLiteConnection: @unchecked Sendable {
    private let db: OpaquePointer

    fileprivate init(db: OpaquePointer) {
        self.db = db
    }

    public func userVersion() throws -> Int {
        let rows = try query("PRAGMA user_version;")
        return rows.first?.int("user_version") ?? 0
    }

    public func inTransaction<T>(_ block: (SQLiteConnection) throws -> T) throws -> T {
        try execute("BEGIN IMMEDIATE TRANSACTION;")
        do {
            let result = try block(self)
            try execute("COMMIT TRANSACTION;")
            return result
        } catch {
            try? execute("ROLLBACK TRANSACTION;")
            throw error
        }
    }

    public func execute(_ sql: String, bindings: [SQLiteValue] = []) throws {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw SQLiteError.prepareFailed(sql: sql, message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }

        try bind(bindings, to: stmt, sql: sql)

        let stepResult = sqlite3_step(stmt)
        if stepResult != SQLITE_DONE && stepResult != SQLITE_ROW {
            throw SQLiteError.stepFailed(sql: sql, message: String(cString: sqlite3_errmsg(db)))
        }
    }

    public func query(_ sql: String, bindings: [SQLiteValue] = []) throws -> [SQLiteRow] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw SQLiteError.prepareFailed(sql: sql, message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }

        try bind(bindings, to: stmt, sql: sql)

        var rows: [SQLiteRow] = []
        let columnCount = sqlite3_column_count(stmt)

        while true {
            let result = sqlite3_step(stmt)
            if result == SQLITE_ROW {
                var dict: [String: SQLiteValue] = [:]
                for index in 0..<columnCount {
                    let colName = String(cString: sqlite3_column_name(stmt, index))
                    let colType = sqlite3_column_type(stmt, index)
                    switch colType {
                    case SQLITE_INTEGER:
                        dict[colName] = .integer(sqlite3_column_int64(stmt, index))
                    case SQLITE_FLOAT:
                        dict[colName] = .double(sqlite3_column_double(stmt, index))
                    case SQLITE_TEXT:
                        if let cStr = sqlite3_column_text(stmt, index) {
                            dict[colName] = .text(String(cString: cStr))
                        } else {
                            dict[colName] = .null
                        }
                    case SQLITE_BLOB:
                        let bytes = sqlite3_column_bytes(stmt, index)
                        if bytes > 0, let ptr = sqlite3_column_blob(stmt, index) {
                            dict[colName] = .blob(Data(bytes: ptr, count: Int(bytes)))
                        } else {
                            dict[colName] = .blob(Data())
                        }
                    default:
                        dict[colName] = .null
                    }
                }
                rows.append(SQLiteRow(columns: dict))
            } else if result == SQLITE_DONE {
                break
            } else {
                throw SQLiteError.stepFailed(sql: sql, message: String(cString: sqlite3_errmsg(db)))
            }
        }
        return rows
    }

    private func bind(_ bindings: [SQLiteValue], to stmt: OpaquePointer?, sql: String) throws {
        for (idx, value) in bindings.enumerated() {
            let bindIndex = Int32(idx + 1)
            let code: Int32
            switch value {
            case .text(let str):
                code = sqlite3_bind_text(stmt, bindIndex, str, -1, sqliteTransient)
            case .integer(let intVal):
                code = sqlite3_bind_int64(stmt, bindIndex, intVal)
            case .double(let dblVal):
                code = sqlite3_bind_double(stmt, bindIndex, dblVal)
            case .blob(let data):
                if data.isEmpty {
                    code = sqlite3_bind_zeroblob(stmt, bindIndex, 0)
                } else {
                    code = data.withUnsafeBytes { rawBuffer in
                        sqlite3_bind_blob(stmt, bindIndex, rawBuffer.baseAddress, Int32(data.count), sqliteTransient)
                    }
                }
            case .null:
                code = sqlite3_bind_null(stmt, bindIndex)
            }
            if code != SQLITE_OK {
                throw SQLiteError.prepareFailed(sql: sql, message: String(cString: sqlite3_errmsg(db)))
            }
        }
    }
}
