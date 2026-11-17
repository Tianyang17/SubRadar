import Foundation

public struct SubRadarBackupPayload: Codable, Sendable {
    public var version: Int
    public var exportedAt: Date
    public var includesSecrets: Bool
    public var categories: [SubscriptionCategory]
    public var templates: [TemplateDefinition]
    public var subscriptions: [SubscriptionItem]
    public var billingRecords: [BillingRecord]

    public init(
        version: Int = 1,
        exportedAt: Date = Date(),
        includesSecrets: Bool = false,
        categories: [SubscriptionCategory],
        templates: [TemplateDefinition],
        subscriptions: [SubscriptionItem],
        billingRecords: [BillingRecord]
    ) {
        self.version = version
        self.exportedAt = exportedAt
        self.includesSecrets = includesSecrets
        self.categories = categories
        self.templates = templates
        self.subscriptions = subscriptions
        self.billingRecords = billingRecords
    }
}

public struct BackupRestoreStats: Sendable, Equatable {
    public let restoredCategories: Int
    public let restoredTemplates: Int
    public let restoredSubscriptions: Int
    public let restoredRecords: Int
}

public final class BackupExportService: Sendable {
    public init() {}

    public func exportLedgerCSV(
        from repository: SubscriptionRepositoryProtocol,
        baseCurrency: String
    ) async throws -> String {
        let subscriptions = try await repository.fetchSubscriptions()
        let categories = try await repository.fetchCategories()
        let records = try await repository.fetchBillingRecords(
            from: Date(timeIntervalSince1970: 0),
            to: Date.distantFuture
        )
        let subById = Dictionary(uniqueKeysWithValues: subscriptions.map { ($0.id, $0) })
        let catById = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })

        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"

        var lines: [String] = [
            "\u{FEFF}日期,订阅名称,所属分类,账单类型,来源,原币金额,币种,折算金额,基准币种,备注"
        ]

        for record in records.sorted(by: { $0.billedAt > $1.billedAt }) {
            let sub = subById[record.subscriptionId]
            let subName = sub?.name ?? "已删除订阅"
            let catName = sub.flatMap { catById[$0.categoryId]?.name } ?? "未分类"
            let signedOriginal = NSDecimalNumber(decimal: record.signedAmount).stringValue
            let signedBase = NSDecimalNumber(decimal: record.signedBaseCurrencyAmount).stringValue

            let cols = [
                df.string(from: record.billedAt),
                subName,
                catName,
                record.kind.displayName,
                record.source.displayName,
                signedOriginal,
                record.currency,
                signedBase,
                baseCurrency.uppercased(),
                record.note
            ]
            lines.append(cols.map(escapeCSV).joined(separator: ","))
        }

        return lines.joined(separator: "\n")
    }

    public func exportJSONBackup(
        from repository: SubscriptionRepositoryProtocol,
        includeSecrets: Bool = false
    ) async throws -> Data {
        let categories = try await repository.fetchCategories()
        let templates = try await repository.fetchTemplates()
        var subscriptions = try await repository.fetchSubscriptions()
        let records = try await repository.fetchBillingRecords(
            from: Date(timeIntervalSince1970: 0),
            to: Date.distantFuture
        )

        if !includeSecrets {
            subscriptions = subscriptions.map { sub in
                var copy = sub
                copy.customFields = sub.customFields.map { field in
                    var f = field
                    if f.isSensitive && !f.value.isEmpty {
                        f.value = ""
                    }
                    return f
                }
                return copy
            }
        }

        let payload = SubRadarBackupPayload(
            exportedAt: Date(),
            includesSecrets: includeSecrets,
            categories: categories,
            templates: templates,
            subscriptions: subscriptions,
            billingRecords: records
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(payload)
    }

    @discardableResult
    public func restoreJSONBackup(
        data: Data,
        into repository: SubscriptionRepositoryProtocol
    ) async throws -> BackupRestoreStats {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(SubRadarBackupPayload.self, from: data)

        for category in payload.categories {
            try await repository.saveCategory(category)
        }
        for template in payload.templates {
            try await repository.saveTemplate(template)
        }

        let recordsBySub = Dictionary(grouping: payload.billingRecords, by: \.subscriptionId)
        for sub in payload.subscriptions {
            let subRecords = recordsBySub[sub.id] ?? []
            try await repository.saveSubscription(sub, initialRecords: subRecords)
        }

        return BackupRestoreStats(
            restoredCategories: payload.categories.count,
            restoredTemplates: payload.templates.count,
            restoredSubscriptions: payload.subscriptions.count,
            restoredRecords: payload.billingRecords.count
        )
    }

    private func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }
}
