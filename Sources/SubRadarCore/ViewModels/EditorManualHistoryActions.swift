import Foundation
import Observation

/// 编辑器内待写入的手动历史开销草稿条目
public struct EditorManualHistoryEntry: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var billedAt: Date
    public var amountText: String
    public var currency: String
    public var kind: BillingRecordKind
    public var note: String
    public var hasCustomDate: Bool

    /// 尚未填入金额/备注且未手动调整过日期的草稿视为「空白」
    public var isBlankDraft: Bool {
        amountText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !hasCustomDate
    }

    public init(
        id: UUID = UUID(),
        billedAt: Date = Date(),
        amountText: String = "",
        currency: String = "CNY",
        kind: BillingRecordKind = .charge,
        note: String = "",
        hasCustomDate: Bool = false
    ) {
        self.id = id
        self.billedAt = billedAt
        self.amountText = amountText
        self.currency = currency.uppercased()
        self.kind = kind
        self.note = note
        self.hasCustomDate = hasCustomDate
    }
}

extension EditorViewModel {
    public func addManualHistoryEntry(
        billedAt: Date = Date(),
        amountText: String = "",
        currency: String? = nil,
        kind: BillingRecordKind = .charge,
        note: String = ""
    ) {
        manualHistoryEntries.insert(
            EditorManualHistoryEntry(
                billedAt: billedAt,
                amountText: amountText,
                currency: currency ?? self.currency,
                kind: kind,
                note: note
            ),
            at: 0
        )
        sortManualHistoryEntries()
    }

    public func updateManualHistoryDate(id: UUID, to newDate: Date) {
        guard let idx = manualHistoryEntries.firstIndex(where: { $0.id == id }) else { return }
        manualHistoryEntries[idx].billedAt = newDate
        manualHistoryEntries[idx].hasCustomDate = true
        sortManualHistoryEntries()
    }

    /// 列表顺序从上到下固定为：空白草稿 -> 最近日期 -> 最远日期
    public func sortManualHistoryEntries() {
        let calendar = Calendar.current
        manualHistoryEntries = manualHistoryEntries.enumerated().sorted { lhs, rhs in
            let leftBlank = lhs.element.isBlankDraft
            let rightBlank = rhs.element.isBlankDraft
            if leftBlank != rightBlank {
                return leftBlank
            }
            if leftBlank && rightBlank {
                return lhs.offset < rhs.offset
            }
            let leftDay = calendar.startOfDay(for: lhs.element.billedAt)
            let rightDay = calendar.startOfDay(for: rhs.element.billedAt)
            if leftDay != rightDay {
                return leftDay > rightDay
            }
            return lhs.offset < rhs.offset
        }
        .map(\.element)
    }

    public func removeManualHistoryEntry(_ id: UUID) {
        manualHistoryEntries.removeAll { $0.id == id }
    }

    public var manualHistoryEstimatedTotal: Decimal {
        manualHistoryEntries.reduce(Decimal.zero) { acc, entry in
            let trimmed = entry.amountText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let amt = Decimal(string: trimmed), amt > 0 else { return acc }
            switch entry.kind {
            case .charge, .topUp: return acc + amt
            case .refund: return acc - amt
            }
        }
    }

    public var manualHistoryNetSummaryText: String {
        var orderedCurrencies: [String] = []
        var totalsByCurrency: [String: Decimal] = [:]

        for entry in manualHistoryEntries {
            let trimmed = entry.amountText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let amt = Decimal(string: trimmed), amt > 0 else { continue }
            let code = entry.currency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            let resolvedCode = code.isEmpty ? currency.uppercased() : code
            if totalsByCurrency[resolvedCode] == nil {
                orderedCurrencies.append(resolvedCode)
            }
            let signed = entry.kind == .refund ? -amt : amt
            totalsByCurrency[resolvedCode, default: .zero] += signed
        }

        guard !orderedCurrencies.isEmpty else {
            let fallbackCode = manualHistoryEntries.first?.currency ?? currency
            return SubRadarFormatter.formatMoney(.zero, currency: fallbackCode)
        }

        return SubRadarFormatter.formatGroupedCurrencySummary(
            orderedCurrencies.map { code in
                (currency: code, amount: totalsByCurrency[code] ?? .zero)
            }
        )
    }

    func buildValidatedManualHistoryRecords(
        subscriptionId: UUID,
        baseCurrency: String
    ) async throws -> [BillingRecord] {
        var validEntries: [(EditorManualHistoryEntry, Decimal)] = []
        for entry in manualHistoryEntries {
            let trimmed = entry.amountText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            guard let amount = Decimal(string: trimmed), amount >= 0 else {
                validationErrorMessage = "请输入合法的历史开销金额（不能为负数或非数字）"
                throw SubscriptionValidationError.negativePrice
            }
            if amount > 0 {
                validEntries.append((entry, amount))
            }
        }
        guard !validEntries.isEmpty else { return [] }

        var records: [BillingRecord] = []
        for (entry, amount) in validEntries {
            let rate = await container.exchangeRateService.rate(
                from: entry.currency,
                to: baseCurrency,
                on: entry.billedAt
            )
            let trimmedNote = entry.note.trimmingCharacters(in: .whitespacesAndNewlines)
            records.append(
                BillingRecord(
                    subscriptionId: subscriptionId,
                    amount: amount,
                    currency: entry.currency,
                    baseCurrencyAmount: amount * rate,
                    billedAt: entry.billedAt,
                    source: .manualLedger,
                    kind: entry.kind,
                    note: trimmedNote.isEmpty ? "手动历史\(entry.kind.displayName)" : trimmedNote
                )
            )
        }
        return records
    }
}
