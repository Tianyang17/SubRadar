import Foundation
import Observation

extension EditorViewModel {
    // MARK: - 五维一体图标与预设快速导入

    public func applySoftwarePreset(
        _ preset: PopularSoftwarePreset,
        iconData: Data? = nil,
        overrideTemplateId: UUID? = nil,
        overrideCategoryId: UUID? = nil
    ) {
        iconErrorMessage = nil
        balanceProbeStatusMessage = nil
        balanceProbeIsError = false
        clearUntouchedAutoFilledFields()
        name = preset.name
        lastAutoFilledPresetName = preset.name
        lastAutoFilledPresetGroup = preset.group
        self.iconData = iconData ?? PopularSoftwarePresetManager.bundledIconData(for: preset)
        let targetTemplateId = overrideTemplateId ?? preset.suggestedTemplateId
        let targetCategoryId = overrideCategoryId ?? preset.suggestedCategoryId

        if !isEditing {
            if categories.contains(where: { $0.id == targetCategoryId }) {
                selectedCategoryId = targetCategoryId
            }
            switchTemplate(to: targetTemplateId, resetSchemaFields: true)
            if targetTemplateId == TemplateDefinition.BuiltinID.apiBalance {
                billingCycleType = .oneTime
                billingCycleIntervalText = "1"
                autoRenew = false
                includeHistoricalBilling = false
                apiTopUpCountText = "1"
                apiTopUpAmounts = [""]
                isAPITopUpAverageMode = false
                apiTopUpTotalText = ""
                nextRenewalDate = startDate
            } else {
                billingCycleType = preset.defaultBillingCycle
                let (_, presetIntervalCount) = preset.defaultBillingCycle.normalizedUnitAndCount(intervalCount: nil)
                billingCycleIntervalText = String(presetIntervalCount)
                autoRenew = (billingCycleType != .oneTime)
                if billingCycleType != .oneTime,
                    let computedNext = billingCycleType.nextDate(from: startDate, customDays: parsedCustomDays)
                {
                    nextRenewalDate = computedNext
                }
            }
            if priceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                currency = preset.defaultCurrency
                lastAutoFilledCurrency = preset.defaultCurrency
            }
        }
        for index in customFields.indices {
            let key = customFields[index].key
            if let value = preset.presetFieldValues[key] {
                customFields[index].value = value
                autoFilledFieldValues[key] = value
            }
        }
        if targetTemplateId == TemplateDefinition.BuiltinID.domain {
            if let registrarIdx = customFields.firstIndex(where: { $0.key == "registrar" }),
                customFields[registrarIdx].value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            {
                customFields[registrarIdx].value = preset.name
                autoFilledFieldValues["registrar"] = preset.name
            }
            if let urlIdx = customFields.firstIndex(where: { $0.key == "manage_url" }),
                customFields[urlIdx].value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                let fallbackPanel = preset.presetFieldValues["panel_url"]
            {
                customFields[urlIdx].value = fallbackPanel
                autoFilledFieldValues["manage_url"] = fallbackPanel
            }
        }
    }

    func clearUntouchedAutoFilledFields() {
        let defaultsByKey: [String: String] =
            if let template = TemplatePresetManager.template(for: selectedTemplateId, from: templates) {
                Dictionary(uniqueKeysWithValues: template.defaultFields.map { ($0.key, $0.defaultValue) })
            } else {
                [:]
            }
        for idx in customFields.indices {
            let key = customFields[idx].key
            if let autoVal = autoFilledFieldValues[key], customFields[idx].value == autoVal {
                customFields[idx].value = defaultsByKey[key] ?? ""
            }
        }
        autoFilledFieldValues.removeAll()
        if !isEditing,
            priceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            let autoCurr = lastAutoFilledCurrency,
            currency == autoCurr
        {
            currency = baseline.currency
        }
        lastAutoFilledCurrency = nil
        lastAutoFilledPresetGroup = nil
    }

    @discardableResult
    public func createCategoryInline(
        name: String,
        iconSymbol: String,
        colorKey: CategoryColorKey
    ) async throws -> SubscriptionCategory {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SubscriptionValidationError.emptyName
        }
        let nextOrder = (categories.map(\.sortOrder).max() ?? 0) + 1
        let category = SubscriptionCategory(
            name: trimmed,
            iconSymbol: iconSymbol,
            colorKey: colorKey,
            isBuiltin: false,
            sortOrder: nextOrder
        )
        try await container.repository.saveCategory(category)
        let fetched = try await container.repository.fetchCategories()
        categories = fetched.isEmpty ? [category] : fetched
        selectedCategoryId = category.id
        return category
    }

    public func importLocalApp(at url: URL) {
        iconErrorMessage = nil
        clearUntouchedAutoFilledFields()
        do {
            let extracted = try container.iconService.extractLocalAppInfo(at: url)
            name = extracted.name
            iconData = extracted.iconData
            lastAutoFilledPresetName = nil
        } catch {
            iconErrorMessage = error.userFacingMessage
        }
    }

    public func searchAppStore() async {
        let kw = appStoreKeyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !kw.isEmpty else {
            appStoreResults = []
            return
        }
        isFetchingIcon = true
        iconErrorMessage = nil
        defer { isFetchingIcon = false }

        do {
            appStoreResults = try await container.iconService.searchAppStore(keyword: kw, country: "cn", limit: 6)
        } catch {
            iconErrorMessage = error.userFacingMessage
        }
    }

    public func selectAppStoreItem(_ item: AppStoreSearchItem) async {
        isFetchingIcon = true
        iconErrorMessage = nil
        defer { isFetchingIcon = false }

        clearUntouchedAutoFilledFields()
        name = item.trackName
        lastAutoFilledPresetName = nil
        if let url = item.bestArtworkURL {
            do {
                iconData = try await container.iconService.downloadAndNormalizeIcon(from: url)
                appStoreResults = []
            } catch {
                iconData = nil
                iconErrorMessage = error.userFacingMessage
            }
        } else {
            iconData = nil
            appStoreResults = []
        }
    }

    public func fetchFavicon() async {
        let target = faviconURLInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else { return }
        isFetchingIcon = true
        iconErrorMessage = nil
        defer { isFetchingIcon = false }

        do {
            iconData = try await container.iconService.fetchFavicon(for: target)
        } catch {
            iconErrorMessage = error.userFacingMessage
        }
    }

    public func importUploadedImageData(_ rawData: Data) {
        iconErrorMessage = nil
        do {
            iconData = try container.iconService.normalizeImageData(rawData, targetDimension: 256)
        } catch {
            iconErrorMessage = error.userFacingMessage
        }
    }
}
