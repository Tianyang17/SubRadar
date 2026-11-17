import SubRadarCore
import SwiftUI

struct CategoryEditorSheet: View {
    @Environment(\.radarPalette) private var palette
    @Environment(\.dismiss) private var dismiss

    enum Mode: Identifiable {
        case create
        case edit(SubscriptionCategory)

        var id: String {
            switch self {
            case .create: return "create-category"
            case .edit(let category): return "edit-\(category.id.uuidString)"
            }
        }
    }

    let mode: Mode
    @Bindable var viewModel: MainViewModel

    @State private var name: String
    @State private var iconSymbol: String
    @State private var colorKey: CategoryColorKey

    init(mode: Mode, viewModel: MainViewModel) {
        self.mode = mode
        self.viewModel = viewModel
        switch mode {
        case .create:
            _name = State(initialValue: "")
            _iconSymbol = State(initialValue: "tag.fill")
            _colorKey = State(initialValue: .indigo)
        case .edit(let category):
            _name = State(initialValue: category.name)
            _iconSymbol = State(initialValue: category.iconSymbol)
            _colorKey = State(initialValue: category.colorKey)
        }
    }

    var body: some View {
        let selectedTint = SubRadarTheme.categoryColor(for: colorKey)
        let isEditing: Bool = {
            if case .edit = mode { return true }
            return false
        }()

        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(isEditing ? "编辑分类" : "新建分类")
                    .font(SubRadarTheme.sheetTitleFont)
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                RadarButton("取消", variant: .ghost, size: .small) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                RadarButton("保存", systemImage: "checkmark", variant: .primary, size: .small) {
                    Task {
                        switch mode {
                        case .create:
                            _ = try? await viewModel.createCategory(
                                name: name,
                                iconSymbol: iconSymbol,
                                colorKey: colorKey
                            )
                        case .edit(var existing):
                            existing.name = name
                            existing.iconSymbol = iconSymbol
                            existing.colorKey = colorKey
                            try? await viewModel.updateCategory(existing)
                        }
                        dismiss()
                    }
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.defaultAction)
            }

            RadarDivider()

            HStack(spacing: 12) {
                Image(systemName: iconSymbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(selectedTint)
                    .frame(width: 40, height: 40)
                    .background(selectedTint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(selectedTint.opacity(0.24), lineWidth: 1)
                    )

                RadarTextField("分类名称（如：AI 工具、日常开支）", text: $name)
            }

            VStack(alignment: .leading, spacing: 10) {
                RadarSectionTitle("选择图标")
                RadarSymbolPickerGrid(selection: $iconSymbol, accentColor: selectedTint)
            }

            VStack(alignment: .leading, spacing: 10) {
                RadarSectionTitle("标识色")
                HStack(spacing: 10) {
                    ForEach(CategoryColorKey.allCases) { key in
                        let color = SubRadarTheme.categoryColor(for: key)
                        let isSelected = colorKey == key
                        Button {
                            colorKey = key
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
                        .help(key.displayName)
                    }
                    Spacer()
                }
            }

            if case .edit(let existing) = mode, !existing.isBuiltin {
                RadarDivider()
                HStack {
                    RadarButton("删除分类", systemImage: "trash", variant: .danger, size: .small) {
                        Task {
                            await viewModel.deleteCategory(existing)
                            dismiss()
                        }
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
