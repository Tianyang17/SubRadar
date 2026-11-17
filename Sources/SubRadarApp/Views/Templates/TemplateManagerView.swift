import SubRadarCore
import SwiftUI

struct TemplateManagerView: View {
    @Environment(\.radarPalette) private var palette
    @State var viewModel: TemplateManagerViewModel
    let onTemplatesChanged: () async -> Void

    @State private var editingTemplate: TemplateDefinition?
    @State private var inspectingTemplate: TemplateDefinition?
    @State private var pendingDeleteTemplate: TemplateDefinition?
    @State private var showTemplateSheet = false
    @State private var templateName = ""
    @State private var templateSymbol = "square.grid.2x2.fill"
    @State private var templateFields: [FieldSchema] = [
        FieldSchema(key: "custom_1", label: "账号 / 标识", type: .text)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    RadarPageHeader(
                        "字段模版管理",
                        subtitle: "点击卡片或「更多字段」可查看全部字段详情；内置模版为只读，自定义模版支持右键或详情页编辑与删除"
                    )
                    Spacer()
                    RadarButton("新建自定义模版", systemImage: "plus", variant: .primary) {
                        openCreateSheet()
                    }
                }

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 268, maximum: 420), spacing: 12)],
                    spacing: 12
                ) {
                    ForEach(viewModel.templates) { template in
                        templateCard(template)
                    }
                }
            }
            .padding(24)
        }
        .background(palette.windowBackground)
        .task {
            await viewModel.loadTemplates()
        }
        .sheet(isPresented: $showTemplateSheet) {
            templateEditorSheet
                .environment(\.radarPalette, palette)
                .preferredColorScheme(palette.colorScheme)
        }
        .sheet(item: $inspectingTemplate) { template in
            TemplateDetailSheet(
                template: template,
                onEditCustomTemplate: template.isBuiltin
                    ? nil
                    : { target in
                        openEditSheet(for: target)
                    }
            )
            .environment(\.radarPalette, palette)
            .preferredColorScheme(palette.colorScheme)
        }
        .sheet(item: $pendingDeleteTemplate) { template in
            RadarConfirmSheet(
                title: "确定删除模版「\(template.name)」？",
                message: "删除后已创建的订阅条目字段不受影响，但新建订阅将不再提供此模版蓝图。",
                confirmTitle: "确认删除模版",
                cancelTitle: "取消",
                isDestructive: true
            ) {
                Task {
                    await viewModel.deleteTemplate(template)
                    await onTemplatesChanged()
                }
            }
            .environment(\.radarPalette, palette)
            .preferredColorScheme(palette.colorScheme)
        }
    }

    private func openCreateSheet() {
        editingTemplate = nil
        templateName = ""
        templateSymbol = "square.grid.2x2.fill"
        templateFields = [FieldSchema(key: "field_1", label: "账号 / 标识", type: .text)]
        showTemplateSheet = true
    }

    private func openEditSheet(for template: TemplateDefinition) {
        editingTemplate = template
        templateName = template.name
        templateSymbol = template.iconSymbol
        templateFields = template.defaultFields
        showTemplateSheet = true
    }

    private func templateCard(_ template: TemplateDefinition) -> some View {
        let tint = SubRadarTheme.templateColor(for: template.id)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: template.iconSymbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(template.name)
                        .font(SubRadarTheme.font(size: 14, weight: .bold))
                        .foregroundStyle(palette.textPrimary)
                        .lineLimit(1)
                    Text(template.isBuiltin ? "系统内置" : "自定义模版")
                        .font(SubRadarTheme.font(size: 10.5))
                        .foregroundStyle(palette.textMuted)
                }
                Spacer()

                Text("\(template.defaultFields.count) 字段")
                    .font(SubRadarTheme.font(size: 10.5, weight: .medium))
                    .foregroundStyle(palette.textMuted)
            }

            RadarDivider()

            if template.defaultFields.isEmpty {
                Text("无预设扩展字段")
                    .font(SubRadarTheme.font(size: 11.5))
                    .foregroundStyle(palette.textMuted)
            } else {
                FlowFieldBadges(fields: template.defaultFields, maxVisibleCount: 4) {
                    inspectingTemplate = template
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 156)
        .customCard()
        .contentShape(Rectangle())
        .onTapGesture {
            inspectingTemplate = template
        }
        .radarContextMenu {
            RadarContextMenuItem(title: "查看全部字段...", systemImage: "eye") {
                inspectingTemplate = template
            }
            if !template.isBuiltin {
                RadarContextMenuItem(title: "编辑模版...", systemImage: "pencil") {
                    openEditSheet(for: template)
                }
                RadarContextMenuItem(title: "删除模版", systemImage: "trash", isDestructive: true) {
                    pendingDeleteTemplate = template
                }
            }
        }
    }

    private var templateEditorSheet: some View {
        let isEditing = editingTemplate != nil
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(isEditing ? "编辑模版" : "新建自定义模版")
                    .font(SubRadarTheme.sheetTitleFont)
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                RadarButton("取消", variant: .ghost, size: .small) {
                    showTemplateSheet = false
                }
                RadarButton("保存", systemImage: "checkmark", variant: .primary, size: .small) {
                    Task {
                        let validFields = templateFields.filter {
                            !$0.label.trimmingCharacters(in: .whitespaces).isEmpty
                        }
                        if var updated = editingTemplate {
                            updated.name = templateName
                            updated.iconSymbol = templateSymbol
                            updated.defaultFields = validFields
                            try? await viewModel.updateTemplate(updated)
                        } else {
                            _ = try? await viewModel.createCustomTemplate(
                                name: templateName,
                                iconSymbol: templateSymbol,
                                fields: validFields
                            )
                        }
                        await onTemplatesChanged()
                        showTemplateSheet = false
                    }
                }
                .disabled(templateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            RadarDivider()

            RadarTextField("模版名称（如：AI 账号、开发工具）", text: $templateName)

            VStack(alignment: .leading, spacing: 8) {
                RadarSectionTitle("模版图标")
                RadarSymbolPickerGrid(selection: $templateSymbol, accentColor: SubRadarTheme.radarAccent)
            }

            RadarSectionTitle("预设字段")

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(templateFields) { field in
                        let binding = templateFieldBinding(for: field)
                        HStack(spacing: 8) {
                            RadarTextField("字段名", text: binding.label)

                            RadarSelectMenu(
                                options: CustomFieldType.allCases,
                                selection: binding.type,
                                label: { $0.displayName }
                            )

                            RadarIconButton(
                                systemImage: "minus.circle.fill",
                                size: 26,
                                tint: palette.textMuted,
                                helpText: "移除此字段"
                            ) {
                                NSApp.keyWindow?.makeFirstResponder(nil)
                                templateFields.removeAll { $0.id == field.id }
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 190)

            HStack {
                RadarButton("增加字段", systemImage: "plus", variant: .secondary, size: .small) {
                    let idx = templateFields.count + 1
                    templateFields.append(
                        FieldSchema(
                            key: "custom_\(idx)_\(UUID().uuidString.prefix(4))", label: "新字段 \(idx)", type: .text)
                    )
                }
                Spacer()
            }
        }
        .padding(20)
        .frame(width: 480)
        .background(palette.windowBackground)
    }

    private func templateFieldBinding(for fallback: FieldSchema) -> Binding<FieldSchema> {
        let fieldId = fallback.id
        return Binding(
            get: { templateFields.first(where: { $0.id == fieldId }) ?? fallback },
            set: { updated in
                guard let idx = templateFields.firstIndex(where: { $0.id == fieldId }) else { return }
                templateFields[idx] = updated
            }
        )
    }
}
