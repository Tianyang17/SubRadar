import AppKit
import SwiftUI

public struct RadarDivider: View {
    @Environment(\.radarPalette) private var palette
    var vertical: Bool = false

    public init(vertical: Bool = false) {
        self.vertical = vertical
    }

    public var body: some View {
        if vertical {
            Rectangle()
                .fill(palette.divider)
                .frame(width: 1)
        } else {
            Rectangle()
                .fill(palette.divider)
                .frame(height: 1)
        }
    }
}

/// 统一页面主标题头
public struct RadarPageHeader: View {
    @Environment(\.radarPalette) private var palette
    private let title: String
    private let subtitle: String

    public init(_ title: String, subtitle: String) {
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(SubRadarTheme.pageTitleFont)
                .foregroundStyle(palette.textPrimary)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(SubRadarTheme.uiFont(size: 12.5))
                    .foregroundStyle(palette.textSecondary)
            }
        }
    }
}

/// 统一卡片分区小标题
public struct RadarSectionTitle: View {
    @Environment(\.radarPalette) private var palette
    private let title: String

    public init(_ title: String) {
        self.title = title
    }

    public var body: some View {
        Text(title)
            .font(SubRadarTheme.sectionTitleFont)
            .foregroundStyle(palette.textSecondary)
    }
}

/// 共享输入容器样式
struct RadarInputSurfaceModifier: ViewModifier {
    @Environment(\.radarPalette) private var palette
    let isFocused: Bool
    var horizontalPadding: CGFloat = 10
    var verticalPadding: CGFloat = 7

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(
                RoundedRectangle(cornerRadius: SubRadarTheme.controlCornerRadius, style: .circular)
                    .fill(palette.inputSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: SubRadarTheme.controlCornerRadius, style: .circular)
                    .strokeBorder(
                        isFocused ? SubRadarTheme.radarAccent : palette.borderSubtle,
                        lineWidth: isFocused ? 2 : 1
                    )
            )
            .padding(2)
    }
}

/// 自定义非原生按钮组件：克制单色主按钮、1px 描边次按钮、幽灵按钮与危险操作按钮
