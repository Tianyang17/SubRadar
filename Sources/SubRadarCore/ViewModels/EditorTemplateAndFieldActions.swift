import Foundation
import Observation

extension EditorViewModel {
    public func switchTemplate(to templateId: UUID, resetSchemaFields: Bool = false) {
        let previousTemplateId = selectedTemplateId
        selectedTemplateId = templateId
        balanceProbeStatusMessage = nil
        balanceProbeIsError = false

        if !isEditing {
            if templateId == TemplateDefinition.BuiltinID.apiBalance {
                billingCycleType = .oneTime
                billingCycleIntervalText = "1"
                autoRenew = false
                includeHistoricalBilling = false
                renewalPriceText = ""
                hasEditedRenewalPrice = false
                nextRenewalDate = startDate
            } else if previousTemplateId == TemplateDefinition.BuiltinID.apiBalance && billingCycleType == .oneTime {
                billingCycleType = .annually
                billingCycleIntervalText = "1"
                autoRenew = true
                if let computed = BillingCycleType.annually.nextDate(from: startDate, customDays: nil) {
                    nextRenewalDate = computed
                }
            }
        }

        guard let template = TemplatePresetManager.template(for: templateId, from: templates) else {
            return
        }

        // 切换模版时，保留用户手工填写的同语义字段与额外自定义字段；基础设施(VPS/域名)互转时保留供应商面板地址，其余跨模版切换清除先前预置自动填表值
        let allKnownKeys = TemplatePresetManager.allKnownSchemaKeys(including: templates)
        let existingByKey = Dictionary(uniqueKeysWithValues: customFields.map { ($0.key, $0) })
        let isSameTemplate = previousTemplateId == templateId
        let infraTemplates: Set<UUID> = [TemplateDefinition.BuiltinID.vps, TemplateDefinition.BuiltinID.domain]
        let allowAutoFilledCarryOver =
            infraTemplates.contains(previousTemplateId)
            && infraTemplates.contains(templateId)
            && (lastAutoFilledPresetGroup == nil || lastAutoFilledPresetGroup == .infrastructure)
        var merged: [CustomField] = template.defaultFields.enumerated().map { idx, schema in
            if !resetSchemaFields {
                if var old = existingByKey[schema.key] {
                    let isUneditedPresetValue =
                        !isSameTemplate && !allowAutoFilledCarryOver && autoFilledFieldValues[schema.key] == old.value
                    old.label = schema.label
                    old.type = schema.type
                    old.sortOrder = idx
                    if isUneditedPresetValue {
                        old.value = schema.defaultValue
                    } else if old.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                        !schema.defaultValue.isEmpty
                    {
                        old.value = schema.defaultValue
                    }
                    return old
                }
                if let carried = semanticCarryOverValue(
                    for: schema.key,
                    from: existingByKey,
                    allowAutoFilledCarryOver: allowAutoFilledCarryOver
                ) {
                    var instantiated = schema.instantiate(subscriptionId: subscriptionId, sortOrder: idx)
                    instantiated.value = carried
                    return instantiated
                }
            }
            return schema.instantiate(subscriptionId: subscriptionId, sortOrder: idx)
        }

        if resetSchemaFields {
            autoFilledFieldValues.removeAll()
        } else if !isSameTemplate && !allowAutoFilledCarryOver {
            autoFilledFieldValues.removeAll()
        } else if allowAutoFilledCarryOver {
            for field in merged where autoFilledFieldValues.values.contains(field.value) {
                autoFilledFieldValues[field.key] = field.value
            }
        }

        let userAdded = customFields.filter {
            !allKnownKeys.contains($0.key) && !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        for var extra in userAdded {
            extra.sortOrder = merged.count
            merged.append(extra)
        }
        let existingAccountDetail = resetSchemaFields ? nil : existingByKey["account_source_detail"]?.value
        let existingPurchaseDetail = resetSchemaFields ? nil : existingByKey["purchase_source_detail"]?.value
        customFields = Self.normalizedDynamicFields(
            in: merged,
            templateId: templateId,
            subscriptionId: subscriptionId,
            preferredAccountDetail: existingAccountDetail,
            preferredPurchaseDetail: existingPurchaseDetail
        )
    }

    private func semanticCarryOverValue(
        for targetKey: String,
        from existingByKey: [String: CustomField],
        allowAutoFilledCarryOver: Bool
    ) -> String? {
        let groups: [[String]] = [
            ["panel_url", "manage_url", "download_url", "console_url"],
            ["account", "account_email", "username"],
            ["account_password", "ssh_password"],
            ["account_source", "purchase_source"],
            ["account_source_detail", "purchase_source_detail"]
        ]
        guard let group = groups.first(where: { $0.contains(targetKey) }) else { return nil }
        for sourceKey in group where sourceKey != targetKey {
            if let value = existingByKey[sourceKey]?.value,
                !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                allowAutoFilledCarryOver || autoFilledFieldValues[sourceKey] != value
            {
                return value
            }
        }
        return nil
    }

    /// 切换「主机与域名」子类：主机 / VPS vs 域名资产（保留官网等跨模版已填内容）
    public func applyInfrastructureKindChoice(isHost: Bool) {
        let targetTemplate = isHost ? TemplateDefinition.BuiltinID.vps : TemplateDefinition.BuiltinID.domain
        let targetCategory =
            isHost ? SubscriptionCategory.BuiltinID.cloudInfra : SubscriptionCategory.BuiltinID.domainNetwork
        if categories.contains(where: { $0.id == targetCategory }) {
            selectedCategoryId = targetCategory
        }
        switchTemplate(to: targetTemplate, resetSchemaFields: false)
    }

    /// 切换 AI API 平台适配器预设并联动推荐端点、解析规则与控制台地址
    public func updateAPIProviderPreset(_ preset: APIBalanceProviderPreset) {
        setFieldValue(preset.rawValue, forKey: "provider_preset", label: "API 平台")
        if preset != .custom {
            setFieldValue(preset.defaultEndpoint, forKey: "api_endpoint", label: "余额接口地址")
            setFieldValue(preset.defaultParseRule, forKey: "parse_rule", label: "解析规则")
            setFieldValue(preset.defaultConsoleURL, forKey: "console_url", label: "API 控制台")
            if priceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                currency = preset.defaultCurrency
            }
        }
        balanceProbeStatusMessage = nil
        balanceProbeIsError = false
    }

