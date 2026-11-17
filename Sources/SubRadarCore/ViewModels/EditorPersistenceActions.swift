import Foundation
import Observation

extension EditorViewModel {
    // MARK: - 保存落盘

    @discardableResult
    public func save(baseCurrency: String = "CNY") async throws -> SubscriptionItem {
        validationErrorMessage = nil
        isSaving = true
        defer { isSaving = false }

        var topUpAmountsToSave: [Decimal] = []
        if !isEditing && isApiBalanceTemplate {
            guard let topUpCount = Int(apiTopUpCountText.trimmingCharacters(in: .whitespacesAndNewlines)),
                topUpCount >= 1
            else {
                validationErrorMessage = "请输入大于 0 的充值次数"
                throw SubscriptionValidationError.invalidCustomCycleDays
            }
            guard let resolvedAmounts = resolvedAPITopUpAmounts(allowZeroFallback: false) else {
                validationErrorMessage =
                    isAPITopUpAverageMode ? "请输入合法的充值总额" : "请填写每一次充值的合法金额"
                throw SubscriptionValidationError.negativePrice
            }
            topUpAmountsToSave = resolvedAmounts
        } else {
            guard Decimal(string: priceText.trimmingCharacters(in: .whitespacesAndNewlines)) != nil else {
                validationErrorMessage = isApiBalanceTemplate ? "请输入合法的充值金额" : "请输入合法的购买价格"
                throw SubscriptionValidationError.negativePrice
            }
        }

        let effectiveItemPrice: Decimal =
            (!isEditing && isApiBalanceTemplate)
            ? topUpAmountsToSave.reduce(0, +)
            : parsedPrice

        let trimmedRenewal = renewalPriceText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !isApiBalanceTemplate && billingCycleType != .oneTime && !trimmedRenewal.isEmpty
            && Decimal(string: trimmedRenewal) == nil
        {
            validationErrorMessage = "请输入合法的续期价格"
            throw SubscriptionValidationError.negativePrice
        }

        let resolvedMode: RenewalMode = (billingCycleType == .oneTime) ? .manual : renewalMode
        let item = SubscriptionItem(
            id: subscriptionId,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            categoryId: selectedCategoryId,
            templateId: selectedTemplateId,
            iconData: iconData,
            price: effectiveItemPrice,
            renewalPrice: parsedRenewalPrice,
            currency: currency,
            billingCycleType: billingCycleType,
            billingCycleDays: parsedCustomDays,
            startDate: startDate,
            nextRenewalDate: billingCycleType == .oneTime ? startDate : nextRenewalDate,
            autoRenew: resolvedMode == .automatic,
            renewalMode: resolvedMode,
            customRenewalNote: resolvedMode == .custom
                ? customRenewalNote.trimmingCharacters(in: .whitespacesAndNewlines) : "",
            status: status,
            reminderDaysBefore: reminderDaysBefore,
            notes: notes,
            customFields: customFields.enumerated().map { idx, f in
                var copy = f
                copy.sortOrder = idx
                return copy
            },
            createdAt: existingItem?.createdAt ?? Date(),
            updatedAt: Date()
        )

        do {
            try item.validate()
        } catch {
            validationErrorMessage = error.userFacingMessage
            throw error
        }

        var initialRecords: [BillingRecord] = []
        if !isEditing && isApiBalanceTemplate {
            let count = topUpAmountsToSave.count
            let totalPositive = topUpAmountsToSave.contains { $0 > 0 }
            if totalPositive {
                await container.exchangeRateService.prefetchRates(
                    from: item.currency,
                    to: baseCurrency,
                    startDate: item.startDate,
                    endDate: item.startDate
                )
                let rate = await container.exchangeRateService.rate(
                    from: item.currency, to: baseCurrency, on: item.startDate)
                for (idx, amount) in topUpAmountsToSave.enumerated() where amount > 0 {
                    let billedAt =
                        Calendar.current.date(byAdding: .minute, value: -idx, to: item.startDate) ?? item.startDate
                    initialRecords.append(
                        BillingRecord(
                            subscriptionId: item.id,
                            amount: amount,
                            currency: item.currency,
                            baseCurrencyAmount: amount * rate,
                            billedAt: billedAt,
                            source: .manualLedger,
                            kind: .topUp,
                            note: count > 1 ? "初始充值（第 \(idx + 1)/\(count) 次）" : "初始充值"
                        )
                    )
                }
            }
        } else if !isEditing && includeHistoricalBilling {
            await container.exchangeRateService.prefetchRates(
                from: item.currency,
                to: baseCurrency,
                startDate: item.startDate,
                endDate: item.nextRenewalDate
            )
            let rateService = container.exchangeRateService
            initialRecords = await container.billingEngine.generateHistoricalRecords(
                for: item,
                endDate: item.nextRenewalDate
            ) { date, srcCurrency in
                await rateService.rate(from: srcCurrency, to: baseCurrency, on: date)
            }
        } else if !isEditing && manualHistoryEntries.isEmpty && effectiveItemPrice > 0 {
            let rate = await container.exchangeRateService.rate(
                from: item.currency, to: baseCurrency, on: item.startDate)
            initialRecords = [
                BillingRecord(
                    subscriptionId: item.id,
                    amount: effectiveItemPrice,
                    currency: item.currency,
                    baseCurrencyAmount: effectiveItemPrice * rate,
                    billedAt: item.startDate,
                    source: .initialPurchase,
                    kind: .charge,
                    note: "初始购买记录"
                )
            ]
        }

        if !isApiBalanceTemplate && !manualHistoryEntries.isEmpty {
            let manualRecords = try await buildValidatedManualHistoryRecords(
                subscriptionId: item.id,
                baseCurrency: baseCurrency
            )
            initialRecords.append(contentsOf: manualRecords)
        }

        try await container.repository.saveSubscription(item, initialRecords: initialRecords)
        if !isApiBalanceTemplate {
            manualHistoryEntries.removeAll()
        }
        await container.notificationService.scheduleReminder(for: item)
        return item
    }
}
