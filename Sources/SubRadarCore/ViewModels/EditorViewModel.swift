import Foundation
import Observation

/// 新建 / 编辑订阅表单视图模型
@Observable
@MainActor
public final class EditorViewModel {
    let container: AppContainer
    let templates: [TemplateDefinition]
    public internal(set) var categories: [SubscriptionCategory]
    let existingItem: SubscriptionItem?
    let subscriptionId: UUID

    public var isEditing: Bool { existingItem != nil }

    public var name: String = ""
    public var selectedCategoryId: UUID
    public var selectedTemplateId: UUID
    public var iconData: Data?
    public var priceText: String = ""
    public var renewalPriceText: String = ""
    public var currency: String = "CNY"
    public var billingCycleType: BillingCycleType = .annually
    public var billingCycleIntervalText: String = "1"
    public var customCycleDaysText: String {
        get { billingCycleIntervalText }
        set { billingCycleIntervalText = newValue }
    }
    public var startDate: Date = Date()
    public var nextRenewalDate: Date
    public var renewalMode: RenewalMode = .automatic
    public var customRenewalNote: String = ""
    public var autoRenew: Bool {
        get { renewalMode == .automatic }
        set { renewalMode = newValue ? .automatic : .manual }
    }
    public var status: SubscriptionStatus = .active
    public var reminderDaysBefore: Int = 3
    public var notes: String = ""
    public var customFields: [CustomField] = []

    /// 新建时是否启用历史计费自动推算累加
    public var includeHistoricalBilling: Bool = false
    /// 手动添加的历史开销草稿列表
    public var manualHistoryEntries: [EditorManualHistoryEntry] = []

    /// AI API 账户专用：充值次数、逐笔金额 / 按总额均分状态与实时余额查询
    public var apiTopUpCountText: String = "1"
    public var apiTopUpAmounts: [String] = [""]
    public var isAPITopUpAverageMode: Bool = false
    public var apiTopUpTotalText: String = ""
    public var isProbingBalance: Bool = false
    public var balanceProbeStatusMessage: String?
    public var balanceProbeIsError: Bool = false

    public var isApiBalanceTemplate: Bool {
        selectedTemplateId == TemplateDefinition.BuiltinID.apiBalance
    }

    public var isInfrastructureTemplate: Bool {
        selectedTemplateId == TemplateDefinition.BuiltinID.vps
            || selectedTemplateId == TemplateDefinition.BuiltinID.domain
    }

