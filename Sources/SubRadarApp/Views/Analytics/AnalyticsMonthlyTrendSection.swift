import AppKit
import Charts
import SubRadarCore
import SwiftUI

extension AnalyticsDashboardView {
    @ViewBuilder
    func chartsSection(summary: ExpenseAnalyticsSummary, isWide: Bool, availableWidth: CGFloat) -> some View {
        if isWide {
            let rightWidth = min(440, max(280, (availableWidth - 16) * 0.36))
            HStack(alignment: .top, spacing: 16) {
                monthlyTrendChart(summary: summary, cardHeight: 332)
                    .frame(maxWidth: .infinity)
                categoryBreakdownChart(summary: summary, cardHeight: 332)
                    .frame(width: rightWidth)
            }
        } else {
            VStack(spacing: 16) {
                monthlyTrendChart(summary: summary, cardHeight: nil)
                categoryBreakdownChart(summary: summary, cardHeight: nil)
            }
        }
    }

    func categoryColor(for categoryId: UUID) -> Color {
        if let cat = viewModel.categoriesById[categoryId] {
            return SubRadarTheme.categoryColor(for: cat.colorKey)
        }
        return SubRadarTheme.radarAccent
    }

    func sampledMonthLabels(from orderedMonths: [String], maxLabels: Int = 5) -> [String] {
        guard orderedMonths.count > maxLabels, maxLabels >= 2 else { return orderedMonths }
        let lastIndex = orderedMonths.count - 1
        var picked: [String] = []
        for idx in 0..<maxLabels {
            let mapped = Int((Double(idx) * Double(lastIndex) / Double(maxLabels - 1)).rounded())
            let label = orderedMonths[mapped]
            if picked.last != label {
                picked.append(label)
            }
        }
        return picked
    }

    func nearestMonth(toPlotX plotX: CGFloat, orderedMonths: [String], proxy: ChartProxy) -> String? {
        guard !orderedMonths.isEmpty else { return nil }
        var bestMonth: String?
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for month in orderedMonths {
            guard let centerX = proxy.position(forX: month) else { continue }
            let dist = abs(centerX - plotX)
            if dist < bestDistance {
                bestDistance = dist
                bestMonth = month
            }
        }
        return bestMonth ?? orderedMonths.first
    }