    /// 立即在编辑弹窗内查询当前配置的 API 账户余额，并回写到只读余额字段
    public func probeCurrentAPIBalance() async {
        isProbingBalance = true
        balanceProbeStatusMessage = nil
        balanceProbeIsError = false
        defer { isProbingBalance = false }

        let tempItem = SubscriptionItem(
            id: subscriptionId,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "API 账户" : name,
            categoryId: selectedCategoryId,
            templateId: selectedTemplateId,
            iconData: iconData,
            price: parsedPrice,
            renewalPrice: parsedRenewalPrice,
            currency: currency,
            billingCycleType: billingCycleType,
            billingCycleDays: parsedCustomDays,
            startDate: startDate,
            nextRenewalDate: nextRenewalDate,
            autoRenew: autoRenew,
            status: status,
            reminderDaysBefore: reminderDaysBefore,
            notes: notes,
            customFields: customFields
        )

        do {
            let result = try await container.apiBalanceService.fetchBalance(for: tempItem)
            let formatted = NSDecimalNumber(decimal: result.balance).stringValue
            setFieldValue(formatted, forKey: "current_balance", label: "当前账户余额")
            if !result.currency.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                currency = result.currency
            }
            balanceProbeStatusMessage = "查询成功：\(result.currency) \(formatted)"
            balanceProbeIsError = false
        } catch {
            balanceProbeStatusMessage = "查询失败：\(error.userFacingMessage)"
            balanceProbeIsError = true
        }
    }

    func setFieldValue(_ value: String, forKey key: String, label: String) {
        if let idx = customFields.firstIndex(where: { $0.key == key }) {
            customFields[idx].value = value
        } else {
            customFields.append(
                CustomField(
                    subscriptionId: subscriptionId,
                    key: key,
                    label: label,
                    type: .text,
                    value: value,
                    sortOrder: customFields.count
                )
            )
        }
    }

    public func addCustomField(label: String, type: CustomFieldType) {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let key = "custom_\(UUID().uuidString.prefix(8).lowercased())"
        let field = CustomField(
            subscriptionId: subscriptionId,
            key: key,
            label: trimmed,
            type: type,
            value: "",
            sortOrder: customFields.count
        )
        customFields.append(field)
        reindexCustomFieldsSortOrder()
    }

    public func removeCustomField(id: UUID) {
        customFields.removeAll { $0.id == id }
        reindexCustomFieldsSortOrder()
    }

    /// 拖拽重排订阅详情字段，并重新连续编排 `sortOrder`
    public func moveCustomField(fromId: UUID, toTargetId: UUID) {
        guard fromId != toTargetId,
            let fromIndex = customFields.firstIndex(where: { $0.id == fromId }),
            let targetIndex = customFields.firstIndex(where: { $0.id == toTargetId })
        else {
            return
        }
        let moved = customFields.remove(at: fromIndex)
        customFields.insert(moved, at: targetIndex)
        reindexCustomFieldsSortOrder()
    }

    private func reindexCustomFieldsSortOrder() {
        for idx in customFields.indices {
            customFields[idx].sortOrder = idx
        }
    }
}
