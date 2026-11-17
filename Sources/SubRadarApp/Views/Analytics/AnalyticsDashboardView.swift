import AppKit
import Charts
import SubRadarCore
import SwiftUI

struct AnalyticsDashboardView: View {
    @Environment(\.radarPalette) var palette
    @Bindable var viewModel: AnalyticsViewModel
    var onCurrencyChanged: ((String) -> Void)? = nil
    var onSelectSubscription: ((UUID) -> Void)? = nil
    @State var isLedgerExpanded = false
    @State var hoveredExpiryBucketId: String?
    @State var selectedExpiryBucketId: String?
    @State var hoveredMonth: String?
    @State var selectedMonth: String?
    @State var hoveredCategoryId: UUID?

    var body: some View {
        GeometryReader { proxy in
            let isWide = proxy.size.width >= 760
            let availableWidth = max(320, proxy.size.width - 48)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerAndRangeBar

                    if let summary = viewModel.summary {
                        kpiGridSection(summary: summary, isWide: isWide)
                        if !summary.apiBalanceItems.isEmpty {
                            apiBalancesSection(summary: summary, isWide: isWide)
                        }
                        expiryRadarSection(summary: summary, isWide: isWide, availableWidth: availableWidth)
                        chartsSection(summary: summary, isWide: isWide, availableWidth: availableWidth)
                        recordsBreakdownCard(summary: summary)
                    } else if viewModel.isLoading {
                        ProgressView("正在计算概览数据...")
                            .frame(maxWidth: .infinity, minHeight: 260)
                    }
                }
                .padding(24)
            }
        }
        .background(palette.windowBackground)
        .task {
            await viewModel.reloadAnalytics()
        }
        .onChange(of: viewModel.selectedRangePreset) { _, _ in
            Task { await viewModel.reloadAnalytics() }
        }
        .onChange(of: viewModel.baseCurrency) { _, _ in
            Task { await viewModel.reloadAnalytics() }
        }
        .onChange(of: viewModel.customStartDate) { _, _ in
            if viewModel.selectedRangePreset == .custom {
                Task { await viewModel.reloadAnalytics() }
            }
        }
        .onChange(of: viewModel.customEndDate) { _, _ in
            if viewModel.selectedRangePreset == .custom {
                Task { await viewModel.reloadAnalytics() }
            }
        }
    }

    @ViewBuilder
    private var headerAndRangeBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 12) {
                    titleHeader
                    Spacer(minLength: 16)
                    HStack(spacing: 10) {
                        currencySwitcher
                        rangePicker
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    titleHeader
                    HStack(spacing: 10) {
                        currencySwitcher
                        rangePicker
                    }
                }
            }

            if viewModel.selectedRangePreset == .custom {
                HStack(spacing: 12) {
                    RadarDatePicker("起始: ", selection: $viewModel.customStartDate)
                    RadarDatePicker("结束: ", selection: $viewModel.customEndDate)
                    Spacer()
                }
                .customCard(padding: 10, cornerRadius: SubRadarTheme.cardCornerRadius)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var titleHeader: some View {
        RadarPageHeader(
            "订阅概览",
            subtitle: "到期分布、续订日程与花费统计（折算币种：\(viewModel.baseCurrency)）"
        )
    }

    private var currencySwitcher: some View {
        RadarSelectMenu(
            options: CommonCurrency.allCases.map(\.rawValue),
            selection: Binding(
                get: { viewModel.baseCurrency },
                set: { newCode in
                    guard viewModel.baseCurrency != newCode else { return }
                    viewModel.baseCurrency = newCode
                    onCurrencyChanged?(newCode)
                }
            ),
            iconSymbol: { _ in "coloncurrencysign.circle" },
            label: { "\($0) \(CommonCurrency.symbol(for: $0))" }
        )
        .fixedSize(horizontal: true, vertical: false)
    }

    private var rangePicker: some View {
        RadarSegmentedBar(
            options: AnalyticsRangePreset.allCases,
            selection: $viewModel.selectedRangePreset,
            label: { $0.displayName }
        )
        .fixedSize(horizontal: true, vertical: false)
    }

    func emptyChartPlaceholder(title: String, systemImage: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 24))
                .foregroundStyle(palette.textMuted)
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(palette.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
