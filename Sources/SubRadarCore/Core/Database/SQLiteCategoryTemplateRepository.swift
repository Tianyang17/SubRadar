import Foundation

extension SQLiteSubscriptionRepository {
    // MARK: - Categories

    public func fetchCategories() async throws -> [SubscriptionCategory] {
        let rows = try await database.query(
            """
            SELECT id, name, icon_symbol, color_key, is_builtin, sort_order, created_at
            FROM categories
            ORDER BY sort_order ASC, created_at ASC;
            """)
        return rows.compactMap { row in
            guard let idStr = row.string("id"),
                let id = UUID(uuidString: idStr),
                let name = row.string("name"),
                let iconSymbol = row.string("icon_symbol")
            else {
                return nil
            }
            let colorKey = row.string("color_key").flatMap(CategoryColorKey.init(rawValue:)) ?? .indigo
            return SubscriptionCategory(
                id: id,
                name: name,
                iconSymbol: iconSymbol,
                colorKey: colorKey,
                isBuiltin: row.bool("is_builtin"),
                sortOrder: row.int("sort_order") ?? 100,
                createdAt: row.date("created_at") ?? Date()
            )
        }
    }

    public func saveCategory(_ category: SubscriptionCategory) async throws {
        try await database.execute(
            """
            INSERT INTO categories (id, name, icon_symbol, color_key, is_builtin, sort_order, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                name = excluded.name,
                icon_symbol = excluded.icon_symbol,
                color_key = excluded.color_key,
                sort_order = excluded.sort_order;
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

    public func deleteCategory(id: UUID) async throws {
        let fallbackId = SubscriptionCategory.BuiltinID.productivity.uuidString
        let targetId = id.uuidString
        try await database.performTransaction { conn in
            try conn.execute(
                """
                UPDATE subscriptions
                SET category_id = ?
                WHERE category_id = ?;
                """,
                bindings: [.text(fallbackId), .text(targetId)]
            )
            try conn.execute(
                "DELETE FROM categories WHERE id = ? AND is_builtin = 0;",
                bindings: [.text(targetId)]
            )
        }
    }

    // MARK: - Templates

    public func fetchTemplates() async throws -> [TemplateDefinition] {
        let rows = try await database.query(
            """
            SELECT id, name, icon_symbol, is_builtin, default_fields_json, created_at
            FROM templates
            ORDER BY is_builtin DESC, created_at ASC;
            """)
        let decoder = JSONDecoder()
        let mapped: [TemplateDefinition] = rows.compactMap { row in
            guard let idStr = row.string("id"),
                let id = UUID(uuidString: idStr),
                let name = row.string("name"),
                let iconSymbol = row.string("icon_symbol"),
                let fieldsJSON = row.string("default_fields_json"),
                let fieldsData = fieldsJSON.data(using: .utf8),
                let fields = try? decoder.decode([FieldSchema].self, from: fieldsData)
            else {
                return nil
            }
            return TemplateDefinition(
                id: id,
                name: name,
                iconSymbol: iconSymbol,
                isBuiltin: row.bool("is_builtin"),
                defaultFields: fields,
                createdAt: row.date("created_at") ?? Date()
            )
        }
        return TemplatePresetManager.sortedTemplates(mapped)
    }

    public func saveTemplate(_ template: TemplateDefinition) async throws {
        let fieldsData = try JSONEncoder().encode(template.defaultFields)
        let fieldsJSON = String(data: fieldsData, encoding: .utf8) ?? "[]"
        try await database.execute(
            """
            INSERT INTO templates (id, name, icon_symbol, is_builtin, default_fields_json, created_at)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                name = excluded.name,
                icon_symbol = excluded.icon_symbol,
                default_fields_json = excluded.default_fields_json;
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

    public func deleteTemplate(id: UUID) async throws {
        try await database.execute(
            "DELETE FROM templates WHERE id = ? AND is_builtin = 0;",
            bindings: [.text(id.uuidString)]
        )
    }
}
