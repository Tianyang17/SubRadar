import SubRadarCore
import SwiftUI

extension MainSplitView {
    func topControlBar(isCompactWidth: Bool, isNarrowDetailMode: Bool) -> some View {
        HStack(spacing: 10) {
            RadarIconButton(
                systemImage: "sidebar.left",
                size: 30,
                helpText: isSidebarExpanded && !isCompactWidth ? "收起侧边栏" : "展开侧边栏"
            ) {
                withAnimation(.snappy(duration: 0.22)) {
                    if isCompactWidth {
                        showNarrowDrawer.toggle()
                    } else {
                        isSidebarExpanded.toggle()
                    }
                }
            }

            if isNarrowDetailMode && isListDestination && showingNarrowDetail {
                RadarButton("返回列表", systemImage: "chevron.left", variant: .secondary, size: .small) {
                    withAnimation(.snappy(duration: 0.2)) {
                        showingNarrowDetail = false
                    }
                }
            } else {
                Text(currentDestinationTitle)
                    .font(SubRadarTheme.sectionTitleFont)
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            RadarButton("新建订阅", systemImage: "plus", variant: .primary, size: .small, action: openCreateSheet)
                .keyboardShortcut("n", modifiers: .command)
                .help("新建订阅 (Cmd+N)")
        }
        .padding(.horizontal, 16)
        .frame(height: 46)
        .background(palette.sidebarBackground.opacity(0.72))
    }

    @ViewBuilder
    func mainDestinationView(isNarrowDetailMode: Bool) -> some View {
        switch viewModel.sidebarSelection {
        case .analytics, nil:
            if let analyticsVM = analyticsViewModel {
                AnalyticsDashboardView(
                    viewModel: analyticsVM,
                    onCurrencyChanged: { newCurrency in
                        Task { await viewModel.updateBaseCurrency(newCurrency) }
                    },
                    onSelectSubscription: { subId in
                        viewModel.sidebarSelection = .all
                        viewModel.selectedSubscriptionId = subId
                        showingNarrowDetail = true
                    }
                )
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

        case .templateManager:
            if let tmVM = templateManagerViewModel {
                TemplateManagerView(viewModel: tmVM) {
                    await viewModel.loadAll()
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

        case .settings:
            SettingsView(viewModel: viewModel, updateManager: updateManager)

        default:
            subscriptionWorkspaceView(isNarrowDetailMode: isNarrowDetailMode)
        }
    }

    @ViewBuilder
    func subscriptionWorkspaceView(isNarrowDetailMode: Bool) -> some View {
        if isNarrowDetailMode {
            if showingNarrowDetail, let selected = viewModel.selectedSubscription {
                SubscriptionDetailView(
                    viewModel: viewModel,
                    item: selected,
                    onEdit: { item in
                        activeEditorSheet = .edit(item)
                    }
                )
            } else {
                SubscriptionListView(
                    viewModel: viewModel,
                    onOpenNewSubscription: openCreateSheet,
                    onEditSubscription: { item in
                        activeEditorSheet = .edit(item)
                    },
                    onSelectSubscriptionItem: {
                        showingNarrowDetail = true
                    }
                )
            }
        } else {
            HStack(spacing: 0) {
                SubscriptionListView(
                    viewModel: viewModel,
                    onOpenNewSubscription: openCreateSheet,
                    onEditSubscription: { item in
                        activeEditorSheet = .edit(item)
                    }
                )
                .frame(width: 310)

                RadarDivider(vertical: true)

                if let selected = viewModel.selectedSubscription {
                    SubscriptionDetailView(
                        viewModel: viewModel,
                        item: selected,
                        onEdit: { item in
                            activeEditorSheet = .edit(item)
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    emptyDetailPlaceholder
                }
            }
        }
    }

    private var emptyDetailPlaceholder: some View {
        VStack(spacing: 14) {
            SubRadarBrandMark(size: 56)

            Text("选择或创建一个订阅")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(palette.textPrimary)

            Text("支持流媒体会员、VPS 服务器、域名资产与软件激活码动态模版")
                .font(.system(size: 13))
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)

            RadarButton("新建订阅", systemImage: "plus", variant: .primary, action: openCreateSheet)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    var isListDestination: Bool {
        switch viewModel.sidebarSelection {
        case .all, .expiringSoon, .expiredOrPaused, .category:
            return true
        case .analytics, .templateManager, .settings, nil:
            return false
        }
    }

    private var currentDestinationTitle: String {
        switch viewModel.sidebarSelection {
        case .analytics, nil:
            return "订阅概览"
        case .all:
            return "全部订阅"
        case .expiringSoon:
            return "7天内到期"
        case .expiredOrPaused:
            return "已暂停 / 逾期"
        case .category(let cid):
            return viewModel.category(for: cid)?.name ?? "分类列表"
        case .templateManager:
            return "字段模版管理"
        case .settings:
            return "应用设置"
        }
    }

    func openCreateSheet() {
        let defaultCategoryId: UUID?
        if case .category(let cid) = viewModel.sidebarSelection {
            defaultCategoryId = cid
        } else {
            defaultCategoryId = nil
        }
        activeEditorSheet = .create(defaultTemplateId: defaultCategoryId)
    }
}
