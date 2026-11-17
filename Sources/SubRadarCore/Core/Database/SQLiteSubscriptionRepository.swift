import Foundation

/// 基于原生 SQLite3 的真实订阅数据仓库实现
public final class SQLiteSubscriptionRepository: SubscriptionRepositoryProtocol, Sendable {
    let database: SQLiteDatabase
    let secretStore: SecretStoreProtocol

    static let keychainMarkerPrefix = "__KEYCHAIN_REF__:"

    public init(database: SQLiteDatabase, secretStore: SecretStoreProtocol) {
        self.database = database
        self.secretStore = secretStore
    }

    // MARK: - Categories
    // MARK: - Subscriptions

    public func fetchSubscriptions() async throws -> [SubscriptionItem] {
        let subRows = try await database.query(
            """
            SELECT id, name, category_id, template_id, icon_data, price, renewal_price, currency, billing_cycle_type,
                   billing_cycle_days, start_date, next_renewal_date, auto_renew, renewal_mode, custom_renewal_note,
                   status, reminder_days_before, notes, created_at, updated_at
            FROM subscriptions
            ORDER BY next_renewal_date ASC;
            """)

        let fieldRows = try await database.query(
            """
            SELECT id, subscription_id, field_key, field_label, field_type, field_value, sort_order
            FROM subscription_custom_fields
            ORDER BY sort_order ASC;
            """)

        var fieldsBySubId: [UUID: [CustomField]] = [:]
        for row in fieldRows {
            if let field = decodeCustomField(from: row) {
                fieldsBySubId[field.subscriptionId, default: []].append(field)
            }
        }

        return subRows.compactMap { row in
            decodeSubscription(from: row, fieldsBySubId: fieldsBySubId)
        }
    }

    public func fetchSubscription(id: UUID) async throws -> SubscriptionItem? {
        let subRows = try await database.query(
            """
            SELECT id, name, category_id, template_id, icon_data, price, renewal_price, currency, billing_cycle_type,
                   billing_cycle_days, start_date, next_renewal_date, auto_renew, renewal_mode, custom_renewal_note,
                   status, reminder_days_before, notes, created_at, updated_at
            FROM subscriptions
            WHERE id = ?
            LIMIT 1;
            """,
            bindings: [.text(id.uuidString)]
        )
        guard let row = subRows.first else { return nil }

        let fieldRows = try await database.query(
            """
            SELECT id, subscription_id, field_key, field_label, field_type, field_value, sort_order
            FROM subscription_custom_fields
            WHERE subscription_id = ?
            ORDER BY sort_order ASC;
            """,
            bindings: [.text(id.uuidString)]
        )
        let fields = fieldRows.compactMap { decodeCustomField(from: $0) }
        return decodeSubscription(from: row, fieldsBySubId: [id: fields])
    }

