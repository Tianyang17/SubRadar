import AppKit
import SubRadarCore
import SwiftUI
import UniformTypeIdentifiers

struct SubscriptionEditorFormBody: View {
    @Environment(\.radarPalette) var palette
    @Bindable var viewModel: EditorViewModel
    let templates: [TemplateDefinition]
    let settings: AppSettingsStore
    var onCategoriesChanged: (() async -> Void)? = nil

    @State var showImagePicker = false
    @State var showInlineCategorySheet = false
    @State var isQuickImportExpanded: Bool
    @State var newCategoryName = ""
    @State var newCategorySymbol = "sparkles"
    @State var newCategoryColor: CategoryColorKey = .indigo
    @State var presetSearchQuery = ""
    @State var selectedPresetGroup: PopularSoftwareGroup? = nil
    @State var selectedInfraKind: InfraAssetKind = .host
    @State var newFieldLabel = ""
    @State var newFieldType: CustomFieldType = .text
    @State var draggingCustomFieldId: UUID?
    @State var activeIconTab: IconImportTab = .appStore
    @State var showFaviconBar = false
    @FocusState var isFaviconFieldFocused: Bool

    enum IconImportTab: String, CaseIterable, Identifiable {
        case appStore = "App Store"
        case localApp = "本机应用"
        var id: String { rawValue }
    }

    enum InfraAssetKind: String, CaseIterable, Identifiable {
        case host = "主机 / VPS"
        case domain = "域名资产"
        var id: String { rawValue }
    }

    let reminderDayOptions: [Int] = SubscriptionItem.reminderDayOptions

    init(
        viewModel: EditorViewModel,
        templates: [TemplateDefinition],
        settings: AppSettingsStore,
        defaultQuickImportExpanded: Bool? = nil,
        onCategoriesChanged: (() async -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.templates = templates
        self.settings = settings
        self.onCategoriesChanged = onCategoriesChanged
        let initialExpanded = defaultQuickImportExpanded ?? !viewModel.isEditing
        self._isQuickImportExpanded = State(initialValue: initialExpanded)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let errorMsg = viewModel.validationErrorMessage {
                    Label(errorMsg, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(SubRadarTheme.coral)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            SubRadarTheme.coral.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(SubRadarTheme.coral.opacity(0.3), lineWidth: 1)
                        )
                }

                quickImportCard
                identityConfirmationCard
                billingConfigurationCard
                customFieldsEditorCard
                notesEditorCard
            }
            .padding(20)
        }
        .background(palette.windowBackground)
        .fileImporter(
            isPresented: $showImagePicker,
            allowedContentTypes: [.image, .icns],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result,
                let url = urls.first,
                let data = try? Data(contentsOf: url)
            {
                viewModel.importUploadedImageData(data)
            }
        }
        .sheet(isPresented: $showInlineCategorySheet) {
            inlineCategorySheet
                .environment(\.radarPalette, palette)
                .preferredColorScheme(palette.colorScheme)
        }
        .onChange(of: viewModel.selectedTemplateId) { _, newTemplateId in
            if newTemplateId == TemplateDefinition.BuiltinID.domain {
                selectedInfraKind = .domain
            } else if newTemplateId == TemplateDefinition.BuiltinID.vps {
                selectedInfraKind = .host
            }
        }
    }

    private var inlineCategorySheet: some View {
        let selectedTint = SubRadarTheme.categoryColor(for: newCategoryColor)
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("新建业务分类")
                    .font(SubRadarTheme.sheetTitleFont)
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                RadarButton("取消", variant: .ghost, size: .small) {
                    showInlineCategorySheet = false
                }
                RadarButton("创建并选用", systemImage: "checkmark", variant: .primary, size: .small) {
                    Task {
                        if (try? await viewModel.createCategoryInline(
                            name: newCategoryName,
                            iconSymbol: newCategorySymbol,
                            colorKey: newCategoryColor
                        )) != nil {
                            await onCategoriesChanged?()
                            showInlineCategorySheet = false
                        }
                    }
                }
                .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            RadarDivider()

            RadarTextField("分类名称（如：AI 工具、流媒体、开发服务）", text: $newCategoryName)

            VStack(alignment: .leading, spacing: 8) {
                RadarSectionTitle("图标与标识色")
                RadarSymbolPickerGrid(selection: $newCategorySymbol, accentColor: selectedTint)
                HStack(spacing: 10) {
                    ForEach(CategoryColorKey.allCases) { key in
                        let color = SubRadarTheme.categoryColor(for: key)
                        let isSelected = newCategoryColor == key
                        Button {
                            newCategoryColor = key
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(color)
                                    .frame(width: 24, height: 24)
                                if isSelected {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(palette.textPrimary, lineWidth: 1.5)
                                        .frame(width: 30, height: 30)
                                }
                            }
                            .frame(width: 30, height: 30)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
            }
        }
        .padding(20)
        .frame(width: 440)
        .background(palette.windowBackground)
    }
}
