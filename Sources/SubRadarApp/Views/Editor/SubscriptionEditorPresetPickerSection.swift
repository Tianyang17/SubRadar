import AppKit
import SubRadarCore
import SwiftUI
import UniformTypeIdentifiers

extension SubscriptionEditorFormBody {
    var presetGridSection: some View {
        let trimmedQuery = presetSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let matchedPresets = PopularSoftwarePresetManager.groupedPresets(
            query: presetSearchQuery,
            groupFilter: selectedPresetGroup
        )

        return HStack(alignment: .top, spacing: 12) {
            presetGroupSidebar

            VStack(alignment: .leading, spacing: 10) {
                RadarTextField(
                    "搜索国内外常用软件、AI 账号、云盘与主机（如 ChatGPT / QQ / B站）...",
                    text: $presetSearchQuery,
                    systemImage: "magnifyingglass",
                    showClearButton: true
                )

                if selectedPresetGroup == .infrastructure && !viewModel.isEditing {
                    HStack(spacing: 10) {
                        Text("资产类型")
                            .font(SubRadarTheme.uiFont(size: 11.5, weight: .semibold))
                            .foregroundStyle(palette.textSecondary)

                        RadarSegmentedBar(
                            options: InfraAssetKind.allCases,
                            selection: Binding(
                                get: { selectedInfraKind },
                                set: { newKind in
                                    selectedInfraKind = newKind
                                    withAnimation(.snappy(duration: 0.16)) {
                                        viewModel.applyInfrastructureKindChoice(isHost: newKind == .host)
                                    }
                                }
                            ),
                            label: { $0.rawValue }
                        )
                        .frame(maxWidth: 210)

                        Text("先选主机/VPS 或域名")
                            .font(SubRadarTheme.font(size: 11))
                            .foregroundStyle(palette.textMuted)
                            .lineLimit(1)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(palette.inputSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(palette.borderSubtle, lineWidth: 1)
                    )
                }

                if matchedPresets.isEmpty {
                    Text("预置库未匹配到「\(trimmedQuery)」，请在下方通过 App Store 或本机应用导入")
                        .font(SubRadarTheme.font(size: 11.5))
                        .foregroundStyle(palette.textMuted)
                        .padding(.vertical, 6)
                } else {
                    ScrollView {
                        if selectedPresetGroup == nil && trimmedQuery.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(PopularSoftwareGroup.allCases) { group in
                                    let items = matchedPresets.filter { $0.group == group }
                                    if !items.isEmpty {
                                        VStack(alignment: .leading, spacing: 6) {
                                            HStack(spacing: 5) {
                                                Image(systemName: group.symbolName)
                                                    .font(.system(size: 10, weight: .semibold))
                                                    .foregroundStyle(SubRadarTheme.radarAccent)
                                                Text(group.rawValue)
                                                    .font(SubRadarTheme.uiFont(size: 11, weight: .semibold))
                                                    .foregroundStyle(palette.textSecondary)
                                                Text("\(items.count)")
                                                    .font(SubRadarTheme.font(size: 10, weight: .medium))
                                                    .foregroundStyle(palette.textMuted)
                                            }
                                            presetGrid(for: items)
                                        }
                                    }
                                }
                            }
                        } else {
                            presetGrid(for: matchedPresets)
                        }
                    }
                    .frame(maxHeight: 270)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    var presetGroupSidebar: some View {
        let allCount = PopularSoftwarePresetManager.allPresets.count
        return VStack(alignment: .leading, spacing: 4) {
            presetGroupSidebarItem(
                title: "全部",
                symbol: "square.grid.2x2.fill",
                count: allCount,
                group: nil
            )
            ForEach(PopularSoftwareGroup.allCases) { group in
                let count = PopularSoftwarePresetManager.allPresets.filter { $0.group == group }.count
                presetGroupSidebarItem(
                    title: group.rawValue,
                    symbol: group.symbolName,
                    count: count,
                    group: group
                )
            }
        }
        .frame(width: 148, alignment: .leading)
        .padding(6)
        .background(palette.inputSurface.opacity(0.65), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(palette.borderSubtle, lineWidth: 1)
        )
    }

    func presetGroupSidebarItem(title: String, symbol: String, count: Int, group: PopularSoftwareGroup?) -> some View {
        let isSelected = selectedPresetGroup == group
        return Button {
            withAnimation(.snappy(duration: 0.16)) {
                selectedPresetGroup = group
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(isSelected ? SubRadarTheme.radarAccent : palette.textMuted)
                    .frame(width: 14)

                Text(title)
                    .font(SubRadarTheme.uiFont(size: 11.5, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? palette.textPrimary : palette.textSecondary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                Text("\(count)")
                    .font(SubRadarTheme.font(size: 10, weight: .medium))
                    .foregroundStyle(isSelected ? SubRadarTheme.radarAccent : palette.textMuted)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected ? SubRadarTheme.radarAccent.opacity(0.12) : Color.clear,
                in: RoundedRectangle(cornerRadius: 7, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(
                        isSelected ? SubRadarTheme.radarAccent.opacity(0.35) : Color.clear,
                        lineWidth: 1
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    func presetGrid(for presets: [PopularSoftwarePreset]) -> some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(minimum: 110), spacing: 8), count: 3),
            spacing: 8
        ) {
            ForEach(presets) { preset in
                let isSelected = viewModel.name == preset.name
                Button {
                    let pngData = SoftwarePresetIconRenderer.renderPNG(for: preset)
                    let useInfraOverride = (preset.group == .infrastructure && selectedPresetGroup == .infrastructure)
                    let overrideTemplate =
                        useInfraOverride
                        ? (selectedInfraKind == .host
                            ? TemplateDefinition.BuiltinID.vps : TemplateDefinition.BuiltinID.domain)
                        : nil
                    let overrideCategory =
                        useInfraOverride
                        ? (selectedInfraKind == .host
                            ? SubscriptionCategory.BuiltinID.cloudInfra : SubscriptionCategory.BuiltinID.domainNetwork)
                        : nil
                    if !useInfraOverride && preset.group == .infrastructure {
                        selectedInfraKind =
                            preset.suggestedTemplateId == TemplateDefinition.BuiltinID.domain ? .domain : .host
                    }
                    withAnimation(.snappy(duration: 0.16)) {
                        viewModel.applySoftwarePreset(
                            preset,
                            iconData: pngData,
                            overrideTemplateId: overrideTemplate,
                            overrideCategoryId: overrideCategory
                        )
                    }
                } label: {
                    HStack(spacing: 7) {
                        presetThumbnail(for: preset)

                        Text(preset.name)
                            .font(SubRadarTheme.font(size: 10.5, weight: isSelected ? .semibold : .medium))
                            .foregroundStyle(palette.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        isSelected ? SubRadarTheme.radarAccent.opacity(0.10) : palette.inputSurface,
                        in: RoundedRectangle(cornerRadius: 8, style: .circular)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .circular)
                            .strokeBorder(
                                isSelected ? SubRadarTheme.radarAccent : palette.borderSubtle,
                                lineWidth: isSelected ? 1.5 : 1
                            )
                    )
                    .padding(1)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
