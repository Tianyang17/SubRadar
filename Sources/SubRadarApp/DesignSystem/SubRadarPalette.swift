import AppKit
import SubRadarCore
import SwiftUI

/// 主题双色板（Zinc-Obsidian 暗黑主题 & Clean Paper 浅色主题）
public struct SubRadarPalette: Sendable, Equatable {
    public let colorScheme: ColorScheme

    public static let light = SubRadarPalette(colorScheme: .light)
    public static let dark = SubRadarPalette(colorScheme: .dark)

    public init(colorScheme: ColorScheme) {
        self.colorScheme = colorScheme
    }

    public var isDark: Bool { colorScheme == .dark }

    public var windowBackground: Color {
        isDark ? Color(red: 0.055, green: 0.059, blue: 0.075) : Color(red: 0.961, green: 0.963, blue: 0.973)
    }

    public var sidebarBackground: Color {
        isDark ? Color(red: 0.075, green: 0.080, blue: 0.100) : Color(red: 0.935, green: 0.939, blue: 0.953)
    }

    public var cardSurface: Color {
        isDark ? Color(red: 0.098, green: 0.106, blue: 0.133) : Color.white
    }

    public var elevatedSurface: Color {
        isDark ? Color(red: 0.130, green: 0.141, blue: 0.176) : Color(red: 0.986, green: 0.987, blue: 0.994)
    }

    public var inputSurface: Color {
        isDark ? Color(red: 0.072, green: 0.077, blue: 0.098) : Color(red: 0.953, green: 0.957, blue: 0.971)
    }

    public var primaryActionBackground: Color {
        isDark ? Color(red: 0.345, green: 0.408, blue: 0.875) : Color(red: 0.259, green: 0.329, blue: 0.855)
    }

    public var primaryActionForeground: Color {
        Color.white
    }

    public var borderSubtle: Color {
        isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.068)
    }

    public var borderStrong: Color {
        isDark ? Color.white.opacity(0.18) : Color.black.opacity(0.145)
    }

    public var topHighlight: Color {
        isDark ? Color.white.opacity(0.09) : Color.white.opacity(0.92)
    }

    public var divider: Color {
        isDark ? Color.white.opacity(0.07) : Color.black.opacity(0.065)
    }

    public var textPrimary: Color {
        isDark ? Color(white: 0.95) : Color(red: 0.085, green: 0.095, blue: 0.118)
    }

    public var textSecondary: Color {
        isDark ? Color(white: 0.66) : Color(red: 0.34, green: 0.37, blue: 0.43)
    }

    public var textMuted: Color {
        isDark ? Color(white: 0.45) : Color(red: 0.53, green: 0.55, blue: 0.61)
    }

    public var cardShadow: Color {
        isDark ? Color.black.opacity(0.32) : Color.black.opacity(0.045)
    }
}

private struct RadarPaletteEnvironmentKey: EnvironmentKey {
    static let defaultValue: SubRadarPalette = .light
}

extension EnvironmentValues {
    public var radarPalette: SubRadarPalette {
        get { self[RadarPaletteEnvironmentKey.self] }
        set { self[RadarPaletteEnvironmentKey.self] = newValue }
    }
}
