import SubRadarCore
import SwiftUI

struct SubscriptionListView: View {
    @Environment(\.radarPalette) private var palette
    @Bindable var viewModel: MainViewModel
    let onOpenNewSubscription: () -> Void
    let onEditSubscription: (SubscriptionItem) -> Void
    var onSelectSubscriptionItem: (() -> Void)? = nil

    @State private var hoveredId: UUID?
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                RadarTextField(
                    "搜索名称、IP、域名或备注...",
                    text: $viewModel.searchQuery,
                    systemImage: "magnifyingglass",
                    showClearButton: true,
                    focusBinding: $isSearchFocused
                )
                .background {
                    Button("") { isSearchFocused = true }
                        .keyboardShortcut("f", modifiers: .command)
                        .opacity(0)
                        .allowsHitTesting(false)
                }

                RadarSelectMenu(
                    options: SubscriptionSortOption.allCases,
                    selection: $viewModel.sortOption,
                    label: { $0.displayName }
                )
                .help("排序方式")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            RadarDivider()

            if viewModel.filteredSubscriptions.isEmpty {
                emptyListPlaceholder
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.filteredSubscriptions) { item in
                            SubscriptionRowCard(
                                item: item,
                                categories: viewModel.categories,
                                templates: viewModel.templates,
                                isSelected: viewModel.selectedSubscriptionId == item.id,
                                isHovered: hoveredId == item.id,
                                onSelect: {
                                    Task {
                                        await viewModel.selectSubscription(item.id)
                                        onSelectSubscriptionItem?()
                                    }
                                },
                                onQuickRenew: {
                                    Task { await viewModel.renewSubscription(item) }
                                },
                                onEdit: {
                                    onEditSubscription(item)
                                }
                            )
                            .onHover { hovering in
                                withAnimation(.snappy(duration: 0.16)) {
                                    hoveredId = hovering ? item.id : (hoveredId == item.id ? nil : hoveredId)
                                }
                            }
                        }
                    }
                    .padding(10)
                }
            }
        }
        .background(palette.windowBackground)
    }

    private var emptyListPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(palette.textMuted)

            Text("暂无匹配订阅")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(palette.textPrimary)

            Text(viewModel.searchQuery.isEmpty ? "点击右上角「新建订阅」添加你的第一条服务或数字资产" : "换个关键词或清除筛选条件试试")
                .font(.system(size: 12))
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            if viewModel.searchQuery.isEmpty {
                RadarButton("新建订阅", systemImage: "plus", variant: .primary, size: .small, action: onOpenNewSubscription)
            } else {
                RadarButton("清除搜索", variant: .secondary, size: .small) {
                    viewModel.searchQuery = ""
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SubscriptionRowCard: View {
    @Environment(\.radarPalette) private var palette
    let item: SubscriptionItem
    let categories: [SubscriptionCategory]
    let templates: [TemplateDefinition]
    let isSelected: Bool
    let isHovered: Bool
    let onSelect: () -> Void
    let onQuickRenew: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            SubscriptionAvatarView(
                iconData: item.iconData,
                categoryId: item.categoryId,
                categories: categories,
                templateId: item.templateId,
                templates: templates,
                size: 42
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(palette.textPrimary)
                        .lineLimit(1)
                    if item.autoRenew && item.billingCycleType != .oneTime {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(palette.textMuted)
                            .help("已开启自动续费")
                    }
                }

                HStack(spacing: 6) {
                    CountdownBadge(item: item)
                    if let category = CategoryPresetManager.category(for: item.categoryId, from: categories) {
                        Text(category.name)
                            .font(.system(size: 11))
                            .foregroundStyle(palette.textMuted)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 3) {
                Text(SubRadarFormatter.formatCompactMoney(item.effectiveRenewalPrice, currency: item.currency))
                    .font(SubRadarTheme.font(size: 13, weight: .bold))
                    .foregroundStyle(palette.textPrimary)

                Text(item.cycleDisplayName)
                    .font(SubRadarTheme.font(size: 11))
                    .foregroundStyle(palette.textMuted)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(borderColor, lineWidth: isSelected ? 1.5 : 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .radarContextMenu {
            RadarContextMenuItem(title: "复制订阅名称", systemImage: "doc.on.doc") {
                ClipboardHelper.copy(item.name)
            }
            if let ssh = item.sshCommand {
                RadarContextMenuItem(title: "复制 SSH 命令", systemImage: "terminal.fill") {
                    ClipboardHelper.copy(ssh)
                }
            }
        }
    }

    private var cardBackground: Color {
        if isSelected {
            return SubRadarTheme.radarAccent.opacity(palette.isDark ? 0.16 : 0.10)
        } else if isHovered {
            return palette.elevatedSurface
        } else {
            return palette.cardSurface.opacity(0.6)
        }
    }

    private var borderColor: Color {
        if isSelected {
            return SubRadarTheme.radarAccent.opacity(0.55)
        } else if isHovered {
            return palette.borderStrong
        } else {
            return palette.borderSubtle
        }
    }
}
