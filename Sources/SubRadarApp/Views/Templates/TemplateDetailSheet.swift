import SubRadarCore
import SwiftUI

struct TemplateDetailSheet: View {
    @Environment(\.radarPalette) private var palette
    @Environment(\.dismiss) private var dismiss

    let template: TemplateDefinition
    let onEditCustomTemplate: ((TemplateDefinition) -> Void)?

    var body: some View {
        let tint = SubRadarTheme.templateColor(for: template.id)
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: template.iconSymbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 40, height: 40)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(template.name)
                            .font(SubRadarTheme.sheetTitleFont)
                            .foregroundStyle(palette.textPrimary)

                        Text(template.isBuiltin ? "系统内置 · 只读" : "自定义模版")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(template.isBuiltin ? SubRadarTheme.amber : SubRadarTheme.radarAccent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                (template.isBuiltin ? SubRadarTheme.amber : SubRadarTheme.radarAccent).opacity(0.12),
                                in: Capsule()
                            )
                    }

                    Text("共 \(template.defaultFields.count) 个预设扩展字段")
                        .font(.system(size: 12))
                        .foregroundStyle(palette.textSecondary)
                }

                Spacer()

                if !template.isBuiltin, let onEditCustomTemplate {
                    RadarButton("编辑模版", systemImage: "pencil", variant: .secondary, size: .small) {
                        dismiss()
                        onEditCustomTemplate(template)
                    }
                }

                RadarButton("关闭", variant: .primary, size: .small) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }

            if template.isBuiltin {
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(SubRadarTheme.amber)
                    Text("系统内置模版字段结构受保护，仅供查看所有字段定义，不支持修改或删除。")
                        .font(.system(size: 11.5))
                        .foregroundStyle(palette.textSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    SubRadarTheme.amber.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(SubRadarTheme.amber.opacity(0.24), lineWidth: 1)
                )
            }

            RadarDivider()

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(template.defaultFields.enumerated()), id: \.element.id) { index, field in
                        fieldRow(index: index + 1, field: field)
                    }
                }
            }
            .frame(maxHeight: 360)
        }
        .padding(20)
        .frame(width: 560)
        .background(palette.windowBackground)
    }

    private func fieldRow(index: Int, field: FieldSchema) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(index)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(palette.textMuted)
                .frame(width: 24, height: 24)
                .background(palette.inputSurface, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(field.label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.textPrimary)

                    Text(field.type.displayName)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(palette.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(palette.inputSurface, in: Capsule())

                    if field.type == .secret {
                        Label("加密存储", systemImage: "lock.fill")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(SubRadarTheme.amber)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(SubRadarTheme.amber.opacity(0.12), in: Capsule())
                    }

                    Spacer()

                    Text(field.key)
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(palette.textMuted)
                }

                if !field.defaultValue.isEmpty {
                    Text("默认值：\(field.defaultValue)")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(SubRadarTheme.radarAccent)
                }

                if !field.placeholder.isEmpty {
                    Text("填写提示：\(field.placeholder)")
                        .font(.system(size: 11))
                        .foregroundStyle(palette.textSecondary)
                }
            }
        }
        .padding(10)
        .background(palette.cardSurface, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(palette.borderSubtle, lineWidth: 1)
        )
    }
}
