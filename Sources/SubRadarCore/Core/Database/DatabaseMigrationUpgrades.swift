import Foundation

extension DatabaseMigrator {
    static func applyV2Migration(on conn: SQLiteConnection) throws {
        try conn.execute(
            """
            CREATE TABLE IF NOT EXISTS categories (
                id TEXT PRIMARY KEY NOT NULL,
                name TEXT NOT NULL,
                icon_symbol TEXT NOT NULL,
                color_key TEXT NOT NULL DEFAULT 'indigo',
                is_builtin INTEGER NOT NULL DEFAULT 0,
                sort_order INTEGER NOT NULL DEFAULT 100,
                created_at REAL NOT NULL
            );
            """)

        try conn.execute(
            """
            ALTER TABLE subscriptions
            ADD COLUMN category_id TEXT NOT NULL DEFAULT '';
            """)

        try conn.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_subscriptions_category_id
            ON subscriptions(category_id);
            """)

        for template in TemplatePresetManager.builtinTemplates {
            let defaultCategoryId = CategoryPresetManager.defaultCategoryId(forTemplateId: template.id)
            try conn.execute(
                """
                UPDATE subscriptions
                SET category_id = ?
                WHERE category_id = '' AND template_id = ?;
                """,
                bindings: [
                    .text(defaultCategoryId.uuidString),
                    .text(template.id.uuidString)
                ]
            )
        }

        try conn.execute(
            """
            UPDATE subscriptions
            SET category_id = ?
            WHERE category_id = '';
            """,
            bindings: [.text(SubscriptionCategory.BuiltinID.productivity.uuidString)]
        )

        try conn.execute("PRAGMA user_version = 2;")
    }

    static func seedBuiltinCategoriesIfEmpty(on conn: SQLiteConnection) throws {
        for category in CategoryPresetManager.builtinCategories {
            try conn.execute(
                """
                INSERT OR IGNORE INTO categories (id, name, icon_symbol, color_key, is_builtin, sort_order, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?);
                """,
                bindings: [
                    .text(category.id.uuidString),
                    .text(category.name),
                    .text(category.iconSymbol),
                    .text(category.colorKey.rawValue),
                    .integer(category.isBuiltin ? 1 : 0),
                    .integer(Int64(category.sortOrder)),
                    .double(category.createdAt.timeIntervalSince1970)
                ]
            )
        }
    }

    static func applyV3Migration(on conn: SQLiteConnection) throws {
        let encoder = JSONEncoder()
        if let softwareTemplate = TemplatePresetManager.builtinTemplates.first(where: {
            $0.id == TemplateDefinition.BuiltinID.softwareLicense
        }) {
            let fieldsData = try encoder.encode(softwareTemplate.defaultFields)
            let fieldsJSON = String(data: fieldsData, encoding: .utf8) ?? "[]"
            try conn.execute(
                """
                UPDATE templates
                SET default_fields_json = ?
                WHERE id = ? AND is_builtin = 1;
                """,
                bindings: [
                    .text(fieldsJSON),
                    .text(softwareTemplate.id.uuidString)
                ]
            )
        }
        try conn.execute("PRAGMA user_version = 3;")
    }

    static func applyV4Migration(on conn: SQLiteConnection) throws {
        let encoder = JSONEncoder()
        if let aiTemplate = TemplatePresetManager.builtinTemplates.first(where: {
            $0.id == TemplateDefinition.BuiltinID.aiMembership
        }) {
            let fieldsData = try encoder.encode(aiTemplate.defaultFields)
            let fieldsJSON = String(data: fieldsData, encoding: .utf8) ?? "[]"
            try conn.execute(
                """
                INSERT OR IGNORE INTO templates (id, name, icon_symbol, is_builtin, default_fields_json, created_at)
                VALUES (?, ?, ?, ?, ?, ?);
                """,
                bindings: [
                    .text(aiTemplate.id.uuidString),
                    .text(aiTemplate.name),
                    .text(aiTemplate.iconSymbol),
                    .integer(1),
                    .text(fieldsJSON),
                    .double(aiTemplate.createdAt.timeIntervalSince1970)
                ]
            )
        }
        try conn.execute("PRAGMA user_version = 4;")
    }

    private static func hasColumn(_ columnName: String, in tableName: String, conn: SQLiteConnection) throws -> Bool {
        let rows = try conn.query("PRAGMA table_info(\(tableName));")
        return rows.contains { $0.string("name") == columnName }
    }

    static func applyV5Migration(on conn: SQLiteConnection) throws {
        if !(try hasColumn("renewal_price", in: "subscriptions", conn: conn)) {
            try conn.execute(
                """
                ALTER TABLE subscriptions
                ADD COLUMN renewal_price TEXT;
                """)
        }
        try conn.execute("PRAGMA user_version = 5;")
    }

    static func applyV6Migration(on conn: SQLiteConnection) throws {
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
                    .integer(1),
                    .text(fieldsJSON),
                    .double(template.createdAt.timeIntervalSince1970)
                ]
            )
            try conn.execute(
                """
                UPDATE templates
                SET default_fields_json = ?, icon_symbol = ?
                WHERE id = ? AND is_builtin = 1;
                """,
                bindings: [
                    .text(fieldsJSON),
                    .text(template.iconSymbol),
                    .text(template.id.uuidString)
                ]
            )
        }
        try conn.execute("PRAGMA user_version = 6;")
    }

    static func applyV7Migration(on conn: SQLiteConnection) throws {
        if !(try hasColumn("record_kind", in: "billing_records", conn: conn)) {
            try conn.execute(
                """
                ALTER TABLE billing_records
                ADD COLUMN record_kind TEXT NOT NULL DEFAULT 'charge';
                """)
        }
        try conn.execute("PRAGMA user_version = 7;")
    }

    static func applyV8Migration(on conn: SQLiteConnection) throws {
        for category in CategoryPresetManager.builtinCategories {
            try conn.execute(
                """
                INSERT OR IGNORE INTO categories (id, name, icon_symbol, color_key, is_builtin, sort_order, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?);
                """,
                bindings: [
                    .text(category.id.uuidString),
                    .text(category.name),
                    .text(category.iconSymbol),
                    .text(category.colorKey.rawValue),
                    .integer(category.isBuiltin ? 1 : 0),
                    .integer(Int64(category.sortOrder)),
                    .double(category.createdAt.timeIntervalSince1970)
                ]
            )
        }
        try conn.execute("PRAGMA user_version = 8;")
    }

    static func applyV9Migration(on conn: SQLiteConnection) throws {
        try syncBuiltinTemplates(on: conn, targetVersion: 9)
    }

    static func applyV10Migration(on conn: SQLiteConnection) throws {
        try syncBuiltinTemplates(on: conn, targetVersion: 10)
    }

    static func applyV11Migration(on conn: SQLiteConnection) throws {
        try syncBuiltinTemplates(on: conn, targetVersion: 11)
    }

    static func applyV12Migration(on conn: SQLiteConnection) throws {
        try conn.execute(
            """
            CREATE TABLE IF NOT EXISTS app_secrets (
                secret_key TEXT PRIMARY KEY NOT NULL,
                secret_value TEXT NOT NULL,
                updated_at REAL NOT NULL
            );
            """)
        try conn.execute("PRAGMA user_version = 12;")
    }

    static func syncBuiltinTemplates(on conn: SQLiteConnection, targetVersion: Int) throws {
        let encoder = JSONEncoder()
        for template in TemplatePresetManager.builtinTemplates {
            let fieldsData = try encoder.encode(template.defaultFields)
            let fieldsJSON = String(data: fieldsData, encoding: .utf8) ?? "[]"
            try conn.execute(
                """
                INSERT OR IGNORE INTO templates (id, name, icon_symbol, is_builtin, default_fields_json, created_at)
                VALUES (?, ?, ?, 1, ?, ?);
                """,
                bindings: [
                    .text(template.id.uuidString),
                    .text(template.name),
                    .text(template.iconSymbol),
                    .text(fieldsJSON),
                    .double(template.createdAt.timeIntervalSince1970)
                ]
            )
            try conn.execute(
                """
                UPDATE templates
                SET default_fields_json = ?, icon_symbol = ?
                WHERE id = ? AND is_builtin = 1;
                """,
                bindings: [
                    .text(fieldsJSON),
                    .text(template.iconSymbol),
                    .text(template.id.uuidString)
                ]
            )
        }
        try conn.execute("PRAGMA user_version = \(targetVersion);")
    }

    static func applyV16Migration(on conn: SQLiteConnection) throws {
        if !(try hasColumn("renewal_mode", in: "subscriptions", conn: conn)) {
            try conn.execute("ALTER TABLE subscriptions ADD COLUMN renewal_mode TEXT;")
        }
        if !(try hasColumn("custom_renewal_note", in: "subscriptions", conn: conn)) {
            try conn.execute("ALTER TABLE subscriptions ADD COLUMN custom_renewal_note TEXT NOT NULL DEFAULT '';")
        }
        try conn.execute(
            """
            UPDATE subscriptions
            SET renewal_mode = CASE WHEN auto_renew = 1 THEN 'automatic' ELSE 'manual' END
            WHERE renewal_mode IS NULL;
            """
        )
        try conn.execute("PRAGMA user_version = 16;")
    }
}
