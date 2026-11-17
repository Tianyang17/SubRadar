import Foundation

extension SQLiteSubscriptionRepository {
    // MARK: - Billing Records

    public func fetchBillingRecords(for subscriptionId: UUID) async throws -> [BillingRecord] {
        let rows = try await database.query(
            """
            SELECT id, subscription_id, amount, currency, base_currency_amount,
                   billed_at, record_source, record_kind, note
            FROM billing_records
            WHERE subscription_id = ?
            ORDER BY billed_at DESC;
            """,
            bindings: [.text(subscriptionId.uuidString)]
        )
        return rows.compactMap(decodeBillingRecord)
    }

    public func fetchBillingRecords(from startDate: Date, to endDate: Date) async throws -> [BillingRecord] {
        let rows = try await database.query(
            """
            SELECT id, subscription_id, amount, currency, base_currency_amount,
                   billed_at, record_source, record_kind, note
            FROM billing_records
            WHERE billed_at >= ? AND billed_at <= ?
            ORDER BY billed_at DESC;
            """,
            bindings: [
                .double(startDate.timeIntervalSince1970),
                .double(endDate.timeIntervalSince1970)
            ]
        )
        return rows.compactMap(decodeBillingRecord)
    }

    public func addBillingRecord(_ record: BillingRecord) async throws {
        try await database.execute(
            """
            INSERT INTO billing_records (
                id, subscription_id, amount, currency, base_currency_amount,
                billed_at, record_source, record_kind, note
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
            """,
            bindings: [
                .text(record.id.uuidString),
                .text(record.subscriptionId.uuidString),
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

    public func updateBillingRecord(_ record: BillingRecord) async throws {
        try await database.execute(
            """
            UPDATE billing_records
            SET amount = ?, currency = ?, base_currency_amount = ?,
                billed_at = ?, record_source = ?, record_kind = ?, note = ?
            WHERE id = ?;
            """,
            bindings: [
                .text(NSDecimalNumber(decimal: record.amount).stringValue),
                .text(record.currency),
                .text(NSDecimalNumber(decimal: record.baseCurrencyAmount).stringValue),
                .double(record.billedAt.timeIntervalSince1970),
                .text(record.source.rawValue),
                .text(record.kind.rawValue),
                .text(record.note),
                .text(record.id.uuidString)
            ]
        )
    }

    public func deleteBillingRecord(id: UUID) async throws {
        try await database.execute(
            "DELETE FROM billing_records WHERE id = ?;",
            bindings: [.text(id.uuidString)]
        )
    }

    public func totalSpent(for subscriptionId: UUID) async throws -> Decimal {
        let records = try await fetchBillingRecords(for: subscriptionId)
        return records.reduce(Decimal.zero) { $0 + $1.signedAmount }
    }

    // MARK: - Row Decoders

    func decodeSubscription(from row: SQLiteRow, fieldsBySubId: [UUID: [CustomField]]) -> SubscriptionItem? {
        guard let idStr = row.string("id"),
            let id = UUID(uuidString: idStr),
            let name = row.string("name"),
            let templateIdStr = row.string("template_id"),
            let templateId = UUID(uuidString: templateIdStr),
            let price = row.decimal("price"),
            let currency = row.string("currency"),
            let cycleRaw = row.string("billing_cycle_type"),
            let cycleType = BillingCycleType(rawValue: cycleRaw),
            let startDate = row.date("start_date"),
            let nextRenewalDate = row.date("next_renewal_date")
        else {
            return nil
        }

        let categoryId =
            row.string("category_id").flatMap(UUID.init(uuidString:))
            ?? CategoryPresetManager.defaultCategoryId(forTemplateId: templateId)
        let status = row.string("status").flatMap(SubscriptionStatus.init(rawValue:)) ?? .active
        let rawAutoRenew = row.bool("auto_renew")
        let decodedMode =
            row.string("renewal_mode").flatMap(RenewalMode.init(rawValue:))
            ?? (rawAutoRenew ? .automatic : .manual)
        return SubscriptionItem(
            id: id,
            name: name,
            categoryId: categoryId,
            templateId: templateId,
            iconData: row.data("icon_data"),
            price: price,
            renewalPrice: row.decimal("renewal_price"),
            currency: currency,
            billingCycleType: cycleType,
            billingCycleDays: row.int("billing_cycle_days"),
            startDate: startDate,
            nextRenewalDate: nextRenewalDate,
            autoRenew: rawAutoRenew,
            renewalMode: decodedMode,
            customRenewalNote: row.string("custom_renewal_note") ?? "",
            status: status,
            reminderDaysBefore: row.int("reminder_days_before") ?? 3,
            notes: row.string("notes") ?? "",
            customFields: fieldsBySubId[id] ?? [],
            createdAt: row.date("created_at") ?? Date(),
            updatedAt: row.date("updated_at") ?? Date()
        )
    }

    func decodeCustomField(from row: SQLiteRow) -> CustomField? {
        guard let idStr = row.string("id"),
            let id = UUID(uuidString: idStr),
            let subIdStr = row.string("subscription_id"),
            let subId = UUID(uuidString: subIdStr),
            let key = row.string("field_key"),
            let label = row.string("field_label"),
            let typeRaw = row.string("field_type"),
            let type = CustomFieldType(rawValue: typeRaw)
        else {
            return nil
        }

        let storedVal = row.string("field_value") ?? ""
        let resolvedValue: String
        if storedVal.hasPrefix(Self.keychainMarkerPrefix) {
            let refKey = String(storedVal.dropFirst(Self.keychainMarkerPrefix.count))
            resolvedValue = (try? secretStore.loadSecret(forKey: refKey)) ?? ""
        } else {
            resolvedValue = storedVal
        }

        return CustomField(
            id: id,
            subscriptionId: subId,
            key: key,
            label: label,
            type: type,
            value: resolvedValue,
            sortOrder: row.int("sort_order") ?? 0
        )
    }

    func decodeBillingRecord(from row: SQLiteRow) -> BillingRecord? {
        guard let idStr = row.string("id"),
            let id = UUID(uuidString: idStr),
            let subIdStr = row.string("subscription_id"),
            let subId = UUID(uuidString: subIdStr),
            let amount = row.decimal("amount"),
            let currency = row.string("currency"),
            let baseAmount = row.decimal("base_currency_amount"),
            let billedAt = row.date("billed_at"),
            let sourceRaw = row.string("record_source"),
            let source = BillingRecordSource(rawValue: sourceRaw)
        else {
            return nil
        }
        let kind = row.string("record_kind").flatMap(BillingRecordKind.init(rawValue:)) ?? .charge
        return BillingRecord(
            id: id,
            subscriptionId: subId,
            amount: amount,
            currency: currency,
            baseCurrencyAmount: baseAmount,
            billedAt: billedAt,
            source: source,
            kind: kind,
            note: row.string("note") ?? ""
        )
    }
}
