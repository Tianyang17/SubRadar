import SwiftUI

struct RadarSelectMenuPopoverContent<Option: Hashable>: View {
    @Environment(\.radarPalette) private var palette
    @State private var hoveredIndex: Int?
    @State private var isFooterHovered = false
    @State private var searchQuery = ""

    let options: [Option]
    @Binding var selection: Option
    let searchable: Bool
    let iconSymbol: ((Option) -> String?)?
    let accentColor: ((Option) -> Color?)?
    let footerAction: RadarSelectMenuAction?
    let label: (Option) -> String

    private var filteredOptions: [Option] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard searchable, !query.isEmpty else { return options }
        return options.filter { label($0).localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: 4) {
            if searchable {
                searchInputBar
            }

            ScrollView {
                VStack(spacing: 2) {
                    if filteredOptions.isEmpty {
                        Text("无匹配选项")
                            .font(SubRadarTheme.uiFont(size: 11.5))
                            .foregroundStyle(palette.textMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    ForEach(Array(filteredOptions.enumerated()), id: \.offset) { idx, option in
                        optionRow(option, index: idx)
                    }

                    if let footerAction {
                        footerButton(footerAction)
                    }
                }
            }
            .frame(maxHeight: 280)
        }
    }

    private var searchInputBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(palette.textMuted)
            TextField("搜索选项...", text: $searchQuery)
                .textFieldStyle(.plain)
                .font(SubRadarTheme.uiFont(size: 12))
                .foregroundStyle(palette.textPrimary)
            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(palette.textMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(palette.inputSurface, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(palette.borderSubtle, lineWidth: 1)
        )
    }

    private func optionRow(_ option: Option, index idx: Int) -> some View {
        let isSelected = selection == option
        let isRowHovered = hoveredIndex == idx

        return Button {
            selection = option
            RadarFloatingPanelPresenter.shared.dismiss()
        } label: {
            HStack(spacing: 8) {
                if let sym = iconSymbol?(option) {
                    Image(systemName: sym)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(accentColor?(option) ?? SubRadarTheme.radarAccent)
                        .frame(width: 16)
                } else if let dot = accentColor?(option) {
                    Circle()
                        .fill(dot)
                        .frame(width: 7, height: 7)
                }

                Text(label(option))
                    .font(SubRadarTheme.uiFont(size: 12.5, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? palette.textPrimary : palette.textSecondary)
                    .lineLimit(1)

                Spacer(minLength: 14)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(SubRadarTheme.radarAccent)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .circular)
                    .fill(
                        isSelected
                            ? SubRadarTheme.radarAccent.opacity(palette.isDark ? 0.18 : 0.10)
                            : (isRowHovered
                                ? palette.textPrimary.opacity(palette.isDark ? 0.08 : 0.05)
                                : Color.clear)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredIndex = hovering ? idx : (hoveredIndex == idx ? nil : hoveredIndex)
        }
    }

    private func footerButton(_ action: RadarSelectMenuAction) -> some View {
        VStack(spacing: 0) {
            RadarDivider()
                .padding(.vertical, 3)

            Button {
                RadarFloatingPanelPresenter.shared.dismiss()
                Task { @MainActor in
                    action.action()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: action.systemImage)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(SubRadarTheme.radarAccent)
                        .frame(width: 16)

                    Text(action.title)
                        .font(SubRadarTheme.uiFont(size: 12.5, weight: .semibold))
                        .foregroundStyle(SubRadarTheme.radarAccent)
                        .lineLimit(1)

                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .circular)
                        .fill(isFooterHovered ? SubRadarTheme.radarAccent.opacity(0.10) : Color.clear)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isFooterHovered = hovering
            }
        }
    }
}