    func monthlyTrendChart(summary: ExpenseAnalyticsSummary, cardHeight: CGFloat?) -> some View {
        let validTrends = summary.monthlyTrends.filter { NSDecimalNumber(decimal: $0.totalBaseAmount).doubleValue > 0 }
        let categoryNames = Array(Set(validTrends.map(\.categoryName))).sorted()
        let categoryColors = categoryNames.map { name -> Color in
            if let point = validTrends.first(where: { $0.categoryName == name }) {
                return categoryColor(for: point.categoryId)
            }
            return SubRadarTheme.radarAccent
        }
        let orderedMonths = Array(Set(validTrends.map(\.yearMonth))).sorted()
        let visibleMonths = sampledMonthLabels(from: orderedMonths, maxLabels: 5)
        let activeFocusMonth = hoveredMonth ?? selectedMonth
        let monthBreakdowns =
            activeFocusMonth.map { month in
                validTrends
                    .filter { $0.yearMonth == month }
                    .sorted { $0.totalBaseAmount > $1.totalBaseAmount }
            } ?? []
        let focusedMonthTotal = monthBreakdowns.reduce(Decimal.zero) { $0 + $1.totalBaseAmount }

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("月度支出堆叠趋势")
                    .font(SubRadarTheme.cardTitleFont)
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                if let focusMonth = activeFocusMonth, !monthBreakdowns.isEmpty {
                    HStack(spacing: 5) {
                        Text(
                            "\(focusMonth) · \(SubRadarFormatter.formatCompactMoney(focusedMonthTotal, currency: summary.baseCurrency))"
                        )
                        .font(SubRadarTheme.font(size: 10.5, weight: .semibold))
                        .foregroundStyle(palette.textPrimary)
                        if selectedMonth != nil {
                            Button {
                                selectedMonth = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(palette.textMuted)
                            }
                            .buttonStyle(.plain)
                            .help("取消月份筛选")
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(palette.inputSurface, in: Capsule())
                } else if orderedMonths.count > 1 {
                    Text("\(orderedMonths.first ?? "") ~ \(orderedMonths.last ?? "")")
                        .font(SubRadarTheme.font(size: 10.5))
                        .foregroundStyle(palette.textMuted)
                }
            }

            if validTrends.isEmpty {
                emptyChartPlaceholder(title: "当前时间段暂无扣费流水", systemImage: "chart.bar")
                    .frame(maxHeight: .infinity)
            } else {
                Chart(validTrends) { point in
                    BarMark(
                        x: .value("月份", point.yearMonth),
                        y: .value("金额", max(0, NSDecimalNumber(decimal: point.totalBaseAmount).doubleValue))
                    )
                    .foregroundStyle(by: .value("分类", point.categoryName))
                    .cornerRadius(3)
                }
                .chartForegroundStyleScale(domain: categoryNames, range: categoryColors)
                .chartXAxis {
                    AxisMarks(values: visibleMonths) { value in
                        AxisGridLine()
                            .foregroundStyle(palette.divider.opacity(0.45))
                        AxisValueLabel(centered: true) {
                            if let label = value.as(String.self) {
                                Text(label)
                                    .font(SubRadarTheme.font(size: 10))
                                    .foregroundStyle(palette.textMuted)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                        }
                    }
                }
                .chartPlotStyle { plotArea in
                    plotArea.padding(.horizontal, 10)
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine()
                            .foregroundStyle(palette.divider)
                        AxisValueLabel()
                            .foregroundStyle(palette.textMuted)
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        if let plotFrame = proxy.plotFrame {
                            let frame = geo[plotFrame]
                            ZStack(alignment: .topLeading) {
                                if let focusMonth = activeFocusMonth,
                                    let centerX = proxy.position(forX: focusMonth)
                                {
                                    let bandWidth = min(
                                        56, max(20, frame.width / CGFloat(max(1, orderedMonths.count)) * 0.58))
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(SubRadarTheme.radarAccent.opacity(0.08))
                                        .frame(width: bandWidth, height: frame.height)
                                        .offset(x: frame.minX + centerX - bandWidth / 2, y: frame.minY)
                                        .allowsHitTesting(false)

                                    Rectangle()
                                        .fill(SubRadarTheme.radarAccent.opacity(0.45))
                                        .frame(width: 1, height: frame.height)
                                        .offset(x: frame.minX + centerX, y: frame.minY)
                                        .allowsHitTesting(false)
                                }

                                Color.clear
                                    .contentShape(Rectangle())
                                    .onContinuousHover { phase in
                                        switch phase {
                                        case .active(let location):
                                            guard
                                                location.x >= frame.minX - 6 && location.x <= frame.maxX + 6
                                                    && location.y >= frame.minY && location.y <= frame.maxY
                                            else {
                                                if hoveredMonth != nil {
                                                    hoveredMonth = nil
                                                }
                                                return
                                            }
                                            let plotX = location.x - frame.minX
                                            let nextHover = nearestMonth(
                                                toPlotX: plotX,
                                                orderedMonths: orderedMonths,
                                                proxy: proxy
                                            )
                                            if hoveredMonth != nextHover {
                                                hoveredMonth = nextHover
                                            }
                                        case .ended:
                                            if hoveredMonth != nil {
                                                hoveredMonth = nil
                                            }
                                        }
                                    }
                                    .onTapGesture {
                                        if let target = hoveredMonth {
                                            selectedMonth = (selectedMonth == target) ? nil : target
                                            if selectedMonth != nil {
                                                isLedgerExpanded = true
                                            }
                                        }
                                    }

                                if let hover = hoveredMonth, !monthBreakdowns.isEmpty {
                                    let idx = orderedMonths.firstIndex(of: hover) ?? 0
                                    let alignRight = idx < max(1, orderedMonths.count / 2)
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 8) {
                                            Text(hover)
                                                .font(SubRadarTheme.font(size: 11, weight: .bold))
                                                .foregroundStyle(palette.textPrimary)
                                            Spacer(minLength: 8)
                                            Text(
                                                SubRadarFormatter.formatMoney(
                                                    focusedMonthTotal, currency: summary.baseCurrency)
                                            )
                                            .font(SubRadarTheme.font(size: 11, weight: .bold))
                                            .foregroundStyle(SubRadarTheme.radarAccent)
                                        }
                                        ForEach(monthBreakdowns.prefix(4)) { item in
                                            HStack(spacing: 5) {
                                                Circle()
                                                    .fill(categoryColor(for: item.categoryId))
                                                    .frame(width: 6, height: 6)
                                                Text(item.categoryName)
                                                    .font(SubRadarTheme.uiFont(size: 10.5))
                                                    .foregroundStyle(palette.textSecondary)
                                                    .lineLimit(1)
                                                Spacer(minLength: 8)
                                                Text(
                                                    SubRadarFormatter.formatCompactMoney(
                                                        item.totalBaseAmount, currency: summary.baseCurrency)
                                                )
                                                .font(SubRadarTheme.font(size: 10.5, weight: .semibold))
                                                .foregroundStyle(palette.textPrimary)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .frame(width: 176)
                                    .background(
                                        palette.elevatedSurface,
                                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .strokeBorder(palette.borderSubtle, lineWidth: 1)
                                    )
                                    .shadow(color: Color.black.opacity(palette.isDark ? 0.38 : 0.12), radius: 8, y: 4)
                                    .offset(
                                        x: alignRight ? max(frame.minX + 8, frame.maxX - 184) : frame.minX + 8,
                                        y: frame.minY + 6
                                    )
                                    .allowsHitTesting(false)
                                }
                            }
                        }
                    }
                }
                // 禁用 Charts Canvas 隐式动画，规避 macOS Layout 与 AttributeGraph syncMainIfReferences 重入陷阱
                .transaction { $0.animation = nil }
                .frame(maxHeight: .infinity)
            }
        }
        .frame(height: cardHeight ?? 292, alignment: .top)
        .customCard(padding: 18)
    }
}
