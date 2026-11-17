import AppKit
import Charts
import SubRadarCore
import SwiftUI

extension AnalyticsDashboardView {
    @ViewBuilder
    func expiryRadarSection(summary: ExpenseAnalyticsSummary, isWide: Bool, availableWidth: CGFloat) -> some View {
        if isWide {
            let rightWidth = min(500, max(320, (availableWidth - 16) * 0.40))
            HStack(alignment: .top, spacing: 16) {
                expiryBucketChart(summary: summary, cardHeight: 318)
                    .frame(maxWidth: .infinity)
                upcomingRenewalsListCard(summary: summary, cardHeight: 318)
                    .frame(width: rightWidth)
            }
        } else {
            VStack(spacing: 16) {
                expiryBucketChart(summary: summary, cardHeight: nil)
                upcomingRenewalsListCard(summary: summary, cardHeight: nil)
            }
        }
    }

    func expiryBucketChart(summary: ExpenseAnalyticsSummary, cardHeight: CGFloat?) -> some View {
        let totalCount = summary.expiryBuckets.reduce(0) { $0 + $1.count }
        let maxCount = max(2, summary.expiryBuckets.map(\.count).max() ?? 2)
        let focusedBucketLabel = hoveredExpiryBucketId ?? selectedExpiryBucketId
        let focusedBucket = focusedBucketLabel.flatMap { id in summary.expiryBuckets.first { $0.label == id } }

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("订阅到期窗口分布")
                    .font(SubRadarTheme.cardTitleFont)
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                if let focusedBucket {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(expiryBucketColor(focusedBucket.colorToken))
                            .frame(width: 6.5, height: 6.5)
                        let amountText =
                            focusedBucket.estimatedRenewalBaseAmount > 0
                            ? " · \(SubRadarFormatter.formatCompactMoney(focusedBucket.estimatedRenewalBaseAmount, currency: summary.baseCurrency))"
                            : ""
                        Text("\(focusedBucket.label)：\(focusedBucket.count) 项\(amountText)")
                            .font(SubRadarTheme.font(size: 10.5, weight: .semibold))
                            .foregroundStyle(palette.textPrimary)
                        if selectedExpiryBucketId != nil {
                            Button {
                                selectedExpiryBucketId = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(palette.textMuted)
                            }
                            .buttonStyle(.plain)
                            .help("清除窗口筛选")
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(palette.inputSurface, in: Capsule())
                } else {
                    Text("共 \(totalCount) 项运行中 · 悬浮看详情 / 点击筛选日程")
                        .font(SubRadarTheme.font(size: 10.5))
                        .foregroundStyle(palette.textMuted)
                }
            }

            if totalCount == 0 {
                emptyChartPlaceholder(title: "暂无运行中订阅到期数据", systemImage: "calendar.badge.clock")
                    .frame(maxHeight: .infinity)
            } else {
                GeometryReader { geo in
                    let plotHeight = max(110, geo.size.height - 46)
                    let ySteps = maxCount <= 4 ? maxCount : 4

                    HStack(alignment: .top, spacing: 8) {
                        // 左侧整数 Y 轴刻度
                        VStack(alignment: .trailing, spacing: 0) {
                            ForEach((0...ySteps).reversed(), id: \.self) { step in
                                let tickValue = Int((Double(maxCount) * Double(step) / Double(ySteps)).rounded())
                                Text("\(tickValue)")
                                    .font(SubRadarTheme.font(size: 10))
                                    .foregroundStyle(palette.textMuted)
                                    .frame(height: step == 0 ? 12 : nil, alignment: .bottom)
                                if step > 0 {
                                    Spacer(minLength: 0)
                                }
                            }
                        }
                        .frame(width: 18, height: plotHeight)

                        // 右侧等宽柱状图与居中 X 轴标签
                        ZStack(alignment: .top) {
                            // 水平参考网格线
                            VStack(spacing: 0) {
                                ForEach(0...ySteps, id: \.self) { step in
                                    Rectangle()
                                        .fill(palette.divider.opacity(step == ySteps ? 0.9 : 0.45))
                                        .frame(height: 1)
                                    if step < ySteps {
                                        Spacer(minLength: 0)
                                    }
                                }
                            }
                            .frame(height: plotHeight)

                            HStack(alignment: .bottom, spacing: 8) {
                                ForEach(summary.expiryBuckets) { bucket in
                                    let barColor = expiryBucketColor(bucket.colorToken)
                                    let ratio = maxCount > 0 ? CGFloat(bucket.count) / CGFloat(maxCount) : 0
                                    let barHeight = bucket.count > 0 ? max(16, (plotHeight - 24) * ratio) : 3
                                    let isSelected = selectedExpiryBucketId == bucket.label
                                    let isHovered = hoveredExpiryBucketId == bucket.label
                                    let isDimmed = (selectedExpiryBucketId != nil && !isSelected) && !isHovered

                                    VStack(spacing: 6) {
                                        VStack(spacing: 4) {
                                            Spacer(minLength: 0)

                                            if bucket.count > 0 {
                                                Text("\(bucket.count) 项")
                                                    .font(SubRadarTheme.font(size: 10.5, weight: .semibold))
                                                    .foregroundStyle(
                                                        isHovered || isSelected
                                                            ? palette.textPrimary : palette.textSecondary
                                                    )
                                                    .lineLimit(1)
                                            }

                                            UnevenRoundedRectangle(
                                                topLeadingRadius: bucket.count > 0 ? 6 : 2,
                                                bottomLeadingRadius: 2,
                                                bottomTrailingRadius: 2,
                                                topTrailingRadius: bucket.count > 0 ? 6 : 2,
                                                style: .continuous
                                            )
                                            .fill(
                                                LinearGradient(
                                                    colors: bucket.count > 0
                                                        ? [barColor, barColor.opacity(0.78)]
                                                        : [palette.divider.opacity(0.6), palette.divider.opacity(0.6)],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                            .overlay(
                                                UnevenRoundedRectangle(
                                                    topLeadingRadius: bucket.count > 0 ? 6 : 2,
                                                    bottomLeadingRadius: 2,
                                                    bottomTrailingRadius: 2,
                                                    topTrailingRadius: bucket.count > 0 ? 6 : 2,
                                                    style: .continuous
                                                )
                                                .strokeBorder(
                                                    isSelected || isHovered
                                                        ? palette.textPrimary.opacity(0.45) : Color.clear,
                                                    lineWidth: 1.5)
                                            )
                                            .frame(maxWidth: 42)
                                            .frame(height: barHeight)
                                        }
                                        .frame(height: plotHeight)

                                        VStack(spacing: 1) {
                                            Text(bucket.label)
                                                .font(
                                                    SubRadarTheme.uiFont(
                                                        size: 11,
                                                        weight: (isSelected || isHovered || bucket.count > 0)
                                                            ? .semibold : .regular)
                                                )
                                                .foregroundStyle(
                                                    isSelected
                                                        ? barColor
                                                        : (bucket.count > 0 ? palette.textPrimary : palette.textMuted)
                                                )
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.85)

                                            if bucket.estimatedRenewalBaseAmount > 0 && bucket.label != "永久买断" {
                                                Text(
                                                    SubRadarFormatter.formatCompactMoney(
                                                        bucket.estimatedRenewalBaseAmount,
                                                        currency: summary.baseCurrency)
                                                )
                                                .font(SubRadarTheme.font(size: 9.5))
                                                .foregroundStyle(palette.textMuted)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.8)
                                            } else {
                                                Text(" ")
                                                    .font(SubRadarTheme.font(size: 9.5))
                                            }
                                        }
                                        .frame(height: 32, alignment: .top)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.horizontal, 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(
                                                isSelected
                                                    ? barColor.opacity(0.11)
                                                    : (isHovered ? palette.inputSurface.opacity(0.85) : Color.clear)
                                            )
                                    )
                                    .opacity(isDimmed ? 0.42 : 1.0)
                                    .contentShape(Rectangle())
                                    .onHover { hovering in
                                        hoveredExpiryBucketId =
                                            hovering
                                            ? bucket.label
                                            : (hoveredExpiryBucketId == bucket.label ? nil : hoveredExpiryBucketId)
                                    }
                                    .onTapGesture {
                                        selectedExpiryBucketId =
                                            (selectedExpiryBucketId == bucket.label) ? nil : bucket.label
                                    }
                                    .help("\(bucket.label)：\(bucket.count) 项，点击联动筛选右侧日程")
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .frame(height: cardHeight ?? 280, alignment: .top)
        .customCard(padding: 18)
    }
}
