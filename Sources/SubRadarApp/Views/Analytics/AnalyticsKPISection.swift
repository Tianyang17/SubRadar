import AppKit
import Charts
import SubRadarCore
import SwiftUI

extension AnalyticsDashboardView {
    func kpiGridSection(summary: ExpenseAnalyticsSummary, isWide: Bool) -> some View {
        let columns = Array(
            repeating: GridItem(.flexible(), spacing: 14),
            count: isWide ? 4 : 2
        )
        let nearest = summary.upcomingRenewals.first
        let nearestCountdown: String =
            if let nearest {
                if nearest.daysRemaining < 0 {
                    "已逾期 \(-nearest.daysRemaining) 天 · \(SubRadarFormatter.formatDate(nearest.nextBillingDate))"
                } else if nearest.daysRemaining == 0 {
                    "今天到期 · \(SubRadarFormatter.formatCompactMoney(nearest.renewalBaseAmount, currency: summary.baseCurrency))"
                } else {
                    "\(nearest.daysRemaining) 天后 (\(SubRadarFormatter.formatDate(nearest.nextBillingDate)))"
                }
            } else {
                "暂无周期性续订任务"
            }

        return LazyVGrid(columns: columns, spacing: 14) {
            kpiCard(
                title: "活跃订阅资产",
                value: "\(summary.activeSubscriptionCount)",
                subtitle: "7天内到期或逾期 \(summary.overdueOrSoonCount) 项",
                tint: SubRadarTheme.radarAccent,
                symbol: "square.stack.3d.up.fill"
            )
            kpiCard(
                title: "最近即将到期",
                value: nearest?.name ?? "暂无临期",
                subtitle: nearestCountdown,
                tint: (nearest?.daysRemaining ?? 99) <= 7 ? SubRadarTheme.amber : SubRadarTheme.emerald,
                symbol: "clock.badge.exclamationmark.fill"
            )
            kpiCard(
                title: "未来 30 天待续",
                value: SubRadarFormatter.formatMoney(summary.upcoming30DaysBaseAmount, currency: summary.baseCurrency),
                subtitle: "未来 30 天续期预估总开销",
                tint: SubRadarTheme.emerald,
                symbol: "calendar.badge.clock"
            )
            kpiCard(
                title: "区间实付总额",
                value: SubRadarFormatter.formatMoney(summary.totalBaseAmount, currency: summary.baseCurrency),
                subtitle:
                    "日均 \(SubRadarFormatter.formatMoney(summary.dailyAverageBaseAmount, currency: summary.baseCurrency)) · \(summary.records.count) 笔流水",
                tint: SubRadarTheme.categoryColor(for: .purple),
                symbol: "banknote.fill"
            )
        }
    }

    func kpiCard(
        title: String,
        value: String,
        subtitle: String,
        tint: Color,
        symbol: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text(title)
                    .font(SubRadarTheme.uiFont(size: 12, weight: .medium))
                    .foregroundStyle(palette.textSecondary)
                Spacer()
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    tint.opacity(palette.isDark ? 0.24 : 0.16),
                                    tint.opacity(palette.isDark ? 0.12 : 0.07)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 28, height: 28)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(tint.opacity(0.22), lineWidth: 0.75)
                        )
                    Image(systemName: symbol)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(tint)
                }
            }
            Text(value)
                .font(SubRadarTheme.font(size: 19, weight: .bold))
                .foregroundStyle(palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(subtitle)
                .font(SubRadarTheme.uiFont(size: 11.5, weight: .regular))
                .foregroundStyle(palette.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .customCard(padding: 16)
    }

    @ViewBuilder
    func apiBalancesSection(summary: ExpenseAnalyticsSummary, isWide: Bool) -> some View {
        let lowCount = summary.apiBalanceItems.filter(\.isLowBalance).count
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "key.radiowaves.forward.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SubRadarTheme.categoryColor(for: .indigo))
                Text("AI API 账户余额")
                    .font(SubRadarTheme.cardTitleFont)
                    .foregroundStyle(palette.textPrimary)

                if lowCount > 0 {
                    Text("\(lowCount) 项低余额预警")
                        .font(SubRadarTheme.font(size: 10.5, weight: .semibold))
                        .foregroundStyle(SubRadarTheme.coral)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(SubRadarTheme.coral.opacity(0.12), in: Capsule())
                }

                Spacer()

                Text(
                    "折合可用余额 \(SubRadarFormatter.formatMoney(summary.totalAPIBalanceBaseAmount, currency: summary.baseCurrency))"
                )
                .font(SubRadarTheme.font(size: 11.5, weight: .semibold))
                .foregroundStyle(palette.textSecondary)
            }

            LazyVGrid(
                columns: [
                    GridItem(
                        .adaptive(minimum: isWide ? 280 : 240, maximum: 460),
                        spacing: 12,
                        alignment: .top
                    )
                ],
                spacing: 12
            ) {
                ForEach(summary.apiBalanceItems) { apiItem in
                    Button {
                        onSelectSubscription?(apiItem.subscriptionId)
                    } label: {
                        HStack(spacing: 10) {
                            SubscriptionAvatarView(
                                iconData: apiItem.iconData,
                                categoryId: SubscriptionCategory.BuiltinID.aiTools,
                                categories: [],
                                templateId: TemplateDefinition.BuiltinID.apiBalance,
                                templates: [],
                                size: 32
                            )

                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(apiItem.name)
                                        .font(SubRadarTheme.uiFont(size: 12.5, weight: .semibold))
                                        .foregroundStyle(palette.textPrimary)
                                        .lineLimit(1)
                                        .layoutPriority(1)
                                    Text(apiItem.providerName)
                                        .font(SubRadarTheme.font(size: 10, weight: .medium))
                                        .foregroundStyle(palette.textMuted)
                                        .lineLimit(1)
                                }
                                Text(
                                    "累计净充值 \(SubRadarFormatter.formatCompactMoney(apiItem.netRechargedBaseAmount, currency: summary.baseCurrency))"
                                )
                                .font(SubRadarTheme.font(size: 10.5))
                                .foregroundStyle(palette.textMuted)
                                .lineLimit(1)
                            }

                            Spacer(minLength: 8)

                            VStack(alignment: .trailing, spacing: 3) {
                                if let bal = apiItem.currentBalance {
                                    Text(SubRadarFormatter.formatMoney(bal, currency: apiItem.currency))
                                        .font(SubRadarTheme.font(size: 13.5, weight: .bold))
                                        .foregroundStyle(
                                            apiItem.isLowBalance ? SubRadarTheme.coral : SubRadarTheme.emerald)
                                } else {
                                    Text("待查询")
                                        .font(SubRadarTheme.font(size: 11.5, weight: .medium))
                                        .foregroundStyle(palette.textMuted)
                                }
                                if let threshold = apiItem.lowThreshold {
                                    Text(
                                        apiItem.isLowBalance
                                            ? "低于阈值 \(SubRadarFormatter.formatMoney(threshold, currency: apiItem.currency))"
                                            : "阈值 \(SubRadarFormatter.formatMoney(threshold, currency: apiItem.currency))"
                                    )
                                    .font(SubRadarTheme.font(size: 9.5, weight: .medium))
                                    .foregroundStyle(apiItem.isLowBalance ? SubRadarTheme.coral : palette.textMuted)
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(palette.inputSurface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(
                                    apiItem.isLowBalance ? SubRadarTheme.coral.opacity(0.35) : palette.borderSubtle,
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .customCard(padding: 18)
    }
}
