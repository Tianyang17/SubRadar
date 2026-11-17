import AppKit
import SwiftUI

public struct RadarSymbolOption: Identifiable, Hashable, Sendable {
    public let symbol: String
    public let label: String
    public var id: String { symbol }

    public init(symbol: String, label: String) {
        self.symbol = symbol
        self.label = label
    }

    public static let presets: [RadarSymbolOption] = [
        RadarSymbolOption(symbol: "play.tv.fill", label: "影音会员"),
        RadarSymbolOption(symbol: "sparkles", label: "AI 账号"),
        RadarSymbolOption(symbol: "server.rack", label: "服务器"),
        RadarSymbolOption(symbol: "globe", label: "域名网站"),
        RadarSymbolOption(symbol: "key.fill", label: "软件授权"),
        RadarSymbolOption(symbol: "icloud.fill", label: "云盘存储"),
        RadarSymbolOption(symbol: "cpu", label: "算力计算"),
        RadarSymbolOption(symbol: "terminal.fill", label: "开发工具"),
        RadarSymbolOption(symbol: "music.note", label: "音乐娱乐"),
        RadarSymbolOption(symbol: "gamecontroller.fill", label: "游戏订阅"),
        RadarSymbolOption(symbol: "network", label: "网络带宽"),
        RadarSymbolOption(symbol: "shield.checkered", label: "安全防护"),
        RadarSymbolOption(symbol: "creditcard.fill", label: "金融服务"),
        RadarSymbolOption(symbol: "folder.fill", label: "日常分类"),
        RadarSymbolOption(symbol: "tag.fill", label: "通用标签"),
        RadarSymbolOption(symbol: "bolt.fill", label: "高效工具")
    ]
}

public struct RadarSymbolPickerGrid: View {
    @Environment(\.radarPalette) private var palette
    @Binding private var selection: String
    private let accentColor: Color
    private let options: [RadarSymbolOption]

    public init(
        selection: Binding<String>,
        accentColor: Color = SubRadarTheme.radarAccent,
        options: [RadarSymbolOption] = RadarSymbolOption.presets
    ) {
        self._selection = selection
        self.accentColor = accentColor
        self.options = options
    }

    public var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 8)
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(options) { option in
                let isSelected = selection == option.symbol
                Button {
                    selection = option.symbol
                } label: {
                    Image(systemName: option.symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isSelected ? accentColor : palette.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .circular)
                                .fill(
                                    isSelected
                                        ? accentColor.opacity(palette.isDark ? 0.20 : 0.12) : palette.inputSurface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .circular)
                                .strokeBorder(
                                    isSelected ? accentColor : palette.borderSubtle, lineWidth: isSelected ? 2 : 1)
                        )
                        .padding(1)
                }
                .buttonStyle(.plain)
                .help(option.label)
            }
        }
    }
}

// MARK: - 统一自定义二次确认弹窗 (Double Check)

public struct RadarConfirmSheet: View {
    @Environment(\.radarPalette) private var palette
    @Environment(\.dismiss) private var dismiss

    private let title: String
    private let message: String
    private let details: [String]
    private let confirmTitle: String
    private let cancelTitle: String
    private let isDestructive: Bool
    private let onConfirm: @MainActor () -> Void

    public init(
        title: String,
        message: String,
        details: [String] = [],
        confirmTitle: String = "确认",
        cancelTitle: String = "取消",
        isDestructive: Bool = false,
        onConfirm: @escaping @MainActor () -> Void
    ) {
        self.title = title
        self.message = message
        self.details = details
        self.confirmTitle = confirmTitle
        self.cancelTitle = cancelTitle
        self.isDestructive = isDestructive
        self.onConfirm = onConfirm
    }

    public var body: some View {
        let badgeTint = isDestructive ? SubRadarTheme.coral : SubRadarTheme.radarAccent
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: isDestructive ? "exclamationmark.triangle.fill" : "checkmark.shield.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(badgeTint)
                    .frame(width: 36, height: 36)
                    .background(badgeTint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .circular))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(SubRadarTheme.uiFont(size: 15, weight: .bold))
                        .foregroundStyle(palette.textPrimary)
                    Text(message)
                        .font(SubRadarTheme.uiFont(size: 12.5))
                        .foregroundStyle(palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !details.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(details, id: \.self) { line in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•")
                                .font(SubRadarTheme.font(size: 11.5, weight: .bold))
                                .foregroundStyle(badgeTint)
                            Text(line)
                                .font(SubRadarTheme.uiFont(size: 12))
                                .foregroundStyle(palette.textPrimary)
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(palette.inputSurface, in: RoundedRectangle(cornerRadius: 7, style: .circular))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .circular)
                        .strokeBorder(palette.borderSubtle, lineWidth: 1)
                )
            }

            RadarDivider()

            HStack {
                Spacer()
                RadarButton(cancelTitle, variant: .ghost) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                RadarButton(
                    confirmTitle,
                    systemImage: isDestructive ? "trash" : "checkmark",
                    variant: isDestructive ? .danger : .primary
                ) {
                    dismiss()
                    onConfirm()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 400)
        .background(palette.windowBackground)
    }
}
