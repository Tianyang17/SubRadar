import AppKit
import SwiftUI

public struct RadarTextField: View {
    @Environment(\.radarPalette) private var palette
    @FocusState private var internalFocus: Bool

    private let placeholder: String
    @Binding private var text: String
    private let systemImage: String?
    private let prefixText: String?
    private let monospaced: Bool
    private let showClearButton: Bool
    private let externalFocus: FocusState<Bool>.Binding?

    public init(
        _ placeholder: String,
        text: Binding<String>,
        systemImage: String? = nil,
        prefixText: String? = nil,
        monospaced: Bool = false,
        showClearButton: Bool = false,
        focusBinding: FocusState<Bool>.Binding? = nil
    ) {
        self.placeholder = placeholder
        self._text = text
        self.systemImage = systemImage
        self.prefixText = prefixText
        self.monospaced = monospaced
        self.showClearButton = showClearButton
        self.externalFocus = focusBinding
    }

    private var effectiveFocusBinding: FocusState<Bool>.Binding {
        externalFocus ?? $internalFocus
    }

    private var isCurrentlyFocused: Bool {
        externalFocus?.wrappedValue ?? internalFocus
    }

    public var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isCurrentlyFocused ? SubRadarTheme.radarAccent : palette.textMuted)
            }

            if let prefixText, !prefixText.isEmpty {
                Text(prefixText)
                    .font(SubRadarTheme.font(size: 12.5, weight: .semibold))
                    .foregroundStyle(isCurrentlyFocused ? SubRadarTheme.radarAccent : palette.textSecondary)
            }

            TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(palette.textMuted))
                .textFieldStyle(.plain)
                .focusEffectDisabled()
                .font(SubRadarTheme.font(size: 12.5))
                .foregroundStyle(palette.textPrimary)
                .focused(effectiveFocusBinding)

            if showClearButton && !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(palette.textMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .modifier(RadarInputSurfaceModifier(isFocused: isCurrentlyFocused))
    }
}

/// 自定义敏感信息密码输入框（支持显隐切换，屏蔽系统密码 AutoFill 弹窗）
public struct RadarSecureField: View {
    @Environment(\.radarPalette) private var palette
    @State private var isFocused: Bool = false
    @State private var isRevealed: Bool = false

    private let placeholder: String
    @Binding private var text: String
    private let monospaced: Bool

    public init(
        _ placeholder: String,
        text: Binding<String>,
        monospaced: Bool = true
    ) {
        self.placeholder = placeholder
        self._text = text
        self.monospaced = monospaced
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isFocused ? SubRadarTheme.radarAccent : palette.textMuted)

            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(monospaced ? SubRadarTheme.font(size: 12.5) : SubRadarTheme.uiFont(size: 12.5))
                        .foregroundStyle(palette.textMuted)
                        .lineLimit(1)
                        .allowsHitTesting(false)
                }

                RadarSecureInputView(
                    placeholder: placeholder,
                    text: $text,
                    isRevealed: isRevealed,
                    monospaced: monospaced,
                    textColor: palette.isDark ? .white : .labelColor,
                    isFocused: $isFocused
                )
                .frame(height: 17)
            }

            Button {
                isRevealed.toggle()
            } label: {
                Image(systemName: isRevealed ? "eye.slash" : "eye")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isRevealed ? SubRadarTheme.radarAccent : palette.textMuted)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(isRevealed ? "隐藏敏感内容" : "显示敏感内容")
        }
        .modifier(RadarInputSurfaceModifier(isFocused: isFocused))
    }
}

/// 自定义多行文本输入域
public struct RadarTextArea: View {
    @Environment(\.radarPalette) private var palette
    @FocusState private var isFocused: Bool

    private let placeholder: String
    @Binding private var text: String
    private let lineRange: ClosedRange<Int>

    public init(
        _ placeholder: String,
        text: Binding<String>,
        lineRange: ClosedRange<Int> = 2...4
    ) {
        self.placeholder = placeholder
        self._text = text
        self.lineRange = lineRange
    }

    public var body: some View {
        TextField(placeholder, text: $text, axis: .vertical)
            .textFieldStyle(.plain)
            .focusEffectDisabled()
            .font(SubRadarTheme.font(size: 12.5))
            .foregroundStyle(palette.textPrimary)
            .lineLimit(lineRange)
            .focused($isFocused)
            .modifier(RadarInputSurfaceModifier(isFocused: isFocused, horizontalPadding: 10, verticalPadding: 9))
    }
}

/// 精密方形分段控制器（零渐变胶囊，高对比卡片滑块）
