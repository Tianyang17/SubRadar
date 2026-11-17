import Foundation
import LocalAuthentication
import SQLite3

private let secretSQLiteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// 基于本地 SQLite 的敏感字段持久化存储（避免未签名/自签名版本升级触发 macOS 钥匙串授权弹窗）
public final class SQLiteSecretStore: SecretStoreProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private let handle: OpaquePointer

    public init(databasePath: String) throws {
        if databasePath != ":memory:" {
            let folderURL = URL(fileURLWithPath: databasePath).deletingLastPathComponent()
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        }

        var dbHandle: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(databasePath, &dbHandle, flags, nil) != SQLITE_OK {
            let message = dbHandle.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "Unknown error"
            sqlite3_close(dbHandle)
            throw SQLiteError.openFailed(message: message)
        }
        guard let openedHandle = dbHandle else {
            throw SQLiteError.openFailed(message: "Null sqlite handle for secrets")
        }

        self.handle = openedHandle
        sqlite3_busy_timeout(openedHandle, 5000)
        if databasePath != ":memory:" {
            try Self.executeSQL("PRAGMA journal_mode = WAL;", on: openedHandle)
        }
        try Self.executeSQL(
            """
            CREATE TABLE IF NOT EXISTS app_secrets (
                secret_key TEXT PRIMARY KEY NOT NULL,
                secret_value TEXT NOT NULL,
                updated_at REAL NOT NULL
            );
            """,
            on: openedHandle
        )
    }

    deinit {
        sqlite3_close_v2(handle)
    }

    public func saveSecret(_ value: String, forKey key: String) throws {
        try lock.withLock {
            let sql = """
                INSERT INTO app_secrets (secret_key, secret_value, updated_at)
                VALUES (?, ?, ?)
                ON CONFLICT(secret_key) DO UPDATE SET
                    secret_value = excluded.secret_value,
                    updated_at = excluded.updated_at;
                """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw SQLiteError.prepareFailed(sql: sql, message: String(cString: sqlite3_errmsg(handle)))
            }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_text(stmt, 1, key, -1, secretSQLiteTransient)
            sqlite3_bind_text(stmt, 2, value, -1, secretSQLiteTransient)
            sqlite3_bind_double(stmt, 3, Date().timeIntervalSince1970)

            guard sqlite3_step(stmt) == SQLITE_DONE else {
                throw SQLiteError.stepFailed(sql: sql, message: String(cString: sqlite3_errmsg(handle)))
            }
        }
    }

    public func loadSecret(forKey key: String) throws -> String? {
        try lock.withLock {
            let sql = "SELECT secret_value FROM app_secrets WHERE secret_key = ? LIMIT 1;"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw SQLiteError.prepareFailed(sql: sql, message: String(cString: sqlite3_errmsg(handle)))
            }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_text(stmt, 1, key, -1, secretSQLiteTransient)
            let result = sqlite3_step(stmt)
            if result == SQLITE_ROW {
                guard let cStr = sqlite3_column_text(stmt, 0) else { return nil }
                return String(cString: cStr)
            }
            if result == SQLITE_DONE {
                return nil
            }
            throw SQLiteError.stepFailed(sql: sql, message: String(cString: sqlite3_errmsg(handle)))
        }
    }

    public func deleteSecret(forKey key: String) throws {
        try lock.withLock {
            let sql = "DELETE FROM app_secrets WHERE secret_key = ?;"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw SQLiteError.prepareFailed(sql: sql, message: String(cString: sqlite3_errmsg(handle)))
            }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_text(stmt, 1, key, -1, secretSQLiteTransient)
            guard sqlite3_step(stmt) == SQLITE_DONE else {
                throw SQLiteError.stepFailed(sql: sql, message: String(cString: sqlite3_errmsg(handle)))
            }
        }
    }

    public func authenticateUser(reason: String) async -> Bool {
        let context = LAContext()
        var authError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError) else {
            return true
        }
        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }

    private static func executeSQL(_ sql: String, on db: OpaquePointer) throws {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw SQLiteError.prepareFailed(sql: sql, message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }

        let result = sqlite3_step(stmt)
        if result != SQLITE_DONE && result != SQLITE_ROW {
            throw SQLiteError.stepFailed(sql: sql, message: String(cString: sqlite3_errmsg(db)))
        }
    }
}
