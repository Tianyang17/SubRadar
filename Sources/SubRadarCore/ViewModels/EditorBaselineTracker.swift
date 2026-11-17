import Foundation

struct FieldSnapshot: Equatable {
    let key: String
    let label: String
    let type: CustomFieldType
    let value: String
}

struct EditorBaseline: Equatable {
    let name: String
    let categoryId: UUID
    let templateId: UUID
    let iconData: Data?
    let priceText: String
    let renewalPriceText: String
    let currency: String
    let billingCycleType: BillingCycleType
    let customCycleDaysText: String
    let startDateDay: Date
    let nextRenewalDateDay: Date
    let renewalMode: RenewalMode
    let customRenewalNote: String
    let status: SubscriptionStatus
    let reminderDaysBefore: Int
    let notes: String
    let fields: [FieldSnapshot]
}

extension EditorViewModel {
    var currentSnapshot: EditorBaseline {
        EditorBaseline(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            categoryId: selectedCategoryId,
            templateId: selectedTemplateId,
            iconData: iconData,
            priceText: priceText.trimmingCharacters(in: .whitespacesAndNewlines),
            renewalPriceText: renewalPriceText.trimmingCharacters(in: .whitespacesAndNewlines),
            currency: currency,
            billingCycleType: billingCycleType,
            customCycleDaysText: customCycleDaysText.trimmingCharacters(in: .whitespacesAndNewlines),
            startDateDay: Calendar.current.startOfDay(for: startDate),
            nextRenewalDateDay: Calendar.current.startOfDay(for: nextRenewalDate),
            renewalMode: renewalMode,
            customRenewalNote: customRenewalNote.trimmingCharacters(in: .whitespacesAndNewlines),
            status: status,
            reminderDaysBefore: reminderDaysBefore,
            notes: notes,
            fields: customFields.map {
                FieldSnapshot(key: $0.key, label: $0.label, type: $0.type, value: $0.value)
            }
        )
    }

    /// 表单是否存在尚未保存的修改（包含字段增删与内容编辑）
    public var hasUnsavedChanges: Bool {
        currentSnapshot != baseline || !manualHistoryEntries.isEmpty
    }

    /// 供二次确认弹窗展示的变更条目清单
    public var changeSummaryLines: [String] {
        let current = currentSnapshot
        var summary: [String] = []
        if current.name != baseline.name.trimmingCharacters(in: .whitespacesAndNewlines) {
            summary.append("订阅名称（\(current.name.isEmpty ? "已清空" : current.name)）")
        }
        if current.iconData != baseline.iconData {
            summary.append("订阅图标已更换")
        }
        if current.categoryId != baseline.categoryId {
            let catName = categories.first(where: { $0.id == current.categoryId })?.name ?? "新分类"
            summary.append("所属分类变更为「\(catName)」")
        }
        if current.templateId != baseline.templateId {
            let tmplName = templates.first(where: { $0.id == current.templateId })?.name ?? "新模版"
            summary.append("字段模版切换为「\(tmplName)」")
        }
        if current.priceText != baseline.priceText || current.currency != baseline.currency {
            summary.append("购买价格（\(current.currency) \(current.priceText)）")
        }
        if current.billingCycleType != .oneTime && current.renewalPriceText != baseline.renewalPriceText {
            let eff = current.renewalPriceText.isEmpty ? current.priceText : current.renewalPriceText
            summary.append("续期价格（\(current.currency) \(eff)）")
        }
        if current.billingCycleType != baseline.billingCycleType
            || current.customCycleDaysText != baseline.customCycleDaysText
        {
            summary.append(
                "付费频率（\(current.billingCycleType.formattedDisplayName(intervalCount: Int(current.customCycleDaysText)))）"
            )
        }
        if current.startDateDay != baseline.startDateDay || current.nextRenewalDateDay != baseline.nextRenewalDateDay {
            summary.append("起止与续订日期")
        }
        if current.renewalMode != baseline.renewalMode
            || (current.renewalMode == .custom
                && current.customRenewalNote
                    != baseline.customRenewalNote.trimmingCharacters(in: .whitespacesAndNewlines))
            || current.reminderDaysBefore != baseline.reminderDaysBefore
        {
            summary.append("续订方式或到期提醒策略")
        }
        if !manualHistoryEntries.isEmpty {
            summary.append("新增 \(manualHistoryEntries.count) 笔手动历史开销")
        }
        if current.notes != baseline.notes {
            summary.append("备注内容")
        }
        if current.fields != baseline.fields {
            let diffCount = current.fields.count - baseline.fields.count
            if diffCount > 0 {
                summary.append("订阅详情字段（新增 \(diffCount) 项并调整内容）")
            } else if diffCount < 0 {
                summary.append("订阅详情字段（移除 \(-diffCount) 项）")
            } else {
                summary.append("订阅详情字段内容已修改")
            }
        }
        return summary
    }
}
