import SubRadarCore
import SwiftUI

struct MainSplitView: View {
    @Environment(\.radarPalette) var palette
    @Bindable var viewModel: MainViewModel
    @Binding var activeEditorSheet: EditorSheetMode?
    var updateManager: AppUpdateManager? = nil

    @State var isSidebarExpanded: Bool = true
    @State var showNarrowDrawer: Bool = false
    @State var showingNarrowDetail: Bool = false
    @State var analyticsViewModel: AnalyticsViewModel?
    @State var templateManagerViewModel: TemplateManagerViewModel?
    @State var activeCategorySheet: CategoryEditorSheet.Mode?

    enum EditorSheetMode: Identifiable {
        case create(defaultTemplateId: UUID?)
        case edit(SubscriptionItem)

        var id: String {
            switch self {
            case .create(let tid): return "create-\(tid?.uuidString ?? "default")"
            case .edit(let item): return "edit-\(item.id.uuidString)"
            }
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let isCompactWidth = proxy.size.width < 900
            let isNarrowDetailMode = proxy.size.width < 760

            ZStack(alignment: .leading) {
                HStack(spacing: 0) {
                    if !isCompactWidth && isSidebarExpanded {
                        SidebarView(
                            viewModel: viewModel,
                            onOpenNewSubscription: openCreateSheet,
                            onCreateCategory: { activeCategorySheet = .create },
                            onEditCategory: { category in activeCategorySheet = .edit(category) },
                            onSelectDestination: {
                                showingNarrowDetail = false
                            }
                        )
                        .frame(width: proxy.size.width >= 1080 ? 228 : 210)
                        .transition(.move(edge: .leading))

                        RadarDivider(vertical: true)
                    }

                    VStack(spacing: 0) {
                        topControlBar(
                            isCompactWidth: isCompactWidth,
                            isNarrowDetailMode: isNarrowDetailMode
                        )

                        RadarDivider()

                        mainDestinationView(isNarrowDetailMode: isNarrowDetailMode)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .background(palette.windowBackground)
                }

                // 窄屏抽屉侧边栏遮罩与浮层
                if isCompactWidth && showNarrowDrawer {
                    Color.black.opacity(palette.isDark ? 0.55 : 0.28)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.snappy(duration: 0.2)) {
                                showNarrowDrawer = false
                            }
                        }
                        .zIndex(5)

                    HStack(spacing: 0) {
                        SidebarView(
                            viewModel: viewModel,
                            onOpenNewSubscription: {
                                showNarrowDrawer = false
                                openCreateSheet()
                            },
                            onCreateCategory: {
                                showNarrowDrawer = false
                                activeCategorySheet = .create
                            },
                            onEditCategory: { category in
                                showNarrowDrawer = false
                                activeCategorySheet = .edit(category)
                            },
                            onSelectDestination: {
                                showingNarrowDetail = false
                                withAnimation(.snappy(duration: 0.2)) {
                                    showNarrowDrawer = false
                                }
                            }
                        )
                        .frame(width: 230)

                        RadarDivider(vertical: true)
                    }
                    .shadow(color: Color.black.opacity(0.28), radius: 22, x: 6)
                    .transition(.move(edge: .leading))
                    .zIndex(6)
                }

                if let toast = viewModel.toastMessage {
                    VStack {
                        ToastBannerView(message: toast) {
                            withAnimation(.snappy(duration: 0.22)) {
                                viewModel.clearToast()
                            }
                        }
                        .padding(.top, 54)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(20)
                }
            }
            // 将布局过渡仅作用于窄屏抽屉与提示，避免全树隐式动画联动 Swift Charts Canvas 触发 macOS Layout 重入崩溃
            .animation(.snappy(duration: 0.20), value: showNarrowDrawer)
            .animation(.snappy(duration: 0.22), value: viewModel.toastMessage)
        }
        .frame(minWidth: 680, minHeight: 520)
        .background(WindowFullScreenConfigurator())
        .background(palette.windowBackground)
        .background {
            Group {
                Button("") { viewModel.openSettings() }
                    .keyboardShortcut(",", modifiers: .command)
                Button("") { viewModel.sidebarSelection = .analytics }
                    .keyboardShortcut("1", modifiers: .command)
                Button("") { viewModel.sidebarSelection = .all }
                    .keyboardShortcut("2", modifiers: .command)
            }
            .opacity(0)
            .frame(width: 0, height: 0)
        }
        .sheet(item: $activeEditorSheet) { mode in
            let editorVM: EditorViewModel = {
                switch mode {
                case .create(let defaultCategoryId):
                    return EditorViewModel(
                        container: viewModel.container,
                        templates: viewModel.templates,
                        categories: viewModel.categories,
                        existingItem: nil,
                        defaultCategoryId: defaultCategoryId,
                        defaultCurrency: viewModel.baseCurrency,
                        defaultReminderDays: viewModel.settings.defaultReminderDays
                    )
                case .edit(let item):
                    return EditorViewModel(
                        container: viewModel.container,
                        templates: viewModel.templates,
                        categories: viewModel.categories,
                        existingItem: item
                    )
                }
            }()

            SubscriptionEditorSheet(
                viewModel: editorVM,
                templates: viewModel.templates,
                settings: viewModel.settings,
                onCategoriesChanged: {
                    await viewModel.loadAll()
                }
            ) { savedItem in
                await viewModel.loadAll()
                await viewModel.selectSubscription(savedItem.id)
                await analyticsViewModel?.reloadAnalytics()
                viewModel.showToast(editorVM.isEditing ? "已更新「\(savedItem.name)」" : "已添加「\(savedItem.name)」")
            }
            .radarTheme(viewModel.settings.themeMode)
        }
        .sheet(item: $activeCategorySheet) { mode in
            CategoryEditorSheet(mode: mode, viewModel: viewModel)
                .radarTheme(viewModel.settings.themeMode)
        }
        .task {
            if analyticsViewModel == nil {
                let vm = AnalyticsViewModel(container: viewModel.container)
                vm.baseCurrency = viewModel.baseCurrency
                analyticsViewModel = vm
            }
            if templateManagerViewModel == nil {
                templateManagerViewModel = TemplateManagerViewModel(container: viewModel.container)
            }
            await viewModel.loadAll()
        }
        .onChange(of: viewModel.baseCurrency) { _, newCurrency in
            analyticsViewModel?.baseCurrency = newCurrency
        }
        .sheet(
            isPresented: Binding(
                get: { updateManager?.showUpdatePrompt ?? false },
                set: { updateManager?.showUpdatePrompt = $0 }
            )
        ) {
            if let updateManager {
                AppUpdatePromptSheet(updateManager: updateManager)
                    .radarTheme(viewModel.settings.themeMode)
            }
        }
    }
}
