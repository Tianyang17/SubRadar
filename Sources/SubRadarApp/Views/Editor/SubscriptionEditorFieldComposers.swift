import SubRadarCore
import SwiftUI

struct PresetSelectOrCustomField: View {
    private static let unsetSentinel = "__subradar_unset__"
    private static let customSentinel = "__subradar_custom__"

    @Environment(\.radarPalette) private var palette
    let options: [String]
    let customPlaceholder: String
    var searchable: Bool = false
    @Binding var text: String

    @State private var isCustomMode = false

    private var menuOptions: [String] {
        options + [Self.customSentinel]
    }

    private var menuSelection: Binding<String> {
        Binding(
            get: {
                if isCustomMode {
                    return Self.customSentinel
                }
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return Self.unsetSentinel
                }
                if options.contains(text) {
                    return text
                }
                return Self.customSentinel
            },
            set: { picked in
                if picked == Self.customSentinel {
                    isCustomMode = true
                    if options.contains(text) {
                        text = ""
                    }
                } else {
                    isCustomMode = false
                    text = picked
                }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RadarSelectMenu(
                options: menuOptions,
                selection: menuSelection,
                fullWidth: true,
                searchable: searchable,
                isPlaceholder: { $0 == Self.unsetSentinel },
                label: { opt in
                    switch opt {
                    case Self.unsetSentinel: return "未选择"
                    case Self.customSentinel: return "自定义..."
                    default: return opt
                    }
                }
            )

            if isCustomMode
                || (!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !options.contains(text))
            {
                RadarTextField(customPlaceholder, text: $text)
            }
        }
        .onAppear {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && !options.contains(trimmed) {
                isCustomMode = true
            }
        }
    }
}

struct PlatformMultiSelectField: View {
    @Environment(\.radarPalette) private var palette
    @Binding var value: String

    private var selectedSet: Set<String> {
        Set(FieldOptionCatalog.parsedPlatforms(from: value))
    }

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 84), spacing: 6)],
            alignment: .leading,
            spacing: 6
        ) {
            ForEach(FieldOptionCatalog.softwarePlatforms, id: \.self) { platform in
                let isSelected = selectedSet.contains(platform)
                Button {
                    value = FieldOptionCatalog.togglingPlatform(platform, in: value)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(isSelected ? SubRadarTheme.radarAccent : palette.textMuted)
                        Text(platform)
                            .font(SubRadarTheme.uiFont(size: 11.5, weight: isSelected ? .semibold : .medium))
                            .foregroundStyle(isSelected ? palette.textPrimary : palette.textSecondary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        isSelected ? SubRadarTheme.radarAccent.opacity(0.12) : palette.inputSurface,
                        in: RoundedRectangle(cornerRadius: SubRadarTheme.controlCornerRadius, style: .circular)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: SubRadarTheme.controlCornerRadius, style: .circular)
                            .strokeBorder(
                                isSelected ? SubRadarTheme.radarAccent : palette.borderSubtle,
                                lineWidth: isSelected ? 1.25 : 1
                            )
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
