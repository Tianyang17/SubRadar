import Foundation

extension EditorViewModel {
    private static let appStoreRemovedSoftwareKeys: Set<String> = [
        "account_password",
        "license_key",
        "device_limit"
    ]

    /// 更新账号来源，并在选中「渠道代充」或「第三方合租」时联动维护「具体渠道来源」字段
    public func updateAccountSource(_ newValue: String) {
        let existingDetail = customFields.first(where: { $0.key == "account_source_detail" })?.value
        setFieldValue(newValue, forKey: "account_source", label: "来源")
        customFields = Self.normalizedDynamicFields(
            in: customFields,
            templateId: selectedTemplateId,
            subscriptionId: subscriptionId,
            preferredAccountDetail: existingDetail
        )
    }

    /// 更新软件购买来源：
    /// 1. 选中「渠道代充」/「第三方合租」时紧随下方动态维护「来源」明细字段（切走直接清除）；
    /// 2. 选中「App Store」时直接清除密码、激活码与授权设备数（切回非 App Store 时重建空白字段）。
    public func updatePurchaseSource(_ newValue: String) {
        let existingDetail = customFields.first(where: { $0.key == "purchase_source_detail" })?.value
        setFieldValue(newValue, forKey: "purchase_source", label: "购买来源")
        customFields = Self.normalizedDynamicFields(
            in: customFields,
            templateId: selectedTemplateId,
            subscriptionId: subscriptionId,
            preferredPurchaseDetail: existingDetail
        )
    }

    static func normalizedDynamicFields(
        in fields: [CustomField],
        templateId: UUID,
        subscriptionId: UUID,
        preferredAccountDetail: String? = nil,
        preferredPurchaseDetail: String? = nil
    ) -> [CustomField] {
        var result = syncedSourceDetailField(
            in: fields,
            subscriptionId: subscriptionId,
            sourceKey: "account_source",
            detailKey: "account_source_detail",
            detailLabel: "具体渠道来源",
            preferredDetailValue: preferredAccountDetail
        )
        result = syncedSourceDetailField(
            in: result,
            subscriptionId: subscriptionId,
            sourceKey: "purchase_source",
            detailKey: "purchase_source_detail",
            detailLabel: "来源",
            preferredDetailValue: preferredPurchaseDetail
        )
        result = syncedSoftwareLicenseFields(
            in: result,
            templateId: templateId,
            subscriptionId: subscriptionId
        )
        for idx in result.indices {
            result[idx].sortOrder = idx
        }
        return result
    }

    private static func syncedSourceDetailField(
        in fields: [CustomField],
        subscriptionId: UUID,
        sourceKey: String,
        detailKey: String,
        detailLabel: String,
        preferredDetailValue: String?
    ) -> [CustomField] {
        var result = fields
        let existingDetail = result.first(where: { $0.key == detailKey })
        let sourceValue =
            result.first(where: { $0.key == sourceKey })?
            .value.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let needsDetail = FieldOptionCatalog.requiresDetailAccountSources.contains(sourceValue)

        result.removeAll { $0.key == detailKey }
        if needsDetail, let updatedSourceIndex = result.firstIndex(where: { $0.key == sourceKey }) {
            let detailField = CustomField(
                id: existingDetail?.id ?? UUID(),
                subscriptionId: subscriptionId,
                key: detailKey,
                label: detailLabel,
                type: .text,
                value: existingDetail?.value ?? preferredDetailValue ?? "",
                sortOrder: updatedSourceIndex + 1
            )
            result.insert(detailField, at: updatedSourceIndex + 1)
        }
        return result
    }

    private static func syncedSoftwareLicenseFields(
        in fields: [CustomField],
        templateId: UUID,
        subscriptionId: UUID
    ) -> [CustomField] {
        guard templateId == TemplateDefinition.BuiltinID.softwareLicense else {
            return fields
        }
        var result = fields
        let sourceValue =
            result.first(where: { $0.key == "purchase_source" })?
            .value.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if sourceValue == "App Store" {
            result.removeAll { appStoreRemovedSoftwareKeys.contains($0.key) }
            return result
        }

        guard
            let softwareTemplate = TemplatePresetManager.template(
                for: TemplateDefinition.BuiltinID.softwareLicense,
                from: TemplatePresetManager.builtinTemplates
            )
        else {
            return result
        }

        let schemaOrder = Dictionary(
            uniqueKeysWithValues: softwareTemplate.defaultFields.enumerated().map { ($1.key, $0) }
        )
        for schema in softwareTemplate.defaultFields where appStoreRemovedSoftwareKeys.contains(schema.key) {
            guard !result.contains(where: { $0.key == schema.key }) else { continue }
            let targetRank = schemaOrder[schema.key] ?? Int.max
            let insertAt =
                result.firstIndex { existing in
                    guard let existingRank = schemaOrder[existing.key] else { return false }
                    return existingRank > targetRank
                } ?? result.endIndex
            result.insert(schema.instantiate(subscriptionId: subscriptionId, sortOrder: insertAt), at: insertAt)
        }
        return result
    }
}
