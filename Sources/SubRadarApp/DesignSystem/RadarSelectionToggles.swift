import AppKit
import SwiftUI

public struct RadarSegmentedBar<Option: Hashable & Identifiable>: View {
    @Environment(\.radarPalette) private var palette
    @Namespace private var pillNamespace

    private let options: [Option]
    @Binding private var selection: Option
    private let label: (Option) -> String

    public init(
        options: [Option],
        selection: Binding<Option>,
        label: @escaping (Option) -> String
    ) {
        self.options = options
        self._selection = selection
        self.label = label
    }

    public var body: some View {
        HStack(spacing: 3) {
            ForEach(options) { option in
                let isSelected = selection == option
                Button {
                    withAnimation(.snappy(duration: 0.18)) {
                        selection = option
                    }
                } label: {
                    Text(label(option))
                        .font(SubRadarTheme.uiFont(size: 12, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? palette.textPrimary : palette.textSecondary)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 5)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(palette.cardSurface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                                            .strokeBorder(palette.borderSubtle, lineWidth: 1)
                                    )
                                    .matchedGeometryEffect(id: "radarSegmentPill", in: pillNamespace)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(palette.inputSurface)
        .clipShape(RoundedRectangle(cornerRadius: SubRadarTheme.controlCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: SubRadarTheme.controlCornerRadius, style: .continuous)
                .strokeBorder(palette.borderSubtle, lineWidth: 1)
        )
    }
}

public struct RadarToggle: View {
    @Environment(\.radarPalette) private var palette
    private let title: String
    @Binding private var isOn: Bool

    public init(_ title: String, isOn: Binding<Bool>) {
        self.title = title
        self._isOn = isOn
    }

    public var body: some View {
        Button {
            withAnimation(.snappy(duration: 0.18)) {
                isOn.toggle()
            }
        } label: {
            HStack(spacing: 9) {
                if !title.isEmpty {
                    Text(title)
                        .font(SubRadarTheme.font(size: 12.5))
                        .foregroundStyle(palette.textPrimary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }

                ZStack(alignment: isOn ? .trailing : .leading) {
                    Capsule(style: .continuous)
                        .fill(isOn ? SubRadarTheme.radarAccent : palette.inputSurface)
                        .frame(width: 36, height: 20)
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(isOn ? Color.clear : palette.borderStrong, lineWidth: 1)
                        )

                    Circle()
                        .fill(Color.white)
                        .frame(width: 14, height: 14)
                        .padding(3)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// 侧边栏自定义导航行：瞬时稳重悬停热区，无闪动
public struct RadarSidebarNavRow: View {
    @Environment(\.radarPalette) private var palette
    @State private var isHovered = false

    private let title: String
    private let systemImage: String
    private let tint: Color
    private let count: Int?
    private let isSelected: Bool
    private let action: () -> Void

    public init(
        title: String,
        systemImage: String,
        tint: Color,
        count: Int? = nil,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.count = count
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(isSelected ? SubRadarTheme.radarAccent : Color.clear)
                    .frame(width: 2.5, height: 16)

                Image(systemName: systemImage)
                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? SubRadarTheme.radarAccent : tint)
                    .frame(width: 17)

                Text(title)
                    .font(SubRadarTheme.uiFont(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? palette.textPrimary : palette.textSecondary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                if let count, count > 0 {
                    Text("\(count)")
                        .font(SubRadarTheme.font(size: 11, weight: .semibold))
                        .foregroundStyle(isSelected ? SubRadarTheme.radarAccent : palette.textMuted)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(isSelected ? SubRadarTheme.radarAccent.opacity(0.14) : palette.inputSurface)
                        )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: SubRadarTheme.controlCornerRadius, style: .continuous)
                    .fill(
                        isSelected
                            ? SubRadarTheme.radarAccent.opacity(palette.isDark ? 0.16 : 0.10)
                            : (isHovered ? palette.textPrimary.opacity(palette.isDark ? 0.055 : 0.045) : Color.clear)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: SubRadarTheme.controlCornerRadius, style: .continuous)
                    .strokeBorder(
                        isSelected ? SubRadarTheme.radarAccent.opacity(0.28) : Color.clear,
                        lineWidth: 1
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - 完全去原生化的自定义右键菜单 (RadarContextMenu)
