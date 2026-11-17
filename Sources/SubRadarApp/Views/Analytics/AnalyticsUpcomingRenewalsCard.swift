import AppKit
import Charts
import SubRadarCore
import SwiftUI

extension AnalyticsDashboardView {
    func upcomingRenewalsListCard(summary: ExpenseAnalyticsSummary, cardHeight: CGFloat?) -> some View {
        let displayedItems: [ExpenseAnalyticsSummary.UpcomingRenewalItem] = {
            if let activeBucket = selectedExpiryBucketId {
                if activeBucket == "永久买断" {
                    return summary.oneTimeAssets
                }
                return summary.upcomingRenewals.filter { $0.windowLabel == activeBucket }
            }
            return summary.upcomingRenewals
        }()

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text(selectedExpiryBucketId == "永久买断" ? "永久买断 / 按量资产" : "近期到期日程")
                    .font(SubRadarTheme.cardTitleFont)
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                if let activeFilter = selectedExpiryBucketId {
                    Button {
                        selectedExpiryBucketId = nil
                    } label: {
                        HStack(spacing: 4) {
                            Text(activeFilter)
                            Image(systemName: "xmark")
                                .font(.system(size: 8.5, weight: .bold))
                        }
                        .font(SubRadarTheme.font(size: 10, weight: .semibold))
                        .foregroundStyle(SubRadarTheme.radarAccent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(SubRadarTheme.radarAccent.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("显示全部近期到期订阅")
                }
                Text("\(displayedItems.count) 项")
                    .font(SubRadarTheme.font(size: 11, weight: .medium))
                    .foregroundStyle(palette.textMuted)
            }

            if displayedItems.isEmpty {
                emptyChartPlaceholder(
                    title: selectedExpiryBucketId.map { "「\($0)」窗口暂无订阅" } ?? "暂无周期性续订日程",
                    systemImage: "checkmark.seal"
                )
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(displayedItems) { item in
                            let isBucketHovered =
                                hoveredExpiryBucketId != nil && hoveredExpiryBucketId == item.windowLabel
                            Button {
                                onSelectSubscription?(item.subscriptionId)
                            } label: {
                                HStack(spacing: 10) {
                                    upcomingItemIcon(item)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name)
                                            .font(SubRadarTheme.uiFont(size: 12.5, weight: .semibold))
                                            .foregroundStyle(palette.textPrimary)
                                            .lineLimit(1)
                                        Text(
                                            "\(SubRadarFormatter.formatDate(item.nextBillingDate)) · \(item.cycleDisplayText)"
                                        )
                                        .font(SubRadarTheme.font(size: 10.5))
                                        .foregroundStyle(palette.textMuted)
                                        .lineLimit(1)
                                    }

                                    Spacer(minLength: 4)

                                    VStack(alignment: .trailing, spacing: 3) {
                                        Text(
                                            SubRadarFormatter.formatCompactMoney(
                                                item.renewalBaseAmount, currency: summary.baseCurrency)
                                        )
                                        .font(SubRadarTheme.font(size: 12, weight: .bold))
                                        .foregroundStyle(palette.textPrimary)
                                        expiryCountdownPill(item: item)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(
                                    (isBucketHovered
                                        ? SubRadarTheme.radarAccent.opacity(0.10) : palette.inputSurface.opacity(0.75)),
                                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .strokeBorder(
                                            isBucketHovered
                                                ? SubRadarTheme.radarAccent.opacity(0.55)
                                                : palette.borderSubtle.opacity(0.65),
                                            lineWidth: isBucketHovered ? 1.25 : 0.75
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .frame(height: cardHeight ?? 280, alignment: .top)
        .customCard(padding: 18)
    }

    @ViewBuilder
    func upcomingItemIcon(_ item: ExpenseAnalyticsSummary.UpcomingRenewalItem) -> some View {
        if let iconData = item.iconData, let nsImage = NSImage(data: iconData) {
            Image(nsImage: nsImage)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fill)
                .frame(width: 30, height: 30)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        } else {
            let tint = SubRadarTheme.categoryColor(for: CategoryColorKey(rawValue: item.categoryColorToken) ?? .indigo)
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(tint.opacity(0.16))
                .frame(width: 30, height: 30)
                .overlay(
                    Text(String(item.name.prefix(1)).uppercased())
                        .font(SubRadarTheme.font(size: 12, weight: .bold))
                        .foregroundStyle(tint)
                )
        }
    }

    func expiryCountdownPill(item: ExpenseAnalyticsSummary.UpcomingRenewalItem) -> some View {
        let (label, color): (String, Color) = {
            if item.billingCycleType == .oneTime {
                return ("买断 / 按量", SubRadarTheme.categoryColor(for: .cyan))
            }
            let daysRemaining = item.daysRemaining
            if daysRemaining < 0 {
                return ("已逾期 \(-daysRemaining)天", SubRadarTheme.coral)
            } else if daysRemaining == 0 {
                return ("今日到期", SubRadarTheme.coral)
            } else if daysRemaining <= 7 {
                return ("\(daysRemaining) 天后", SubRadarTheme.amber)
            } else if daysRemaining <= 30 {
                return ("\(daysRemaining) 天后", SubRadarTheme.radarAccent)
            } else {
                return ("\(daysRemaining) 天后", SubRadarTheme.emerald)
            }
        }()
        return Text(label)
            .font(SubRadarTheme.font(size: 10, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12), in: Capsule())
    }

    func expiryBucketColor(_ token: String) -> Color {
        switch token {
        case "red": return SubRadarTheme.coral
        case "orange": return SubRadarTheme.amber
        case "blue": return SubRadarTheme.radarAccent
        case "purple": return SubRadarTheme.categoryColor(for: .purple)
        case "green": return SubRadarTheme.emerald
        default: return SubRadarTheme.categoryColor(for: .cyan)
        }
    }
}
