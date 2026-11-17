import SubRadarCore
import SwiftUI

struct SidebarView: View {
    @Environment(\.radarPalette) private var palette
    @Bindable var viewModel: MainViewModel
    let onOpenNewSubscription: () -> Void
    let onCreateCategory: () -> Void
    let onEditCategory: (SubscriptionCategory) -> Void
    var onSelectDestination: (() -> Void)? = nil

    @State private var pendingDeleteCategory: SubscriptionCategory?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                SubRadarBrandMark(size: 28)

                VStack(alignment: .leading, spacing: 0) {
                    Text("SubRadar")
                        .font(SubRadarTheme.font(size: 13.5, weight: .bold))
                        .foregroundStyle(palette.textPrimary)
                }

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 36)
            .padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    sidebarSection("概览") {
                        navRow(
                            title: "订阅概览",
                            systemImage: "chart.bar.xaxis",
                            tint: SubRadarTheme.emerald,
                            destination: .analytics
                        )
                    }

                    sidebarSection("订阅雷达") {
                        navRow(
                            title: "全部订阅",
                            systemImage: "square.grid.2x2.fill",
                            tint: SubRadarTheme.radarAccent,
                            count: viewModel.count(for: .all),
                            destination: .all
                        )
                        navRow(
                            title: "7天内到期",
                            systemImage: "bell.badge.fill",
                            tint: SubRadarTheme.amber,
                            count: viewModel.count(for: .expiringSoon),
                            destination: .expiringSoon
                        )
                        navRow(
                            title: "已暂停 / 逾期",
                            systemImage: "pause.circle.fill",
                            tint: palette.textMuted,
                            count: viewModel.count(for: .expiredOrPaused),
                            destination: .expiredOrPaused
                        )
                    }

                    sidebarSection(
                        "分类",
                        trailingAction: {
                            RadarIconButton(
                                systemImage: "plus",
                                size: 20,
                                helpText: "新建分类"
                            ) {
                                onCreateCategory()
                            }
                        }
                    ) {
                        ForEach(viewModel.categories) { category in
                            navRow(
                                title: category.name,
                                systemImage: category.iconSymbol,
                                tint: SubRadarTheme.categoryColor(for: category.colorKey),
                                count: viewModel.count(for: .category(category.id)),
                                destination: .category(category.id)
                            )
                            .radarContextMenu {
                                RadarContextMenuItem(title: "编辑分类...", systemImage: "pencil") {
                                    onEditCategory(category)
                                }

                                if !category.isBuiltin {
                                    RadarContextMenuItem(title: "删除分类", systemImage: "trash", isDestructive: true) {
                                        pendingDeleteCategory = category
                                    }
                                }
                            }
                        }
                    }

                    sidebarSection("扩展配置") {
                        navRow(
                            title: "字段模版管理",
                            systemImage: "slider.horizontal.3",
                            tint: palette.textSecondary,
                            destination: .templateManager
                        )
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
            .scrollIndicators(.never)

            RadarDivider()

            VStack(spacing: 8) {
                RadarSidebarNavRow(
                    title: "设置",
                    systemImage: "gearshape.fill",
                    tint: palette.textSecondary,
                    isSelected: viewModel.sidebarSelection == .settings
                ) {
                    viewModel.openSettings()
                    onSelectDestination?()
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        }
        .background(palette.sidebarBackground)
        .sheet(item: $pendingDeleteCategory) { category in
            RadarConfirmSheet(
                title: "确定删除分类「\(category.name)」？",
                message: "删除后原属于该分类的订阅条目不会丢失，系统将自动归类到默认分类。",
                confirmTitle: "确认删除分类",
                cancelTitle: "取消",
                isDestructive: true
            ) {
                Task { await viewModel.deleteCategory(category) }
            }
            .radarTheme(viewModel.settings.themeMode)
        }
    }

    @ViewBuilder
    private func sidebarSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(SubRadarTheme.uiFont(size: 11, weight: .semibold))
                .foregroundStyle(palette.textMuted)
                .padding(.horizontal, 10)
                .padding(.bottom, 2)
            content()
        }
    }

    @ViewBuilder
    private func sidebarSection<Trailing: View, Content: View>(
        _ title: String,
        @ViewBuilder trailingAction: () -> Trailing,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title)
                    .font(SubRadarTheme.uiFont(size: 11, weight: .semibold))
                    .foregroundStyle(palette.textMuted)
                Spacer()
                trailingAction()
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 2)
            content()
        }
    }

    @ViewBuilder
    private func navRow(
        title: String,
        systemImage: String,
        tint: Color,
        count: Int? = nil,
        destination: SidebarDestination
    ) -> some View {
        RadarSidebarNavRow(
            title: title,
            systemImage: systemImage,
            tint: tint,
            count: count,
            isSelected: viewModel.sidebarSelection == destination
        ) {
            viewModel.sidebarSelection = destination
            onSelectDestination?()
        }
    }
}
