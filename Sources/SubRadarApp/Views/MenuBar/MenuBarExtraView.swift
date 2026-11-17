import SubRadarCore
import SwiftUI

struct MenuBarExtraView: View {
    @Environment(\.radarPalette) private var palette
    @Bindable var viewModel: MainViewModel
    var updateManager: AppUpdateManager? = nil
    let onOpenMainWindow: () -> Void
    let onOpenNewSubscription: () -> Void
    var onOpenSettings: (() -> Void)? = nil

    private var activeCount: Int {
        viewModel.subscriptions.filter { $0.status == .active }.count
    }

    private var expiringCount: Int {
        viewModel.expiringSoonSubscriptions.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerSection
            statusSummaryStrip
            RadarDivider()
            upcomingSection
            RadarDivider()
            footerActions
        }
        .padding(14)
        .frame(width: 344)
        .background(palette.windowBackground)
        .task {
            if viewModel.subscriptions.isEmpty {
                await viewModel.loadAll()
            }
        }
    }

    private var headerSection: some View {
        HStack(spacing: 10) {
            SubRadarBrandMark(size: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text("SubRadar")
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(palette.textPrimary)
                Text("订阅追踪与续费雷达")
                    .font(.system(size: 10.5))
                    .foregroundStyle(palette.textMuted)
            }
            Spacer()
            RadarButton("打开主窗口", systemImage: "macwindow", variant: .secondary, size: .small) {
                onOpenMainWindow()
            }
        }
    }

    private var statusSummaryStrip: some View {
        HStack(spacing: 8) {
            summaryStatTile(
                title: "监控中订阅",
                value: "\(activeCount)",
                unit: "项 / 共 \(viewModel.subscriptions.count) 项",
                icon: "checkmark.seal.fill",
                tint: SubRadarTheme.radarAccent
            )
            summaryStatTile(
                title: "7 天内到期",
                value: "\(expiringCount)",
                unit: expiringCount == 0 ? "近期无续费" : "待核对续费",
                icon: expiringCount == 0 ? "shield.checkmark.fill" : "bell.badge.fill",
                tint: expiringCount == 0 ? SubRadarTheme.emerald : SubRadarTheme.amber
            )
        }
    }

    private func summaryStatTile(
        title: String,
        value: String,
        unit: String,
        icon: String,
        tint: Color
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 26, height: 26)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(palette.textMuted)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(SubRadarTheme.font(size: 15, weight: .bold))
                        .foregroundStyle(palette.textPrimary)
                    Text(unit)
                        .font(.system(size: 10))
                        .foregroundStyle(palette.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.cardSurface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(palette.borderSubtle, lineWidth: 1)
        )
    }

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("7 天内临期提醒")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.textSecondary)
                Spacer()
                if expiringCount > 0 {
                    Button("查看全部") {
                        onOpenMainWindow()
                        viewModel.sidebarSelection = .expiringSoon
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(SubRadarTheme.radarAccent)
                }
            }

            if viewModel.expiringSoonSubscriptions.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(SubRadarTheme.emerald)
                    Text("未来 7 天暂无即将续费项目")
                        .font(.system(size: 12))
                        .foregroundStyle(palette.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .background(palette.cardSurface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(palette.borderSubtle, lineWidth: 1)
                )
            } else {
                VStack(spacing: 6) {
                    ForEach(viewModel.expiringSoonSubscriptions.prefix(5)) { item in
                        upcomingRow(for: item)
                    }
                }
            }
        }
    }

    private func upcomingRow(for item: SubscriptionItem) -> some View {
        let urgency = SubRadarTheme.urgencyColor(for: item)
        return Button {
            onOpenMainWindow()
            Task {
                viewModel.sidebarSelection = .all
                await viewModel.selectSubscription(item.id)
            }
        } label: {
            HStack(spacing: 10) {
                SubscriptionAvatarView(
                    iconData: item.iconData,
                    categoryId: item.categoryId,
                    categories: viewModel.categories,
                    templateId: item.templateId,
                    templates: viewModel.templates,
                    size: 30
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(palette.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: 5) {
                        Circle()
                            .fill(urgency)
                            .frame(width: 5, height: 5)
                        Text(SubRadarFormatter.renewalCountdownText(for: item))
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(urgency)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    Text(SubRadarFormatter.formatCompactMoney(item.effectiveRenewalPrice, currency: item.currency))
                        .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(palette.textPrimary)
                    Text(item.billingCycleType.formattedDisplayName(intervalCount: item.billingCycleDays))
                        .font(.system(size: 9.5))
                        .foregroundStyle(palette.textMuted)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(palette.cardSurface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(palette.borderSubtle, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var footerActions: some View {
        HStack(spacing: 8) {
            RadarButton("快速记一笔", systemImage: "plus.circle.fill", variant: .primary, size: .small) {
                onOpenNewSubscription()
            }

            if let onOpenSettings {
                RadarButton("设置", systemImage: "gearshape", variant: .ghost, size: .small, action: onOpenSettings)
            }

            if let updateManager {
                if let release = updateManager.availableRelease {
                    RadarButton(
                        "更新 v\(release.version)",
                        systemImage: "arrow.down.circle.fill",
                        variant: .secondary,
                        size: .small
                    ) {
                        onOpenMainWindow()
                        updateManager.showUpdatePrompt = true
                    }
                } else {
                    RadarButton("检查更新", systemImage: "arrow.clockwise", variant: .ghost, size: .small) {
                        Task { await updateManager.checkForUpdates(manual: true) }
                    }
                }
            }

            Spacer()

            RadarButton("退出", systemImage: "power", variant: .ghost, size: .small) {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
