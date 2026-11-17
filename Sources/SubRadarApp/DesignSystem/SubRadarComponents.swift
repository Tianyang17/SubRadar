import AppKit
import SubRadarCore
import SwiftUI

/// 统一在入口处同步系统/用户选择的主题、优雅 UI 正文字体并注入 `@Environment(\.radarPalette)`
struct RadarThemeModifier: ViewModifier {
    @Environment(\.colorScheme) private var systemColorScheme
    let mode: ThemeMode

    func body(content: Content) -> some View {
        let preferred = SubRadarTheme.preferredColorScheme(for: mode)
        let effectiveScheme = preferred ?? systemColorScheme
        content
            .font(SubRadarTheme.uiFont(size: 13))
            .preferredColorScheme(preferred)
            .environment(\.radarPalette, SubRadarPalette(colorScheme: effectiveScheme))
    }
}

extension View {
    public func radarTheme(_ mode: ThemeMode) -> some View {
        modifier(RadarThemeModifier(mode: mode))
    }
}

/// 精密高光卡片容器（1px 边框 + 顶部微高光发丝线 + 双层克制景深）
struct CustomSurfaceCardModifier: ViewModifier {
    @Environment(\.radarPalette) private var palette
    var padding: CGFloat = 16
    var cornerRadius: CGFloat = SubRadarTheme.cardCornerRadius

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(palette.cardSurface)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [palette.topHighlight, Color.clear, Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                        .padding(0.5)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(palette.borderSubtle, lineWidth: 1)
            )
            .shadow(color: palette.isDark ? Color.black.opacity(0.24) : palette.cardShadow, radius: 2, x: 0, y: 1)
            .shadow(color: palette.isDark ? Color.clear : Color.black.opacity(0.025), radius: 10, x: 0, y: 4)
    }
}

extension View {
    public func customCard(padding: CGFloat = 16, cornerRadius: CGFloat = SubRadarTheme.cardCornerRadius) -> some View {
        modifier(CustomSurfaceCardModifier(padding: padding, cornerRadius: cornerRadius))
    }
}

/// 统一的订阅图标头像组件
public struct SubscriptionAvatarView: View {
    @Environment(\.radarPalette) private var palette
    let iconData: Data?
    var categoryId: UUID? = nil
    var categories: [SubscriptionCategory] = []
    let templateId: UUID
    let templates: [TemplateDefinition]
    var size: CGFloat = 40
    var showEmptyHint: Bool = false

    public var body: some View {
        let corner = size * 0.23
        Group {
            if let data = iconData, let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .scaledToFill()
                    .overlay(
                        LinearGradient(
                            colors: [Color.white.opacity(0.18), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .center
                        )
                    )
            } else if showEmptyHint {
                ZStack {
                    palette.inputSurface
                    VStack(spacing: 3) {
                        Image(systemName: "app.badge.fill")
                            .font(.system(size: size * 0.34, weight: .medium))
                            .foregroundStyle(SubRadarTheme.radarAccent.opacity(0.85))
                        if size >= 48 {
                            Text("图标")
                                .font(SubRadarTheme.uiFont(size: 10, weight: .medium))
                                .foregroundStyle(palette.textMuted)
                        }
                    }
                }
            } else {
                let category = categoryId.flatMap { CategoryPresetManager.category(for: $0, from: categories) }
                let symbol =
                    category?.iconSymbol
                    ?? TemplatePresetManager.template(for: templateId, from: templates)?.iconSymbol
                    ?? "square.stack.3d.up.fill"
                let tint =
                    category.map { SubRadarTheme.categoryColor(for: $0.colorKey) }
                    ?? SubRadarTheme.templateColor(for: templateId)
                ZStack {
                    LinearGradient(
                        colors: [
                            tint.opacity(palette.isDark ? 0.22 : 0.14),
                            tint.opacity(palette.isDark ? 0.10 : 0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: symbol)
                        .font(.system(size: size * 0.42, weight: .semibold))
                        .foregroundStyle(tint)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(
                    (iconData == nil && showEmptyHint) ? palette.borderStrong : palette.borderSubtle,
                    style: (iconData == nil && showEmptyHint)
                        ? StrokeStyle(lineWidth: 1, dash: [4, 3])
                        : StrokeStyle(lineWidth: 1)
                )
        )
    }
}

/// 语义化到期倒计时标签
public struct CountdownBadge: View {
    let item: SubscriptionItem

    public var body: some View {
        let color = SubRadarTheme.urgencyColor(for: item)
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 4.5, height: 4.5)
            Text(SubRadarFormatter.renewalCountdownText(for: item))
                .font(SubRadarTheme.font(size: 10.5, weight: .semibold))
                .foregroundStyle(color)
                .lineLimit(1)
        }
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, 7)
        .padding(.vertical, 2.5)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 5.5, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                .strokeBorder(color.opacity(0.22), lineWidth: 0.75)
        )
    }
}

/// 顶部操作反馈条
public struct ToastBannerView: View {
    @Environment(\.radarPalette) private var palette
    let message: String
    var onDismiss: (() -> Void)? = nil

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(SubRadarTheme.emerald)
            Text(message)
                .font(SubRadarTheme.font(size: 12, weight: .medium))
                .foregroundStyle(palette.textPrimary)
            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(palette.textMuted)
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("关闭提示")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(palette.elevatedSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(palette.borderStrong, lineWidth: 1))
        .shadow(color: palette.cardShadow, radius: 10, y: 4)
    }
}

enum ClipboardHelper {
    static func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
