import AppKit
import SwiftUI

public struct RadarContextMenuItem: Identifiable {
    public let id: String
    public let title: String
    public let systemImage: String
    public let isDestructive: Bool
    public let action: @MainActor () -> Void

    public init(
        id: String? = nil,
        title: String,
        systemImage: String,
        isDestructive: Bool = false,
        action: @escaping @MainActor () -> Void
    ) {
        self.id = id ?? "\(title)-\(systemImage)"
        self.title = title
        self.systemImage = systemImage
        self.isDestructive = isDestructive
        self.action = action
    }
}

struct RadarFloatingMenuContent: View {
    let items: [RadarContextMenuItem]
    let palette: SubRadarPalette
    let onSelect: (RadarContextMenuItem) -> Void

    @State private var hoveredItemId: String?

    var body: some View {
        let regularItems = items.filter { !$0.isDestructive }
        let destructiveItems = items.filter { $0.isDestructive }

        VStack(alignment: .leading, spacing: 2) {
            ForEach(regularItems) { item in
                menuRow(item)
            }

            if !regularItems.isEmpty && !destructiveItems.isEmpty {
                Rectangle()
                    .fill(palette.divider)
                    .frame(height: 1)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 4)
            }

            ForEach(destructiveItems) { item in
                menuRow(item)
            }
        }
        .frame(minWidth: 168)
    }

    private func menuRow(_ item: RadarContextMenuItem) -> some View {
        let isHovered = hoveredItemId == item.id
        return Button {
            onSelect(item)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: item.systemImage)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(item.isDestructive ? SubRadarTheme.coral : palette.textSecondary)
                    .frame(width: 15)

                Text(item.title)
                    .font(SubRadarTheme.uiFont(size: 12.5, weight: .medium))
                    .foregroundStyle(item.isDestructive ? SubRadarTheme.coral : palette.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .circular)
                    .fill(
                        isHovered
                            ? (item.isDestructive
                                ? SubRadarTheme.coral.opacity(0.12)
                                : SubRadarTheme.radarAccent.opacity(palette.isDark ? 0.20 : 0.10))
                            : Color.clear
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredItemId = hovering ? item.id : (hoveredItemId == item.id ? nil : hoveredItemId)
        }
    }
}

private struct RadarContextMenuModifier: ViewModifier {
    @Environment(\.radarPalette) private var palette
    let itemsProvider: () -> [RadarContextMenuItem]

    func body(content: Content) -> some View {
        let items = itemsProvider()
        if items.isEmpty {
            content
        } else {
            content
                .overlay {
                    RightClickCaptureView { screenPoint in
                        RadarFloatingMenuPresenter.show(
                            items: itemsProvider(),
                            palette: palette,
                            screenPoint: screenPoint
                        )
                    }
                }
        }
    }
}

extension View {
    public func radarContextMenu(@RadarMenuBuilder items: @escaping () -> [RadarContextMenuItem]) -> some View {
        modifier(RadarContextMenuModifier(itemsProvider: items))
    }

    public func radarContextMenu(_ items: [RadarContextMenuItem]) -> some View {
        modifier(RadarContextMenuModifier(itemsProvider: { items }))
    }
}

@resultBuilder
public enum RadarMenuBuilder {
    public static func buildBlock(_ components: [RadarContextMenuItem]...) -> [RadarContextMenuItem] {
        components.flatMap { $0 }
    }

    public static func buildExpression(_ expression: RadarContextMenuItem) -> [RadarContextMenuItem] {
        [expression]
    }

    public static func buildOptional(_ component: [RadarContextMenuItem]?) -> [RadarContextMenuItem] {
        component ?? []
    }

    public static func buildEither(first component: [RadarContextMenuItem]) -> [RadarContextMenuItem] {
        component
    }

    public static func buildEither(second component: [RadarContextMenuItem]) -> [RadarContextMenuItem] {
        component
    }
}

// MARK: - 可视化图标选择网格 (不暴露底层英文符号名)
