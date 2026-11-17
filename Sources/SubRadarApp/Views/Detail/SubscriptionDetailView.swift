import SubRadarCore
import SwiftUI

struct SubscriptionDetailView: View {
    @Environment(\.radarPalette) var palette
    @Bindable var viewModel: MainViewModel
    let item: SubscriptionItem
    let onEdit: (SubscriptionItem) -> Void

    @State var showRenewPopover = false
    @State var renewPriceText = ""
    @State var showDeleteConfirm = false
    @State var isRecordsExpanded = false
    @State var showLedgerSheet = false
    @State var editingRecord: BillingRecord?
    @State var ledgerKind: BillingRecordKind = .charge
    @State var ledgerAmountText = ""
    @State var ledgerCurrency = "CNY"
    @State var ledgerDate = Date()
    @State var ledgerNote = ""

    var body: some View {
        let spendSummary = viewModel.totalSpentSummaryBySubscriptionId[item.id]
        let totalSpent = spendSummary?.convertedTotal ?? viewModel.totalSpentBySubscriptionId[item.id] ?? 0

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerSection

                if isLowAPIBalance {
                    lowBalanceBanner
                }

                billingSummaryCard(totalSpent: totalSpent, spendSummary: spendSummary)

                if !item.customFields.isEmpty || item.sshURL != nil {
                    customFieldsCard
                }

                if !item.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    notesCard
                }

                billingRecordsCard
            }
            .padding(22)
        }
        .background(palette.windowBackground)
        .sheet(isPresented: $showRenewPopover) {
            renewPopoverContent
                .radarTheme(viewModel.settings.themeMode)
        }
        .sheet(isPresented: $showLedgerSheet) {
            ledgerRecordSheetContent
                .radarTheme(viewModel.settings.themeMode)
        }
        .sheet(isPresented: $showDeleteConfirm) {
            RadarConfirmSheet(
                title: "确定删除「\(item.name)」？",
                message: "删除后将一并清除该订阅的所有历史计费流水、本地到期提醒及关联敏感字段，且无法恢复。",
                confirmTitle: "确认删除",
                cancelTitle: "保留订阅",
                isDestructive: true
            ) {
                Task { await viewModel.deleteSubscription(item) }
            }
            .radarTheme(viewModel.settings.themeMode)
        }
    }
}
