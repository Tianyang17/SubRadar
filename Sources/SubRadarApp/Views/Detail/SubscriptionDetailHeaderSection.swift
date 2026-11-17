import SubRadarCore
import SwiftUI

extension SubscriptionDetailView {
    @ViewBuilder
    var headerSection: some View {
        let heroTint = SubRadarTheme.dominantColor(from: item.iconData, fallbackTemplateId: item.templateId)
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 16) {
                headerIdentity
                Spacer()
                headerActions
            }
            VStack(alignment: .leading, spacing: 14) {
                headerIdentity
                headerActions
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: SubRadarTheme.cardCornerRadius, style: .continuous)
                    .fill(palette.cardSurface)
                RadialGradient(
                    colors: [heroTint.opacity(palette.isDark ? 0.16 : 0.08), Color.clear],
                    center: .topTrailing,
                    startRadius: 4,
                    endRadius: 240
                )
                .allowsHitTesting(false)
                RoundedRectangle(cornerRadius: SubRadarTheme.cardCornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(colors: [palette.topHighlight, .clear], startPoint: .top, endPoint: .bottom),
                        lineWidth: 1
                    )
                    .padding(0.5)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: SubRadarTheme.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: SubRadarTheme.cardCornerRadius, style: .continuous)
                .strokeBorder(palette.borderSubtle, lineWidth: 1)
        )
        .shadow(color: palette.isDark ? Color.black.opacity(0.24) : palette.cardShadow, radius: 2, x: 0, y: 1)
        .shadow(color: palette.isDark ? Color.clear : Color.black.opacity(0.025), radius: 10, x: 0, y: 4)
    }

    var headerIdentity: some View {
        HStack(spacing: 14) {
            SubscriptionAvatarView(
                iconData: item.iconData,
                categoryId: item.categoryId,
                categories: viewModel.categories,
                templateId: item.templateId,
                templates: viewModel.templates,
                size: 58
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(item.name)
                    .font(SubRadarTheme.uiFont(size: 20, weight: .bold))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if let category = viewModel.category(for: item.categoryId) {
                        Label(category.name, systemImage: category.iconSymbol)
                            .font(SubRadarTheme.uiFont(size: 12, weight: .semibold))
                            .foregroundStyle(SubRadarTheme.categoryColor(for: category.colorKey))
                    }
                    if let template = viewModel.template(for: item.templateId) {
                        Text("•")
                            .foregroundStyle(palette.textMuted)
                        Text(template.name)
                            .font(SubRadarTheme.uiFont(size: 12))
                            .foregroundStyle(palette.textSecondary)
                    }
                    Text("•")
                        .foregroundStyle(palette.textMuted)
                    Text(item.status.displayName)
                        .font(SubRadarTheme.uiFont(size: 12, weight: .semibold))
                        .foregroundStyle(SubRadarTheme.statusColor(for: item.status))
                    CountdownBadge(item: item)
                }
            }
        }
    }

    var headerActions: some View {
        HStack(spacing: 8) {
            if item.templateId == TemplateDefinition.BuiltinID.apiBalance {
                RadarButton(
                    viewModel.isRefreshingAPIBalance ? "查询中..." : "刷新余额",
                    systemImage: "arrow.clockwise",
                    variant: .primary
                ) {
                    Task { await viewModel.refreshAPIBalance(for: item) }
                }
                .disabled(viewModel.isRefreshingAPIBalance)
            }

            if item.billingCycleType != .oneTime {
                RadarButton("立即续订", systemImage: "bolt.fill", variant: .primary) {
                    renewPriceText = NSDecimalNumber(decimal: item.effectiveRenewalPrice).stringValue
                    showRenewPopover = true
                }
            }

            RadarButton("编辑", systemImage: "pencil", variant: .secondary) {
                onEdit(item)
            }

            RadarButton("", systemImage: "trash", variant: .danger) {
                showDeleteConfirm = true
            }
            .help("删除订阅")
        }
    }

    var parsedCurrentAPIBalance: Decimal {
        let raw = item.fieldValue(forKey: "current_balance")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "0"
        return Decimal(string: raw) ?? 0
    }

    var parsedLowBalanceThreshold: Decimal? {
        guard
            let raw = item.fieldValue(forKey: "low_balance_threshold")?.trimmingCharacters(in: .whitespacesAndNewlines),
            let threshold = Decimal(string: raw),
            threshold > 0
        else {
            return nil
        }
        return threshold
    }

    var isLowAPIBalance: Bool {
        guard item.templateId == TemplateDefinition.BuiltinID.apiBalance,
            let threshold = parsedLowBalanceThreshold
        else {
            return false
        }
        return parsedCurrentAPIBalance <= threshold
    }

    var lowBalanceBanner: some View {
        let thresholdText =
            parsedLowBalanceThreshold.map { SubRadarFormatter.formatMoney($0, currency: item.currency) } ?? ""
        let currentText = SubRadarFormatter.formatMoney(parsedCurrentAPIBalance, currency: item.currency)
        return HStack(spacing: 12) {
            Image(systemName: "fuelpump.exclamationmark.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(SubRadarTheme.amber)

            VStack(alignment: .leading, spacing: 2) {
                Text("API 额度已低于告警阈值")
                    .font(SubRadarTheme.uiFont(size: 13, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)
                Text("当前剩余 \(currentText)（阈值 \(thresholdText)），建议尽快通过「+ 记一笔」记录充值并补充账户余额。")
                    .font(SubRadarTheme.font(size: 11.5))
                    .foregroundStyle(palette.textSecondary)
            }

            Spacer(minLength: 8)

            RadarButton("立即刷新", systemImage: "arrow.clockwise", variant: .secondary, size: .small) {
                Task { await viewModel.refreshAPIBalance(for: item) }
            }
            .disabled(viewModel.isRefreshingAPIBalance)
        }
        .padding(14)
        .background(
            SubRadarTheme.amber.opacity(palette.isDark ? 0.14 : 0.09),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(SubRadarTheme.amber.opacity(0.32), lineWidth: 1)
        )
    }

    var renewPopoverContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("确认本次续订")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(palette.textPrimary)

            Text("确认后将自动累加一笔账单流水，并将下次续订日期推进 1 个周期（\(item.cycleDisplayName)）。")
                .font(.system(size: 12))
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Text("本次实付 (\(item.currency))")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(palette.textSecondary)
                RadarTextField(
                    "金额",
                    text: $renewPriceText,
                    prefixText: CommonCurrency.symbol(for: item.currency),
                    monospaced: true
                )
                .frame(width: 128)
            }

            HStack {
                Spacer()
                RadarButton("取消", variant: .ghost, size: .small) {
                    showRenewPopover = false
                }
                RadarButton("确认续订", systemImage: "checkmark", variant: .primary, size: .small) {
                    let customPrice = Decimal(string: renewPriceText)
                    showRenewPopover = false
                    Task { await viewModel.renewSubscription(item, actualPrice: customPrice) }
                }
            }
        }
        .padding(20)
        .frame(width: 360)
        .background(palette.windowBackground)
    }
}
