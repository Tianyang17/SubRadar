import AppKit
import SwiftUI

public struct RadarSelectMenuAction: Sendable {
    public let title: String
    public let systemImage: String
    public let action: @MainActor () -> Void

    public init(title: String, systemImage: String = "plus", action: @escaping @MainActor () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }
}

/// 完全去原生化的自定义下拉选择器（Button + 无箭头边框浮动面板）
public struct RadarSelectMenu<Option: Hashable>: View {
    @Environment(\.radarPalette) private var palette
    @State private var isHovered = false
    @State private var isExpanded = false
    @State private var anchorRef = RadarAnchorRef()
    @State private var menuToken = UUID()

    private let titlePrefix: String?
    private let options: [Option]
    @Binding private var selection: Option
    private let fullWidth: Bool
    private let searchable: Bool
    private let isPlaceholder: ((Option) -> Bool)?
    private let iconSymbol: ((Option) -> String?)?
    private let accentColor: ((Option) -> Color?)?
    private let footerAction: RadarSelectMenuAction?
    private let label: (Option) -> String

    public init(
        titlePrefix: String? = nil,
        options: [Option],
        selection: Binding<Option>,
        fullWidth: Bool = false,
        searchable: Bool = false,
        isPlaceholder: ((Option) -> Bool)? = nil,
        iconSymbol: ((Option) -> String?)? = nil,
        accentColor: ((Option) -> Color?)? = nil,
        footerAction: RadarSelectMenuAction? = nil,
        label: @escaping (Option) -> String
    ) {
        self.titlePrefix = titlePrefix
        self.options = options
        self._selection = selection
        self.fullWidth = fullWidth
        self.searchable = searchable
        self.isPlaceholder = isPlaceholder
        self.iconSymbol = iconSymbol
        self.accentColor = accentColor
        self.footerAction = footerAction
        self.label = label
    }

    public var body: some View {
        let showingPlaceholder = isPlaceholder?(selection) ?? false

        Button {
            let rect = anchorRef.screenRect()
            isExpanded = true
            RadarFloatingPanelPresenter.shared.show(
                anchorRect: rect,
                anchorToken: menuToken,
                minWidth: max(180, (rect?.width ?? 180) - 10),
                allowsKeyboardInput: searchable,
                palette: palette,
                onDismiss: { isExpanded = false }
            ) {
                RadarSelectMenuPopoverContent(
                    options: options,
                    selection: $selection,
                    searchable: searchable,
                    iconSymbol: iconSymbol,
                    accentColor: accentColor,
                    footerAction: footerAction,
                    label: label
                )
            }
        } label: {
            HStack(spacing: 7) {
                if let titlePrefix {
                    Text(titlePrefix)
                        .font(SubRadarTheme.uiFont(size: 11.5))
                        .foregroundStyle(palette.textMuted)
                }

                if !showingPlaceholder {
                    if let sym = iconSymbol?(selection) {
                        Image(systemName: sym)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(accentColor?(selection) ?? SubRadarTheme.radarAccent)
                    } else if let dot = accentColor?(selection) {
                        Circle()
                            .fill(dot)
                            .frame(width: 7, height: 7)
                    }
                }

                Text(label(selection))
                    .font(SubRadarTheme.uiFont(size: 12.5, weight: showingPlaceholder ? .regular : .medium))
                    .foregroundStyle(showingPlaceholder ? palette.textMuted : palette.textPrimary)
                    .lineLimit(1)

                if fullWidth {
                    Spacer(minLength: 6)
                }

                Image(systemName: "chevron.down")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(isExpanded ? SubRadarTheme.radarAccent : palette.textMuted)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .animation(.snappy(duration: 0.16), value: isExpanded)
            }
            .frame(maxWidth: fullWidth ? .infinity : nil, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(isExpanded || isHovered ? palette.elevatedSurface : palette.inputSurface)
            .clipShape(RoundedRectangle(cornerRadius: SubRadarTheme.controlCornerRadius, style: .circular))
            .overlay(
                RoundedRectangle(cornerRadius: SubRadarTheme.controlCornerRadius, style: .circular)
                    .strokeBorder(
                        isExpanded
                            ? SubRadarTheme.radarAccent : (isHovered ? palette.borderStrong : palette.borderSubtle),
                        lineWidth: isExpanded ? 1.5 : 1
                    )
            )
            .background(RadarAnchorBackgroundView(anchorRef: anchorRef))
            .contentShape(RoundedRectangle(cornerRadius: SubRadarTheme.controlCornerRadius, style: .circular))
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: !fullWidth, vertical: false)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
