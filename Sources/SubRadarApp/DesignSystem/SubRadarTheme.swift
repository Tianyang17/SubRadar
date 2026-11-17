import AppKit
import SubRadarCore
import SwiftUI

/// 全局设计系统 Token、双轨排版（SF Pro 正文 + JetBrains Mono 数据/技术指标）与语义色
public enum SubRadarTheme {
    public static let cardCornerRadius: CGFloat = 11
    public static let controlCornerRadius: CGFloat = 8

    private static let availableFontNames: Set<String> = {
        let candidates = [
            "JetBrainsMono-Regular",
            "JetBrainsMono-Medium",
            "JetBrainsMono-SemiBold",
            "JetBrainsMono-Bold"
        ]
        var found = Set<String>()
        for name in candidates where NSFont(name: name, size: 13) != nil {
            found.insert(name)
        }
        return found
    }()

    /// UI 中文标题、标签与说明文字：采用系统 SF Pro / 苹方，保持清晰细腻的阅读质感
    public static func uiFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    /// 金额、日期、倒计时、代码字段、计数与徽标：采用 JetBrains Mono 精确对齐
    public static func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let psName: String
        switch weight {
        case .bold, .heavy, .black:
            psName = "JetBrainsMono-Bold"
        case .semibold:
            psName = "JetBrainsMono-SemiBold"
        case .medium:
            psName = "JetBrainsMono-Medium"
        default:
            psName = "JetBrainsMono-Regular"
        }

        if availableFontNames.contains(psName) {
            return .custom(psName, size: size)
        }
        return .system(size: size, weight: weight, design: .monospaced)
    }

    public static let pageTitleFont = uiFont(size: 21, weight: .bold)
    public static let sheetTitleFont = uiFont(size: 16, weight: .bold)
    public static let sectionTitleFont = uiFont(size: 12, weight: .semibold)
    public static let cardTitleFont = uiFont(size: 13.5, weight: .semibold)

    public static let radarAccent = Color(red: 0.145, green: 0.388, blue: 0.922)
    public static let radarCyan = Color(red: 0.055, green: 0.647, blue: 0.914)
    public static let emerald = Color(red: 0.086, green: 0.639, blue: 0.412)
    public static let amber = Color(red: 0.851, green: 0.467, blue: 0.024)
    public static let coral = Color(red: 0.863, green: 0.149, blue: 0.149)

    public static func preferredColorScheme(for mode: ThemeMode) -> ColorScheme? {
        switch mode {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    public static func categoryColor(for key: CategoryColorKey) -> Color {
        switch key {
        case .purple: return Color(red: 0.486, green: 0.227, blue: 0.929)
        case .cyan: return radarCyan
        case .emerald: return emerald
        case .amber: return amber
        case .indigo: return radarAccent
        case .coral: return coral
        case .pink: return Color(red: 0.859, green: 0.153, blue: 0.467)
        }
    }

    public static func categoryColor(for categoryId: UUID, from categories: [SubscriptionCategory]) -> Color {
        if let cat = CategoryPresetManager.category(for: categoryId, from: categories) {
            return categoryColor(for: cat.colorKey)
        }
        return radarAccent
    }

    public static func templateColor(for templateId: UUID) -> Color {
        switch templateId {
        case TemplateDefinition.BuiltinID.streaming:
            return categoryColor(for: .purple)
        case TemplateDefinition.BuiltinID.vps:
            return categoryColor(for: .cyan)
        case TemplateDefinition.BuiltinID.domain:
            return categoryColor(for: .emerald)
        case TemplateDefinition.BuiltinID.softwareLicense:
            return categoryColor(for: .amber)
        case TemplateDefinition.BuiltinID.aiMembership:
            return categoryColor(for: .pink)
        case TemplateDefinition.BuiltinID.apiBalance:
            return categoryColor(for: .indigo)
        case TemplateDefinition.BuiltinID.custom:
            return radarAccent
        default:
            return radarAccent
        }
    }

    public static func urgencyColor(for item: SubscriptionItem) -> Color {
        if item.billingCycleType == .oneTime { return Color.secondary }
        let days = item.daysUntilRenewal()
        if days <= 0 { return coral }
        if days <= 7 { return amber }
        return emerald
    }

    public static func statusColor(for status: SubscriptionStatus) -> Color {
        switch status {
        case .active: return emerald
        case .paused: return Color.secondary
        case .cancelled, .expired: return coral
        }
    }

    /// 从图标提取主色调用于详情页顶部细微点缀
    public static func dominantColor(from iconData: Data?, fallbackTemplateId: UUID) -> Color {
        guard let data = iconData,
            let image = NSImage(data: data),
            let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            return templateColor(for: fallbackTemplateId)
        }

        let width = 8
        let height = 8
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard
            let ctx = CGContext(
                data: &pixels,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else {
            return templateColor(for: fallbackTemplateId)
        }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var rSum: Double = 0
        var gSum: Double = 0
        var bSum: Double = 0
        var weightSum: Double = 0

        for idx in stride(from: 0, to: pixels.count, by: 4) {
            let r = Double(pixels[idx]) / 255.0
            let g = Double(pixels[idx + 1]) / 255.0
            let b = Double(pixels[idx + 2]) / 255.0
            let a = Double(pixels[idx + 3]) / 255.0
            if a < 0.2 { continue }
            let saturation = max(r, g, b) - min(r, g, b)
            let weight = a * (0.3 + saturation * 2.0)
            rSum += r * weight
            gSum += g * weight
            bSum += b * weight
            weightSum += weight
        }

        guard weightSum > 0 else {
            return templateColor(for: fallbackTemplateId)
        }
        return Color(red: rSum / weightSum, green: gSum / weightSum, blue: bSum / weightSum)
    }
}
