import Foundation

/// SQLite 数据库版本迁移管理器
public enum DatabaseMigrator {
    public static let latestVersion = 21

    private typealias MigrationStep = @Sendable (SQLiteConnection) throws -> Void

    private static let migrationSteps: [(targetVersion: Int, apply: MigrationStep)] = [
        (
            1,
            { conn in
                try applyV1Migration(on: conn)
                try seedBuiltinTemplatesIfEmpty(on: conn)
            }
        ),
        (
            2,
            { conn in
                try applyV2Migration(on: conn)
                try seedBuiltinCategoriesIfEmpty(on: conn)
            }
        ),
        (3, applyV3Migration),
        (4, applyV4Migration),
        (5, applyV5Migration),
        (6, applyV6Migration),
        (7, applyV7Migration),
        (8, applyV8Migration),
        (9, applyV9Migration),
        (10, applyV10Migration),
        (11, applyV11Migration),
        (
            12,
            { conn in
                try applyV12Migration(on: conn)
                try syncBuiltinTemplates(on: conn, targetVersion: 12)
            }
        ),
        (13, applyV13Migration),
        (14, applyV14Migration),
        (
            15,
            { conn in
                try syncBuiltinTemplates(on: conn, targetVersion: 15)
            }
        ),
        (16, applyV16Migration),
        (17, applyV17Migration),
        (
            18,
            { conn in
                try syncBuiltinTemplates(on: conn, targetVersion: 18)
            }
        ),
        (
            19,
            { conn in
                try syncBuiltinTemplates(on: conn, targetVersion: 19)
            }
        ),
        (20, applyV20Migration),
        (21, applyV21Migration)
    ]

    public static func migrateIfNeeded(connection conn: SQLiteConnection) throws {
        var currentVersion = try conn.userVersion()
        for step in migrationSteps where currentVersion < step.targetVersion {
            try conn.inTransaction { txConn in
                try step.apply(txConn)
            }
            currentVersion = step.targetVersion
        }
    }

    public static func migrateIfNeeded(_ database: SQLiteDatabase) async throws {
        var currentVersion = try await database.userVersion()
        for step in migrationSteps where currentVersion < step.targetVersion {
            try await database.performTransaction { conn in
                try step.apply(conn)
            }
            currentVersion = step.targetVersion
        }
    }

