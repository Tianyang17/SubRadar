import Foundation
import Observation

/// 侧边栏导航项
public enum SidebarDestination: Hashable, Sendable {
    case all
    case expiringSoon
    case expiredOrPaused
    case category(UUID)
    case analytics
    case templateManager
    case settings
}

/// 列表排序方式
public enum SubscriptionSortOption: String, CaseIterable, Identifiable, Sendable {
    case nextRenewalAsc
    case priceDesc
    case nameAsc

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .nextRenewalAsc: return "按续订时间"
        case .priceDesc: return "按单期价格"
        case .nameAsc: return "按名称排序"
        }
    }
}

/// 主窗口三栏核心状态管理 ViewModel
@Observable
@MainActor
public final class MainViewModel {
    public let container: AppContainer
    public let settings: AppSettingsStore

    public var categories: [SubscriptionCategory] = []
    public var templates: [TemplateDefinition] = []
    public var subscriptions: [SubscriptionItem] = []
    public var selectedRecords: [BillingRecord] = []
    public var totalSpentBySubscriptionId: [UUID: Decimal] = [:]
    public var totalSpentSummaryBySubscriptionId: [UUID: SubscriptionSpendSummary] = [:]
    public var baseCurrency: String { settings.baseCurrency }
    public var monthlyEstimatedBaseSpend: Decimal = 0

    public var sidebarSelection: SidebarDestination? = .analytics {
        didSet {
            guard oldValue != sidebarSelection else { return }
            syncSelectionOnDestinationChange()
        }
    }
    public var selectedSubscriptionId: UUID?
    public var searchQuery: String = ""
    public var sortOption: SubscriptionSortOption = .nextRenewalAsc

    public var revealedSecretFieldIds: Set<UUID> = []
    public var toastMessage: String?
    @ObservationIgnored
    var toastDismissTask: Task<Void, Never>?
    public var errorMessage: String?
    public var isLoading: Bool = false
    public var isRefreshingAPIBalance: Bool = false

    public init(container: AppContainer, settings: AppSettingsStore = AppSettingsStore()) {
        self.container = container
        self.settings = settings
    }

    public func openSettings() {
        sidebarSelection = .settings
    }

    public func cycleTheme() {
        settings.cycleTheme()
    }

    public func updateBaseCurrency(_ currency: String) async {
        settings.baseCurrency = currency
        await recomputeMonthlyEstimate()
    }

    public var selectedSubscription: SubscriptionItem? {
        guard let id = selectedSubscriptionId else { return nil }
        return subscriptions.first(where: { $0.id == id })
    }

    public var expiringSoonSubscriptions: [SubscriptionItem] {
        subscriptions.filter { item in
            item.status == .active && item.billingCycleType != .oneTime && item.daysUntilRenewal() <= 7
        }
        .sorted { $0.nextRenewalDate < $1.nextRenewalDate }
    }

    public var filteredSubscriptions: [SubscriptionItem] {
        let baseList: [SubscriptionItem]
        switch sidebarSelection {
        case .all, .none, .analytics, .templateManager, .settings:
            baseList = subscriptions
        case .expiringSoon:
            baseList = expiringSoonSubscriptions
        case .expiredOrPaused:
            baseList = subscriptions.filter {
                $0.status == .paused || $0.status == .cancelled || $0.status == .expired
                    || ($0.billingCycleType != .oneTime && $0.daysUntilRenewal() < 0)
            }
        case .category(let categoryId):
            baseList = subscriptions.filter { $0.categoryId == categoryId }
        }

        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let searched: [SubscriptionItem]
        if trimmed.isEmpty {
            searched = baseList
        } else {
            searched = baseList.filter { item in
                item.name.localizedCaseInsensitiveContains(trimmed)
                    || item.notes.localizedCaseInsensitiveContains(trimmed)
                    || item.customFields.contains { $0.value.localizedCaseInsensitiveContains(trimmed) }
            }
        }

        return searched.sorted { lhs, rhs in
            switch sortOption {
            case .nextRenewalAsc:
                if lhs.billingCycleType == .oneTime && rhs.billingCycleType != .oneTime { return false }
                if lhs.billingCycleType != .oneTime && rhs.billingCycleType == .oneTime { return true }
                return lhs.nextRenewalDate < rhs.nextRenewalDate
            case .priceDesc:
                return lhs.effectiveRenewalPrice > rhs.effectiveRenewalPrice
            case .nameAsc:
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        }
    }

    public func count(for destination: SidebarDestination) -> Int {
        switch destination {
        case .all:
            return subscriptions.count
        case .expiringSoon:
            return expiringSoonSubscriptions.count
        case .expiredOrPaused:
            return subscriptions.filter {
                $0.status != .active || ($0.billingCycleType != .oneTime && $0.daysUntilRenewal() < 0)
            }.count
        case .category(let id):
            return subscriptions.filter { $0.categoryId == id }.count
        case .analytics, .templateManager, .settings:
            return 0
        }
    }

    public func category(for id: UUID) -> SubscriptionCategory? {
        CategoryPresetManager.category(for: id, from: categories)
    }

    public func template(for id: UUID) -> TemplateDefinition? {
        TemplatePresetManager.template(for: id, from: templates)
    }

    public func loadAll() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let loadedCategories = container.repository.fetchCategories()
            async let loadedTemplates = container.repository.fetchTemplates()
            async let loadedSubs = container.repository.fetchSubscriptions()
            categories = try await loadedCategories
            templates = try await loadedTemplates
            subscriptions = try await loadedSubs

            var totals: [UUID: Decimal] = [:]
            var summaries: [UUID: SubscriptionSpendSummary] = [:]
            for item in subscriptions {
                let summary = await computeSpendSummary(for: item)
                totals[item.id] = summary.convertedTotal
                summaries[item.id] = summary
            }
            totalSpentBySubscriptionId = totals
            totalSpentSummaryBySubscriptionId = summaries

            await recomputeMonthlyEstimate()

            syncSelectionAfterReload()
            await loadRecordsForSelected()
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    func syncSelectionOnDestinationChange() {
        switch sidebarSelection {
        case .all, .expiringSoon, .expiredOrPaused, .category:
            let nextId = filteredSubscriptions.first?.id
            if selectedSubscriptionId != nextId {
                selectedSubscriptionId = nextId
                if nextId == nil {
                    selectedRecords = []
                } else {
                    Task { @MainActor [weak self] in
                        await self?.loadRecordsForSelected()
                    }
                }
            }
        case .analytics, .templateManager, .settings, .none:
            break
        }
    }

    func syncSelectionAfterReload() {
        switch sidebarSelection {
        case .all, .expiringSoon, .expiredOrPaused, .category:
            if selectedSubscriptionId == nil
                || !filteredSubscriptions.contains(where: { $0.id == selectedSubscriptionId })
            {
                selectedSubscriptionId = filteredSubscriptions.first?.id
            }
        case .analytics, .templateManager, .settings, .none:
            if selectedSubscriptionId == nil || !subscriptions.contains(where: { $0.id == selectedSubscriptionId }) {
                selectedSubscriptionId = subscriptions.first?.id
            }
        }
    }

    public func loadRecordsForSelected() async {
        guard let selectedId = selectedSubscriptionId else {
            selectedRecords = []
            return
        }
        selectedRecords = (try? await container.repository.fetchBillingRecords(for: selectedId)) ?? []
    }

    public func selectSubscription(_ id: UUID?) async {
        selectedSubscriptionId = id
        revealedSecretFieldIds.removeAll()
        await loadRecordsForSelected()
    }
}
