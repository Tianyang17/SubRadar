import AppKit
import SwiftUI

public enum RadarButtonVariant: Sendable {
    case primary
    case secondary
    case ghost
    case danger
}

public enum RadarButtonSize: Sendable {
    case small
    case regular

    var horizontalPadding: CGFloat {
        switch self {
        case .small: 10
        case .regular: 13
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .small: 5
        case .regular: 7
        }
    }

    var font: Font {
        switch self {
        case .small: SubRadarTheme.uiFont(size: 12, weight: .semibold)
        case .regular: SubRadarTheme.uiFont(size: 13, weight: .semibold)
        }
    }
}

/// 统一 1px 主题分割线

public struct RadarButton: View {
    @Environment(\.radarPalette) private var palette
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    private let title: String
    private let systemImage: String?
    private let variant: RadarButtonVariant
    private let size: RadarButtonSize
    private let fullWidth: Bool
    private let action: () -> Void

    public init(
        _ title: String,
        systemImage: String? = nil,
        variant: RadarButtonVariant = .secondary,
        size: RadarButtonSize = .regular,
        fullWidth: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.variant = variant
        self.size = size
        self.fullWidth = fullWidth
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage, !systemImage.isEmpty {
                    Image(systemName: systemImage)
                        .font(.system(size: size == .small ? 11 : 12, weight: .semibold))
                }
                if !title.isEmpty {
                    Text(title)
                        .font(size.font)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.horizontal, title.isEmpty ? size.verticalPadding + 3 : size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .foregroundStyle(foregroundColor)
            .background(backgroundView)
            .overlay {
                RoundedRectangle(cornerRadius: SubRadarTheme.controlCornerRadius, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: SubRadarTheme.controlCornerRadius, style: .continuous))
            .opacity(isEnabled ? 1.0 : 0.42)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary:
            return palette.primaryActionForeground
        case .secondary:
            return palette.textPrimary
        case .ghost:
            return isHovered ? palette.textPrimary : palette.textSecondary
        case .danger:
            return SubRadarTheme.coral
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch variant {
        case .primary:
            palette.primaryActionBackground
                .opacity(isHovered ? 0.88 : 1.0)
        case .secondary:
            isHovered ? palette.elevatedSurface : palette.cardSurface
        case .ghost:
            isHovered ? palette.textPrimary.opacity(palette.isDark ? 0.08 : 0.05) : Color.clear
        case .danger:
            SubRadarTheme.coral.opacity(isHovered ? 0.16 : 0.09)
        }
    }

    private var borderColor: Color {
        switch variant {
        case .primary:
            return Color.clear
        case .secondary:
            return isHovered ? palette.borderStrong : palette.borderSubtle
        case .ghost:
            return isHovered ? palette.borderSubtle : Color.clear
        case .danger:
            return SubRadarTheme.coral.opacity(isHovered ? 0.45 : 0.25)
        }
    }
}

/// 自定义图标纯按钮（如返回、关闭、主题切换、侧边栏新建分类）
public struct RadarIconButton: View {
    @Environment(\.radarPalette) private var palette
    @State private var isHovered = false

    private let systemImage: String
    private let size: CGFloat
    private let tint: Color?
    private let helpText: String?
    private let action: () -> Void

    public init(
        systemImage: String,
        size: CGFloat = 28,
        tint: Color? = nil,
        helpText: String? = nil,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.size = size
        self.tint = tint
        self.helpText = helpText
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: max(10, size * 0.43), weight: .semibold))
                .foregroundStyle(tint ?? (isHovered ? palette.textPrimary : palette.textSecondary))
                .frame(width: size, height: size)
                .background(
                    RoundedRectangle(cornerRadius: SubRadarTheme.controlCornerRadius, style: .continuous)
                        .fill(isHovered ? palette.elevatedSurface : palette.cardSurface.opacity(0.65))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: SubRadarTheme.controlCornerRadius, style: .continuous)
                        .strokeBorder(isHovered ? palette.borderStrong : palette.borderSubtle, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .modifier(OptionalHelpModifier(helpText: helpText))
    }
}

struct OptionalHelpModifier: ViewModifier {
    let helpText: String?

    func body(content: Content) -> some View {
        if let helpText {
            content.help(helpText)
        } else {
            content
        }
    }
}

/// 自定义单行文本输入框
