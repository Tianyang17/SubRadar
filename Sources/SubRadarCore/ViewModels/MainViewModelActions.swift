import Foundation
import Observation

/// 侧边栏导航项
extension MainViewModel {
    public func renewSubscription(_ item: SubscriptionItem, actualPrice: Decimal? = nil) async {
        let now = Date()
        let rate = await container.exchangeRateService.rate(from: item.currency, to: baseCurrency, on: now)
        let (updated, record) = container.billingEngine.processRenewal(
            for: item,
            actualPrice: actualPrice,
            renewedAt: now,
            source: .manualRenew,
            rateToBase: rate
        )

        do {
            try await container.repository.saveSubscription(updated, initialRecords: [])
            try await container.repository.addBillingRecord(record)
            await container.notificationService.scheduleReminder(for: updated)
            await loadAll()
            selectedSubscriptionId = updated.id
            await loadRecordsForSelected()
            showToast("已完成续订，并累加 \(SubRadarFormatter.formatMoney(record.amount, currency: record.currency))")
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    public func deleteSubscription(_ item: SubscriptionItem) async {
        do {
            try await container.repository.deleteSubscription(id: item.id)
            await container.notificationService.cancelReminder(for: item.id)
            if selectedSubscriptionId == item.id {
                selectedSubscriptionId = nil
            }
            await loadAll()
            showToast("已删除「\(item.name)」")
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    // MARK: - 手动补录 / 充值 / 退款与单条流水维护 & 状态切换

    public func addManualBillingRecord(
        for item: SubscriptionItem,
        amount: Decimal,
        currency: String? = nil,
        kind: BillingRecordKind,
        billedAt: Date = Date(),
        note: String = ""
    ) async {
        let resolvedCurrency = (currency ?? item.currency).uppercased()
        let rate = await container.exchangeRateService.rate(from: resolvedCurrency, to: baseCurrency, on: billedAt)
        let record = BillingRecord(
            subscriptionId: item.id,
            amount: max(0, amount),
            currency: resolvedCurrency,
            baseCurrencyAmount: max(0, amount) * rate,
            billedAt: billedAt,
            source: .manualLedger,
            kind: kind,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        do {
            try await container.repository.addBillingRecord(record)
            await loadAll()
            selectedSubscriptionId = item.id
            await loadRecordsForSelected()
            showToast(
                "已记录一笔「\(kind.displayName)」\(SubRadarFormatter.formatMoney(record.amount, currency: record.currency))")
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    public func updateBillingRecord(
        _ record: BillingRecord,
        newAmount: Decimal,
        currency: String,
        kind: BillingRecordKind,
        billedAt: Date,
        note: String
    ) async {
        let upper = currency.uppercased()
        let rate = await container.exchangeRateService.rate(from: upper, to: baseCurrency, on: billedAt)
        var updated = record
        updated.amount = max(0, newAmount)
        updated.currency = upper
        updated.baseCurrencyAmount = updated.amount * rate
        updated.kind = kind
        updated.billedAt = billedAt
        updated.note = note.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            try await container.repository.updateBillingRecord(updated)
            await loadAll()
            selectedSubscriptionId = record.subscriptionId
            await loadRecordsForSelected()
            showToast("已更新该笔流水记录")
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    public func deleteBillingRecord(_ record: BillingRecord) async {
        do {
            try await container.repository.deleteBillingRecord(id: record.id)
            await loadAll()
            selectedSubscriptionId = record.subscriptionId
            await loadRecordsForSelected()
            showToast("已删除该笔流水记录")
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    public func updateStatus(_ item: SubscriptionItem, to status: SubscriptionStatus) async {
        var updated = item
        updated.status = status
        updated.updatedAt = Date()
        do {
            try await container.repository.saveSubscription(updated, initialRecords: [])
            await container.notificationService.scheduleReminder(for: updated)
            await loadAll()
            selectedSubscriptionId = updated.id
            await loadRecordsForSelected()
            showToast("「\(item.name)」已标记为\(status.displayName)")
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    public func toggleSecretReveal(for fieldId: UUID) async {
        if revealedSecretFieldIds.contains(fieldId) {
            revealedSecretFieldIds.remove(fieldId)
            return
        }
        let authenticated = await container.secretStore.authenticateUser(reason: "验证身份以查看敏感字段")
        if authenticated {
            revealedSecretFieldIds.insert(fieldId)
        }
    }

    public func sendTestNotification() async -> NotificationDeliveryReport {
        let report = await container.notificationService.sendTestNotification(
            title: "SubRadar 通知连通测试",
            body: "如果你看到了这条系统通知，说明到期提醒与低余额告警通道已正常连通。"
        )
        showToast(report.detail)
        return report
    }

    public func showToast(_ message: String) {
        toastDismissTask?.cancel()
        toastMessage = message
        toastDismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            self?.toastMessage = nil
            self?.toastDismissTask = nil
        }
    }

    public func clearToast() {
        toastDismissTask?.cancel()
        toastDismissTask = nil
        toastMessage = nil
    }

    static func formatBalanceString(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 4
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "\(value)"
    }

    func recomputeMonthlyEstimate() async {
        var total = Decimal.zero
        let now = Date()
        for item in subscriptions
        where item.status == .active && item.billingCycleType != .oneTime && item.renewalMode != .doNotRenew {
            let rate = await container.exchangeRateService.rate(from: item.currency, to: baseCurrency, on: now)
            let basePrice = item.effectiveRenewalPrice * rate
            let monthlyFactor = item.billingCycleType.monthlyEquivalenceFactor(intervalCount: item.billingCycleDays)
            total += basePrice * monthlyFactor
        }
        monthlyEstimatedBaseSpend = total
    }

    func computeSpendSummary(for item: SubscriptionItem) async -> SubscriptionSpendSummary {
        let records = (try? await container.repository.fetchBillingRecords(for: item.id)) ?? []
        let targetCurrency = item.currency.uppercased()
        var convertedTotal = Decimal.zero
        var hasForeign = false
        var orderedCurrencies: [String] = []
        var totalsByCurrency: [String: Decimal] = [:]

        for record in records {
            let recCurrency = record.currency.uppercased()
            let signed = record.signedAmount
            if totalsByCurrency[recCurrency] == nil {
                orderedCurrencies.append(recCurrency)
            }
            totalsByCurrency[recCurrency, default: .zero] += signed

            if recCurrency == targetCurrency {
                convertedTotal += signed
            } else {
                hasForeign = true
                let rate = await container.exchangeRateService.rate(
                    from: recCurrency,
                    to: targetCurrency,
                    on: record.billedAt
                )
                convertedTotal += signed * rate
            }
        }

        let summaryText = SubRadarFormatter.formatGroupedCurrencySummary(
            orderedCurrencies.map { ($0, totalsByCurrency[$0] ?? .zero) }
        )
        return SubscriptionSpendSummary(
            convertedTotal: convertedTotal,
            hasForeignCurrencyRecords: hasForeign,
            originalCurrencySummaryText: summaryText
        )
    }
}
