import AppKit
import SubRadarCore
import SwiftUI

public struct RadarDatePicker: View {
    @Environment(\.radarPalette) private var palette
    @State private var isHovered = false
    @State private var isExpanded = false
    @State private var anchorRef = RadarAnchorRef()
    @State private var pickerToken = UUID()
    @State private var dateInputText: String
    @FocusState private var isTextFocused: Bool

    private let titlePrefix: String?
    @Binding private var selection: Date
    private let fullWidth: Bool
    private let calendar: Calendar

    public init(
        _ titlePrefix: String? = nil,
        selection: Binding<Date>,
        fullWidth: Bool = false,
        calendar: Calendar = .current
    ) {
        self.titlePrefix = titlePrefix
        self._selection = selection
        self.fullWidth = fullWidth
        self.calendar = calendar
        self._dateInputText = State(initialValue: SubRadarFormatter.formatDate(selection.wrappedValue))
    }

    public var body: some View {
        HStack(spacing: 6) {
            Button {
                toggleCalendarPopover()
            } label: {
                Image(systemName: "calendar")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(isExpanded || isTextFocused ? SubRadarTheme.radarAccent : palette.textMuted)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("打开日历面板")

            if let titlePrefix {
                Text(titlePrefix)
                    .font(SubRadarTheme.uiFont(size: 11.5))
                    .foregroundStyle(palette.textMuted)
            }

            TextField("YYYY-MM-DD", text: $dateInputText)
                .textFieldStyle(.plain)
                .focusEffectDisabled()
                .font(SubRadarTheme.font(size: 12.5, weight: .medium))
                .foregroundStyle(palette.textPrimary)
                .focused($isTextFocused)
                .frame(minWidth: 82, maxWidth: fullWidth ? .infinity : 92, alignment: .leading)
                .onSubmit {
                    commitTextInput()
                }

            if fullWidth {
                Spacer(minLength: 4)
            }

            Button {
                toggleCalendarPopover()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(isExpanded ? SubRadarTheme.radarAccent : palette.textMuted)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .animation(.snappy(duration: 0.16), value: isExpanded)
                    .frame(width: 14, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("展开日历选择")
        }
        .frame(maxWidth: fullWidth ? .infinity : nil, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(isExpanded || isTextFocused || isHovered ? palette.elevatedSurface : palette.inputSurface)
        .clipShape(RoundedRectangle(cornerRadius: SubRadarTheme.controlCornerRadius, style: .circular))
        .overlay(
            RoundedRectangle(cornerRadius: SubRadarTheme.controlCornerRadius, style: .circular)
                .strokeBorder(
                    isExpanded || isTextFocused
                        ? SubRadarTheme.radarAccent : (isHovered ? palette.borderStrong : palette.borderSubtle),
                    lineWidth: isExpanded || isTextFocused ? 1.5 : 1
                )
        )
        .background(RadarAnchorBackgroundView(anchorRef: anchorRef))
        .onHover { hovering in
            isHovered = hovering
        }
        .onAppear {
            dateInputText = SubRadarFormatter.formatDate(selection)
        }
        .onChange(of: selection) { _, newValue in
            let formatted = SubRadarFormatter.formatDate(newValue)
            if dateInputText != formatted {
                dateInputText = formatted
            }
        }
        .onChange(of: isTextFocused) { wasFocused, nowFocused in
            if wasFocused && !nowFocused {
                commitTextInput()
            }
        }
    }

    private func toggleCalendarPopover() {
        commitTextInput()
        let comps = calendar.dateComponents([.year, .month], from: selection)
        let initialMonth = calendar.date(from: comps) ?? selection
        let rect = anchorRef.screenRect()
        isExpanded = true
        RadarFloatingPanelPresenter.shared.show(
            anchorRect: rect,
            anchorToken: pickerToken,
            minWidth: 266,
            allowsKeyboardInput: true,
            palette: palette,
            onDismiss: { isExpanded = false },
            content: {
                RadarCalendarPopoverContent(
                    selection: $selection,
                    calendar: calendar,
                    initialMonth: initialMonth
                )
            }
        )
    }

    private func commitTextInput() {
        if let parsed = SubRadarFormatter.parseDateInput(dateInputText, calendar: calendar) {
            if !calendar.isDate(parsed, inSameDayAs: selection) {
                selection = parsed
            }
            dateInputText = SubRadarFormatter.formatDate(parsed)
        } else {
            dateInputText = SubRadarFormatter.formatDate(selection)
        }
    }
}

/// 自定义开关
public struct RadarToggleRow: View {
    @Environment(\.radarPalette) private var palette
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool

    public init(_ title: String, subtitle: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
    }

    public var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(SubRadarTheme.uiFont(size: 13, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(SubRadarTheme.uiFont(size: 11.5))
                        .foregroundStyle(palette.textSecondary)
                }
            }
            Spacer()

            Button {
                withAnimation(.snappy(duration: 0.16)) {
                    isOn.toggle()
                }
            } label: {
                ZStack(alignment: isOn ? .trailing : .leading) {
                    Capsule(style: .continuous)
                        .fill(isOn ? SubRadarTheme.radarAccent : palette.borderStrong.opacity(0.6))
                        .frame(width: 38, height: 22)

                    Circle()
                        .fill(.white)
                        .frame(width: 16, height: 16)
                        .shadow(color: .black.opacity(0.18), radius: 1.5, y: 1)
                        .padding(3)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }
}
