import SubRadarCore
import SwiftUI

struct SubscriptionEditorSheet: View {
    @Environment(\.radarPalette) var palette
    @Environment(\.dismiss) var dismiss
    @State var viewModel: EditorViewModel
    let templates: [TemplateDefinition]
    let settings: AppSettingsStore
    var onCategoriesChanged: (() async -> Void)? = nil
    let onSaved: (SubscriptionItem) async -> Void

    @State var showDiscardConfirm = false
    @State var showSaveConfirm = false

    init(
        viewModel: EditorViewModel,
        templates: [TemplateDefinition],
        settings: AppSettingsStore = AppSettingsStore(),
        onCategoriesChanged: (() async -> Void)? = nil,
        onSaved: @escaping (SubscriptionItem) async -> Void
    ) {
        self._viewModel = State(initialValue: viewModel)
        self.templates = templates
        self.settings = settings
        self.onCategoriesChanged = onCategoriesChanged
        self.onSaved = onSaved
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(viewModel.isEditing ? "编辑订阅" : "新建订阅")
                    .font(SubRadarTheme.sheetTitleFont)
                    .foregroundStyle(palette.textPrimary)

                Spacer()

                RadarButton("取消", variant: .ghost) {
                    if viewModel.hasUnsavedChanges {
                        showDiscardConfirm = true
                    } else {
                        dismiss()
                    }
                }
                .keyboardShortcut(.cancelAction)

                RadarButton(
                    viewModel.isSaving ? "保存中..." : "保存",
                    systemImage: "checkmark",
                    variant: .primary
                ) {
                    if viewModel.isEditing && viewModel.hasUnsavedChanges {
                        showSaveConfirm = true
                    } else {
                        Task { await performSave() }
                    }
                }
                .disabled(viewModel.isSaving)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(palette.sidebarBackground)

            RadarDivider()

            SubscriptionEditorFormBody(
                viewModel: viewModel,
                templates: templates,
                settings: settings,
                defaultQuickImportExpanded: !viewModel.isEditing,
                onCategoriesChanged: onCategoriesChanged
            )
        }
        .frame(minWidth: 680, idealWidth: 760, minHeight: 580, idealHeight: 740)
        .background(palette.windowBackground)
        .interactiveDismissDisabled(viewModel.hasUnsavedChanges)
        .sheet(isPresented: $showDiscardConfirm) {
            RadarConfirmSheet(
                title: "放弃未保存的修改？",
                message: "关闭窗口后，你刚刚填写或更改的订阅内容将不会保存。",
                details: viewModel.changeSummaryLines,
                confirmTitle: "放弃修改",
                cancelTitle: "继续编辑",
                isDestructive: true
            ) {
                dismiss()
            }
            .environment(\.radarPalette, palette)
            .preferredColorScheme(palette.colorScheme)
        }
        .sheet(isPresented: $showSaveConfirm) {
            let displayName = viewModel.name.trimmingCharacters(in: .whitespacesAndNewlines)
            RadarConfirmSheet(
                title: "确认保存对「\(displayName.isEmpty ? "当前订阅" : displayName)」的修改？",
                message: "以下内容或历史/扩展字段已发生变更，确认后将覆盖原记录：",
                details: viewModel.changeSummaryLines,
                confirmTitle: "确认保存",
                cancelTitle: "返回检查",
                isDestructive: false
            ) {
                Task { await performSave() }
            }
            .environment(\.radarPalette, palette)
            .preferredColorScheme(palette.colorScheme)
        }
    }

    private func performSave() async {
        do {
            let saved = try await viewModel.save()
            await onSaved(saved)
            dismiss()
        } catch {
            // validationErrorMessage 已在 ViewModel 中填充
        }
    }
}