    public func saveSubscription(_ item: SubscriptionItem, initialRecords: [BillingRecord] = []) async throws {
        try item.validate()

        // 敏感字段写入本地 SecretStore（app_secrets 表），字段表仅保存引用 key
        var persistedFields: [(CustomField, String)] = []
        for (index, field) in item.customFields.enumerated() {
            var normalized = field
            normalized.sortOrder = index
            if field.isSensitive {
                let refKey = "subradar.field.\(field.id.uuidString)"
                if field.value.isEmpty {
                    try? secretStore.deleteSecret(forKey: refKey)
                    persistedFields.append((normalized, ""))
                } else {
                    try secretStore.saveSecret(field.value, forKey: refKey)
                    persistedFields.append((normalized, "\(Self.keychainMarkerPrefix)\(refKey)"))
                }
            } else {
                persistedFields.append((normalized, field.value))
            }
        }

        let itemCopy = item
        let fieldsSnapshot = persistedFields
        let recordsSnapshot = initialRecords

        try await database.performTransaction { conn in
            try conn.execute(
                """
                INSERT INTO subscriptions (
                    id, name, category_id, template_id, icon_data, price, renewal_price, currency, billing_cycle_type,
                    billing_cycle_days, start_date, next_renewal_date, auto_renew, renewal_mode, custom_renewal_note,
                    status, reminder_days_before, notes, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    name = excluded.name,
                    category_id = excluded.category_id,
                    template_id = excluded.template_id,
                    icon_data = excluded.icon_data,
                    price = excluded.price,
                    renewal_price = excluded.renewal_price,
                    currency = excluded.currency,
                    billing_cycle_type = excluded.billing_cycle_type,
                    billing_cycle_days = excluded.billing_cycle_days,
                    start_date = excluded.start_date,
                    next_renewal_date = excluded.next_renewal_date,
                    auto_renew = excluded.auto_renew,
                    renewal_mode = excluded.renewal_mode,
                    custom_renewal_note = excluded.custom_renewal_note,
                    status = excluded.status,
                    reminder_days_before = excluded.reminder_days_before,
                    notes = excluded.notes,
                    updated_at = excluded.updated_at;
                """,
                bindings: [
                    .text(itemCopy.id.uuidString),
                    .text(itemCopy.name),
                    .text(itemCopy.categoryId.uuidString),
                    .text(itemCopy.templateId.uuidString),
                    itemCopy.iconData.map { .blob($0) } ?? .null,
                    .text(NSDecimalNumber(decimal: itemCopy.price).stringValue),
                    itemCopy.renewalPrice.map { .text(NSDecimalNumber(decimal: $0).stringValue) } ?? .null,
                    .text(itemCopy.currency),
                    .text(itemCopy.billingCycleType.rawValue),
                    itemCopy.billingCycleDays.map { .integer(Int64($0)) } ?? .null,
                    .double(itemCopy.startDate.timeIntervalSince1970),
                    .double(itemCopy.nextRenewalDate.timeIntervalSince1970),
                    .integer(itemCopy.autoRenew ? 1 : 0),
                    .text(itemCopy.renewalMode.rawValue),
                    .text(itemCopy.customRenewalNote),
                    .text(itemCopy.status.rawValue),
                    .integer(Int64(itemCopy.reminderDaysBefore)),
                    .text(itemCopy.notes),
                    .double(itemCopy.createdAt.timeIntervalSince1970),
                    .double(itemCopy.updatedAt.timeIntervalSince1970)
                ]
            )

            // 覆盖重建当前条目的动态字段
            try conn.execute(
                "DELETE FROM subscription_custom_fields WHERE subscription_id = ?;",
                bindings: [.text(itemCopy.id.uuidString)]
            )

            for (field, storedValue) in fieldsSnapshot {
                try conn.execute(
                    """
                    INSERT INTO subscription_custom_fields (
                        id, subscription_id, field_key, field_label, field_type, field_value, sort_order
                    ) VALUES (?, ?, ?, ?, ?, ?, ?);
                    """,
                    bindings: [
                        .text(field.id.uuidString),
                        .text(itemCopy.id.uuidString),
                        .text(field.key),
                        .text(field.label),
                        .text(field.type.rawValue),
                        .text(storedValue),
                        .integer(Int64(field.sortOrder))
                    ]
                )
            }

            // 批量写入初始/历史推算扣费流水
            for record in recordsSnapshot {
                try conn.execute(
                    """
                    INSERT OR IGNORE INTO billing_records (
                        id, subscription_id, amount, currency, base_currency_amount,
                        billed_at, record_source, record_kind, note
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
                    """,
                    bindings: [
                        .text(record.id.uuidString),
                        .text(itemCopy.id.uuidString),
                        .text(NSDecimalNumber(decimal: record.amount).stringValue),
                        .text(record.currency),
                        .text(NSDecimalNumber(decimal: record.baseCurrencyAmount).stringValue),
                        .double(record.billedAt.timeIntervalSince1970),
                        .text(record.source.rawValue),
                        .text(record.kind.rawValue),
                        .text(record.note)
                    ]
                )
            }
        }
    }

    public func deleteSubscription(id: UUID) async throws {
        // 先读取关联字段，清理本地敏感存储中的对应条目
        if let existing = try await fetchSubscription(id: id) {
            for field in existing.customFields where field.isSensitive {
                try? secretStore.deleteSecret(forKey: "subradar.field.\(field.id.uuidString)")
            }
        }
        try await database.execute(
            "DELETE FROM subscriptions WHERE id = ?;",
            bindings: [.text(id.uuidString)]
        )
    }
}