    public var parsedAPITopUpCount: Int {
        let raw = Int(apiTopUpCountText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 1
        return max(1, min(100, raw))
    }

    public var estimatedTotalTopUpAmount: Decimal {
        previewAPITopUpAmounts.reduce(0, +)
    }

    public var previewAPITopUpAmounts: [Decimal] {
        resolvedAPITopUpAmounts(allowZeroFallback: true) ?? []
    }

    public var averageAPITopUpPerCharge: Decimal {
        let count = parsedAPITopUpCount
        guard count > 0 else { return 0 }
        let items = previewAPITopUpAmounts
        guard !items.isEmpty else { return 0 }
        return items.reduce(0, +) / Decimal(count)
    }

    // 四维图标导入辅助状态
    public var appStoreKeyword: String = ""
    public var appStoreResults: [AppStoreSearchItem] = []
    public var faviconURLInput: String = ""
    public var isFetchingIcon: Bool = false
    public var iconErrorMessage: String?
    public var validationErrorMessage: String?
    public var isSaving: Bool = false

    @ObservationIgnored
    let baseline: EditorBaseline
    @ObservationIgnored
    var hasEditedRenewalPrice: Bool = false
    @ObservationIgnored
    var autoFilledFieldValues: [String: String] = [:]
    @ObservationIgnored
    var lastAutoFilledPresetName: String?
    @ObservationIgnored
    var lastAutoFilledPresetGroup: PopularSoftwareGroup?
    @ObservationIgnored
    var lastAutoFilledCurrency: String?

    public init(
        container: AppContainer,
        templates: [TemplateDefinition],
        categories: [SubscriptionCategory] = CategoryPresetManager.builtinCategories,
        existingItem: SubscriptionItem? = nil,
        defaultCategoryId: UUID? = nil,
        defaultTemplateId: UUID? = nil,
        defaultCurrency: String = "CNY",
        defaultReminderDays: Int = 3
    ) {
        self.container = container
        let resolvedTemplates = templates.isEmpty ? TemplatePresetManager.builtinTemplates : templates
        let resolvedCategories = categories.isEmpty ? CategoryPresetManager.builtinCategories : categories
        self.templates = resolvedTemplates
        self.categories = resolvedCategories
        self.existingItem = existingItem

        if let existing = existingItem {
            self.subscriptionId = existing.id
            self.name = existing.name
            self.selectedCategoryId = existing.categoryId
            self.selectedTemplateId = existing.templateId
            self.iconData = existing.iconData
            let initialPrice = NSDecimalNumber(decimal: existing.price).stringValue
            self.priceText = initialPrice
            let initialRenewalPrice =
                existing.renewalPrice.map { NSDecimalNumber(decimal: $0).stringValue } ?? initialPrice
            self.renewalPriceText = initialRenewalPrice
            self.hasEditedRenewalPrice = (existing.renewalPrice != nil && existing.renewalPrice != existing.price)
            self.currency = existing.currency
            let (normalizedUnit, normalizedCount) = existing.billingCycleType.normalizedUnitAndCount(
                intervalCount: existing.billingCycleDays)
            self.billingCycleType = normalizedUnit.canonicalCycleType
            let initialIntervalText = String(normalizedCount)
            self.billingCycleIntervalText = initialIntervalText
            self.startDate = existing.startDate
            self.nextRenewalDate = existing.nextRenewalDate
            self.renewalMode = existing.renewalMode
            self.customRenewalNote = existing.customRenewalNote
            self.status = existing.status
            self.reminderDaysBefore = existing.reminderDaysBefore
            self.notes = existing.notes
            let normalizedFields = Self.normalizedDynamicFields(
                in: existing.customFields,
                templateId: existing.templateId,
                subscriptionId: existing.id
            )
            self.customFields = normalizedFields

            self.baseline = EditorBaseline(
                name: existing.name,
                categoryId: existing.categoryId,
                templateId: existing.templateId,
                iconData: existing.iconData,
                priceText: initialPrice,
                renewalPriceText: initialRenewalPrice,
                currency: existing.currency,
                billingCycleType: normalizedUnit.canonicalCycleType,
                customCycleDaysText: initialIntervalText,
                startDateDay: Calendar.current.startOfDay(for: existing.startDate),
                nextRenewalDateDay: Calendar.current.startOfDay(for: existing.nextRenewalDate),
                renewalMode: existing.renewalMode,
                customRenewalNote: existing.customRenewalNote,
                status: existing.status,
                reminderDaysBefore: existing.reminderDaysBefore,
                notes: existing.notes,
                fields: normalizedFields.map {
                    FieldSnapshot(key: $0.key, label: $0.label, type: $0.type, value: $0.value)
                }
            )
        } else {
            let newId = UUID()
            self.subscriptionId = newId
            let initialTemplateId =
                defaultTemplateId ?? resolvedTemplates.first?.id ?? TemplateDefinition.BuiltinID.streaming
            let initialCategoryId =
                defaultCategoryId ?? resolvedCategories.first?.id
                ?? CategoryPresetManager.defaultCategoryId(forTemplateId: initialTemplateId)
            let now = Date()
            let initialNext = Calendar.current.date(byAdding: .year, value: 1, to: now) ?? now
            let initialFields: [CustomField] =
                if let template = TemplatePresetManager.template(for: initialTemplateId, from: resolvedTemplates) {
                    template.defaultFields.enumerated().map { idx, schema in
                        schema.instantiate(subscriptionId: newId, sortOrder: idx)
                    }
                } else {
                    []
                }

            let initialIsAPI = initialTemplateId == TemplateDefinition.BuiltinID.apiBalance
            let initialCycle: BillingCycleType = initialIsAPI ? .oneTime : .annually
            let initialRenewalMode: RenewalMode = initialIsAPI ? .manual : .automatic
            let initialNextResolved = initialIsAPI ? now : initialNext

            let initialCurrency =
                defaultCurrency.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "CNY" : defaultCurrency.uppercased()
            self.selectedTemplateId = initialTemplateId
            self.selectedCategoryId = initialCategoryId
            self.currency = initialCurrency
            self.billingCycleType = initialCycle
            self.renewalMode = initialRenewalMode
            self.customRenewalNote = ""
            self.reminderDaysBefore = defaultReminderDays
            self.startDate = now
            self.nextRenewalDate = initialNextResolved
            self.customFields = initialFields

            self.baseline = EditorBaseline(
                name: "",
                categoryId: initialCategoryId,
                templateId: initialTemplateId,
                iconData: nil,
                priceText: "",
                renewalPriceText: "",
                currency: initialCurrency,
                billingCycleType: initialCycle,
                customCycleDaysText: "1",
                startDateDay: Calendar.current.startOfDay(for: now),
                nextRenewalDateDay: Calendar.current.startOfDay(for: initialNextResolved),
                renewalMode: initialRenewalMode,
                customRenewalNote: "",
                status: .active,
                reminderDaysBefore: defaultReminderDays,
                notes: "",
                fields: initialFields.map {
                    FieldSnapshot(key: $0.key, label: $0.label, type: $0.type, value: $0.value)
                }
            )
        }
    }

    public var parsedPrice: Decimal {
        Decimal(string: priceText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    public var parsedRenewalPrice: Decimal? {
        guard billingCycleType != .oneTime else { return nil }
        let trimmed = renewalPriceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Decimal(string: trimmed)
    }
}
