import Foundation

extension DatabaseMigrator {
    static func applyV20Migration(on conn: SQLiteConnection) throws {
        try syncBuiltinCategories(on: conn)
        try syncBuiltinTemplates(on: conn, targetVersion: 20)
    }

    static func applyV21Migration(on conn: SQLiteConnection) throws {
        let removedCategoryID = "00000000-0000-0000-0002-000000000008"
        let removedTemplateID = "00000000-0000-0000-0000-000000000008"
        try conn.execute(
            "UPDATE subscriptions SET category_id = ? WHERE category_id = ?;",
            bindings: [.text(SubscriptionCategory.BuiltinID.productivity.uuidString), .text(removedCategoryID)]
        )
        try conn.execute(
            "UPDATE subscriptions SET template_id = ? WHERE template_id = ?;",
            bindings: [.text(TemplateDefinition.BuiltinID.custom.uuidString), .text(removedTemplateID)]
        )
        try conn.execute(
            "DELETE FROM categories WHERE id = ? AND is_builtin = 1;", bindings: [.text(removedCategoryID)])
        try conn.execute("DELETE FROM templates WHERE id = ? AND is_builtin = 1;", bindings: [.text(removedTemplateID)])
        try syncBuiltinCategories(on: conn)
        try syncBuiltinTemplates(on: conn, targetVersion: 21)
    }

    static func syncBuiltinCategories(on conn: SQLiteConnection) throws {
        for category in CategoryPresetManager.builtinCategories {
            try conn.execute(
                """
                INSERT OR IGNORE INTO categories (
                    id, name, icon_symbol, color_key, is_builtin, sort_order, created_at
                )
                VALUES (?, ?, ?, ?, 1, ?, ?);
                """,
                bindings: [
                    .text(category.id.uuidString),
                    .text(category.name),
                    .text(category.iconSymbol),
                    .text(category.colorKey.rawValue),
                    .integer(Int64(category.sortOrder)),
                    .double(category.createdAt.timeIntervalSince1970)
                ]
            )
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
    }
}