    private static func applyV1Migration(on conn: SQLiteConnection) throws {
        // 1. 模版定义表
        try conn.execute(
            """
            CREATE TABLE IF NOT EXISTS templates (
                id TEXT PRIMARY KEY NOT NULL,
                name TEXT NOT NULL,
                icon_symbol TEXT NOT NULL,
                is_builtin INTEGER NOT NULL DEFAULT 0,
                default_fields_json TEXT NOT NULL,
                created_at REAL NOT NULL
            );
            """)

        // 2. 订阅主表
        try conn.execute(
            """
            CREATE TABLE IF NOT EXISTS subscriptions (
                id TEXT PRIMARY KEY NOT NULL,
                name TEXT NOT NULL,
                template_id TEXT NOT NULL,
                icon_data BLOB,
                price TEXT NOT NULL,
                currency TEXT NOT NULL,
                billing_cycle_type TEXT NOT NULL,
                billing_cycle_days INTEGER,
                start_date REAL NOT NULL,
                next_renewal_date REAL NOT NULL,
                auto_renew INTEGER NOT NULL DEFAULT 1,
                status TEXT NOT NULL DEFAULT 'active',
                reminder_days_before INTEGER NOT NULL DEFAULT 3,
                notes TEXT NOT NULL DEFAULT '',
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL,
                FOREIGN KEY (template_id) REFERENCES templates(id)
            );
            """)

        // 3. 动态扩展字段表（级联删除）
        try conn.execute(
            """
            CREATE TABLE IF NOT EXISTS subscription_custom_fields (
                id TEXT PRIMARY KEY NOT NULL,
                subscription_id TEXT NOT NULL,
                field_key TEXT NOT NULL,
                field_label TEXT NOT NULL,
                field_type TEXT NOT NULL,
                field_value TEXT NOT NULL DEFAULT '',
                sort_order INTEGER NOT NULL DEFAULT 0,
                FOREIGN KEY (subscription_id) REFERENCES subscriptions(id) ON DELETE CASCADE
            );
            """)
        try conn.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_custom_fields_sub_id
            ON subscription_custom_fields(subscription_id, sort_order);
            """)

        // 4. 历史与续订计费流水表（按 billed_at 建索引加速自定义时间段聚合）
        try conn.execute(
            """
            CREATE TABLE IF NOT EXISTS billing_records (
                id TEXT PRIMARY KEY NOT NULL,
                subscription_id TEXT NOT NULL,
                amount TEXT NOT NULL,
                currency TEXT NOT NULL,
                base_currency_amount TEXT NOT NULL,
                billed_at REAL NOT NULL,
                record_source TEXT NOT NULL,
                note TEXT NOT NULL DEFAULT '',
                FOREIGN KEY (subscription_id) REFERENCES subscriptions(id) ON DELETE CASCADE
            );
            """)
        try conn.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_billing_records_sub_id
            ON billing_records(subscription_id, billed_at DESC);
            """)
        try conn.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_billing_records_billed_at
            ON billing_records(billed_at);
            """)

        // 5. 历史与实时汇率缓存表（联合主键 currency_code + rate_date）
        try conn.execute(
            """
            CREATE TABLE IF NOT EXISTS exchange_rates (
                currency_code TEXT NOT NULL,
                rate_date TEXT NOT NULL,
                base_currency TEXT NOT NULL DEFAULT 'CNY',
                rate_to_base REAL NOT NULL,
                updated_at REAL NOT NULL,
                PRIMARY KEY (currency_code, rate_date, base_currency)
            );
            """)

        try conn.execute("PRAGMA user_version = 1;")
    }

    private static func seedBuiltinTemplatesIfEmpty(on conn: SQLiteConnection) throws {
        let encoder = JSONEncoder()
        for template in TemplatePresetManager.builtinTemplates {
            let fieldsData = try encoder.encode(template.defaultFields)
            let fieldsJSON = String(data: fieldsData, encoding: .utf8) ?? "[]"
            try conn.execute(
                """
                INSERT OR IGNORE INTO templates (id, name, icon_symbol, is_builtin, default_fields_json, created_at)
                VALUES (?, ?, ?, ?, ?, ?);
                """,
                bindings: [
                    .text(template.id.uuidString),
                    .text(template.name),
                    .text(template.iconSymbol),
                    .integer(template.isBuiltin ? 1 : 0),
                    .text(fieldsJSON),
                    .double(template.createdAt.timeIntervalSince1970)
                ]
            )
        }
    }

    private static func applyV13Migration(on conn: SQLiteConnection) throws {
        let removedCategoryID = "00000000-0000-0000-0002-000000000007"
        let fallbackCategoryID = SubscriptionCategory.BuiltinID.productivity.uuidString
        try conn.execute(
            "UPDATE subscriptions SET category_id = ? WHERE category_id = ?;",
            bindings: [.text(fallbackCategoryID), .text(removedCategoryID)]
        )
        try conn.execute(
            "DELETE FROM categories WHERE id = ?;",
            bindings: [.text(removedCategoryID)]
        )
        try conn.execute("PRAGMA user_version = 13;")
    }

    private static func applyV14Migration(on conn: SQLiteConnection) throws {
        for category in CategoryPresetManager.builtinCategories {
            try conn.execute(
                """
                UPDATE categories
                SET name = ?, icon_symbol = ?, color_key = ?, sort_order = ?
                WHERE id = ? AND is_builtin = 1;
                """,
                bindings: [
                    .text(category.name),
                    .text(category.iconSymbol),
                    .text(category.colorKey.rawValue),
                    .integer(Int64(category.sortOrder)),
                    .text(category.id.uuidString)
                ]
            )
        }
        try conn.execute("PRAGMA user_version = 14;")
    }

    static func applyV17Migration(on conn: SQLiteConnection) throws {
        let missingRows = try conn.query(
            """
            SELECT s.id, s.price, s.currency, s.start_date
            FROM subscriptions s
            WHERE s.template_id != ?
              AND NOT EXISTS (
                  SELECT 1 FROM billing_records br WHERE br.subscription_id = s.id
              );
            """,
            bindings: [.text(TemplateDefinition.BuiltinID.apiBalance.uuidString)]
        )
        for row in missingRows {
            guard let subId = row.string("id"),
                let priceStr = row.string("price"),
                let price = Decimal(string: priceStr),
                price > 0
            else { continue }
            let currency = row.string("currency") ?? "CNY"
            let startTimestamp = row.double("start_date") ?? Date().timeIntervalSince1970
            let formattedPrice = NSDecimalNumber(decimal: price).stringValue
            try conn.execute(
                """
                INSERT INTO billing_records (
                    id, subscription_id, amount, currency, base_currency_amount,
                    billed_at, record_source, record_kind, note
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
                """,
                bindings: [
                    .text(UUID().uuidString), .text(subId), .text(formattedPrice), .text(currency),
                    .text(formattedPrice), .double(startTimestamp),
                    .text(BillingRecordSource.initialPurchase.rawValue),
                    .text(BillingRecordKind.charge.rawValue), .text("初始购买记录")
                ]
            )
        }
        try conn.execute("PRAGMA user_version = 17;")
    }
}
