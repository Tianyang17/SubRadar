import AppKit
import Charts
import SubRadarCore
import SwiftUI

extension AnalyticsDashboardView {
    func categoryBreakdownChart(summary: ExpenseAnalyticsSummary, cardHeight: CGFloat?) -> some View {
        let positiveBreakdowns = summary.categoryBreakdowns.filter {
            NSDecimalNumber(decimal: $0.totalBaseAmount).doubleValue > 0
        }
        let totalPositive = positiveBreakdowns.reduce(0.0) {
            $0 + NSDecimalNumber(decimal: $1.totalBaseAmount).doubleValue
        }
        let activeCategoryId = hoveredCategoryId ?? viewModel.selectedCategoryFilterId
        let focusedCat = positiveBreakdowns.first { $0.categoryId == activeCategoryId }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("分类占比")
                    .font(SubRadarTheme.cardTitleFont)
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                if viewModel.selectedCategoryFilterId != nil {
                    RadarButton("查看全部", variant: .ghost, size: .small) {
                        viewModel.selectedCategoryFilterId = nil
                    }
                }
            }

            if positiveBreakdowns.isEmpty {
                emptyChartPlaceholder(title: "暂无分类数据", systemImage: "chart.pie")
                    .frame(maxHeight: .infinity)
            } else {
                ZStack {
                    Chart(positiveBreakdowns) { cat in
                        let isFocused = activeCategoryId == nil || activeCategoryId == cat.categoryId
                        SectorMark(
                            angle: .value("金额", NSDecimalNumber(decimal: cat.totalBaseAmount).doubleValue),
                            innerRadius: .ratio(0.64),
                            outerRadius: .ratio(activeCategoryId == cat.categoryId ? 1.0 : 0.94),
                            angularInset: 2
                        )
                        .cornerRadius(3)
                        .foregroundStyle(categoryColor(for: cat.categoryId))
                        .opacity(isFocused ? 1.0 : 0.30)
                    }
                    .chartOverlay { _ in
                        GeometryReader { geo in
                            Color.clear
                                .contentShape(Rectangle())
                                .onContinuousHover { phase in
                                    switch phase {
                                    case .active(let location):
                                        hoveredCategoryId = categoryIdAtDonutPoint(
                                            location,
                                            in: geo.size,
                                            breakdowns: positiveBreakdowns,
                                            totalPositive: totalPositive
                                        )
                                    case .ended:
                                        hoveredCategoryId = nil
                                    }
                                }
                                .onTapGesture {
                                    if let hovered = hoveredCategoryId {
                                        viewModel.selectedCategoryFilterId =
                                            (viewModel.selectedCategoryFilterId == hovered) ? nil : hovered
                                    }
                                }
                        }
                    }
                    .transaction { $0.animation = nil }

                    VStack(spacing: 1) {
                        Text(focusedCat?.categoryName ?? "总计")
                            .font(SubRadarTheme.uiFont(size: 10.5, weight: .medium))
                            .foregroundStyle(palette.textMuted)
                            .lineLimit(1)
                            .frame(maxWidth: 76)
                        if let focusedCat {
                            let ratio =
                                totalPositive > 0
                                ? (NSDecimalNumber(decimal: focusedCat.totalBaseAmount).doubleValue / totalPositive)
                                    * 100
                                : 0
                            Text(String(format: "%.0f%%", ratio))
                                .font(SubRadarTheme.font(size: 13, weight: .bold))
                                .foregroundStyle(palette.textPrimary)
                            Text(
                                SubRadarFormatter.formatCompactMoney(
                                    focusedCat.totalBaseAmount, currency: summary.baseCurrency)
                            )
                            .font(SubRadarTheme.font(size: 9.5, weight: .semibold))
                            .foregroundStyle(categoryColor(for: focusedCat.categoryId))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .frame(maxWidth: 76)
                        } else {
                            Text(
                                SubRadarFormatter.formatCompactMoney(
                                    summary.totalBaseAmount, currency: summary.baseCurrency)
                            )
                            .font(SubRadarTheme.font(size: 12.5, weight: .bold))
                            .foregroundStyle(palette.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: 76)
                        }
                    }
                    .allowsHitTesting(false)
                }
                .frame(height: 142)

                ScrollView {
                    VStack(spacing: 5) {
                        ForEach(summary.categoryBreakdowns) { cat in
                            let isSelected = viewModel.selectedCategoryFilterId == cat.categoryId
                            let isHovered = hoveredCategoryId == cat.categoryId
                            let amountDouble = max(0, NSDecimalNumber(decimal: cat.totalBaseAmount).doubleValue)
                            let ratio = totalPositive > 0 ? (amountDouble / totalPositive) : 0
                            let catTint = categoryColor(for: cat.categoryId)

                            Button {
                                viewModel.selectedCategoryFilterId = isSelected ? nil : cat.categoryId
                            } label: {
                                VStack(spacing: 4) {
                                    HStack(spacing: 7) {
                                        Circle()
                                            .fill(catTint)
                                            .frame(width: 7.5, height: 7.5)
                                        Text(cat.categoryName)
                                            .font(
                                                SubRadarTheme.uiFont(
                                                    size: 12, weight: (isSelected || isHovered) ? .semibold : .medium)
                                            )
                                            .foregroundStyle(
                                                (isSelected || isHovered) ? palette.textPrimary : palette.textSecondary
                                            )
                                            .lineLimit(1)
                                        Spacer(minLength: 4)
                                        Text(String(format: "%.0f%%", ratio * 100))
                                            .font(SubRadarTheme.font(size: 10.5, weight: .medium))
                                            .foregroundStyle(palette.textMuted)
                                        Text(
                                            SubRadarFormatter.formatCompactMoney(
                                                cat.totalBaseAmount, currency: summary.baseCurrency)
                                        )
                                        .font(SubRadarTheme.font(size: 11.5, weight: .semibold))
                                        .foregroundStyle(palette.textPrimary)
                                    }

                                    GeometryReader { barProxy in
                                        ZStack(alignment: .leading) {
                                            Capsule()
                                                .fill(palette.divider.opacity(0.65))
                                                .frame(height: 2.5)
                                            Capsule()
                                                .fill(catTint.opacity((isSelected || isHovered) ? 1.0 : 0.72))
                                                .frame(width: max(4, barProxy.size.width * ratio), height: 2.5)
                                        }
                                    }
                                    .frame(height: 3)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 7, style: .circular)
                                        .fill(
                                            isSelected
                                                ? SubRadarTheme.radarAccent.opacity(0.11)
                                                : (isHovered ? palette.inputSurface : Color.clear)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            .onHover { hovering in
                                hoveredCategoryId =
                                    hovering
                                    ? cat.categoryId : (hoveredCategoryId == cat.categoryId ? nil : hoveredCategoryId)
                            }
                        }
                    }
                }
            }
        }
        .frame(height: cardHeight, alignment: .top)
        .customCard(padding: 18)
    }

    func categoryIdAtDonutPoint(
        _ point: CGPoint,
        in size: CGSize,
        breakdowns: [ExpenseAnalyticsSummary.CategoryBreakdown],
        totalPositive: Double
    ) -> UUID? {
        guard totalPositive > 0 else { return nil }
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = point.x - center.x
        let dy = point.y - center.y
        let radius = hypot(dx, dy)
        let outerR = min(size.width, size.height) / 2
        // 仅命中圆环范围内（排除最外侧空白与内圈文字中心）
        guard radius >= outerR * 0.42 && radius <= outerR * 1.05 else { return nil }

        // SectorMark 从 12 点钟方向顺时针绘制
        var angle = atan2(dx, -dy)
        if angle < 0 { angle += 2 * .pi }
        let targetValue = (angle / (2 * .pi)) * totalPositive

        var cumulative = 0.0
        for item in breakdowns {
            let value = max(0, NSDecimalNumber(decimal: item.totalBaseAmount).doubleValue)
            cumulative += value
            if targetValue <= cumulative {
                return item.categoryId
            }
        }
        return breakdowns.last?.categoryId
    }

    func monthKey(for date: Date) -> String {
        let comps = Calendar.current.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", comps.year ?? 2026, comps.month ?? 1)
    }
}
