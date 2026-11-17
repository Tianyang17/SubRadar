import AppKit
import SubRadarCore
import SwiftUI

struct RadarCalendarPopoverContent: View {
    @Environment(\.radarPalette) private var palette
    @Binding var selection: Date
    let calendar: Calendar
    @State private var displayedMonth: Date
    @State private var yearText: String
    @State private var monthText: String
    @FocusState private var focusedField: HeaderField?

    private enum HeaderField: Hashable {
        case year
        case month
    }

    init(selection: Binding<Date>, calendar: Calendar, initialMonth: Date) {
        self._selection = selection
        self.calendar = calendar
        self._displayedMonth = State(initialValue: initialMonth)
        let comps = calendar.dateComponents([.year, .month], from: initialMonth)
        self._yearText = State(initialValue: String(format: "%04d", comps.year ?? 2026))
        self._monthText = State(initialValue: String(format: "%02d", comps.month ?? 1))
    }

    var body: some View {
        let cells = monthGridDates()
        let weekdayHeaders = ["日", "一", "二", "三", "四", "五", "六"]

        VStack(spacing: 10) {
            HStack(spacing: 6) {
                HStack(spacing: 3) {
                    TextField("YYYY", text: $yearText)
                        .textFieldStyle(.plain)
                        .focusEffectDisabled()
                        .font(SubRadarTheme.font(size: 12.5, weight: .bold))
                        .foregroundStyle(palette.textPrimary)
                        .multilineTextAlignment(.center)
                        .frame(width: 44)
                        .padding(.vertical, 3)
                        .background(
                            palette.inputSurface,
                            in: RoundedRectangle(cornerRadius: 5, style: .circular)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .circular)
                                .strokeBorder(
                                    focusedField == .year ? SubRadarTheme.radarAccent : palette.borderSubtle,
                                    lineWidth: 1
                                )
                        )
                        .focused($focusedField, equals: .year)
                        .onChange(of: yearText) { _, newValue in
                            let filtered = String(newValue.filter(\.isNumber).prefix(4))
                            if filtered != newValue { yearText = filtered }
                            jumpMonthIfValid()
                        }
                        .onSubmit { commitHeaderInputs() }

                    Text("-")
                        .font(SubRadarTheme.font(size: 12.5, weight: .bold))
                        .foregroundStyle(palette.textMuted)

                    TextField("MM", text: $monthText)
                        .textFieldStyle(.plain)
                        .focusEffectDisabled()
                        .font(SubRadarTheme.font(size: 12.5, weight: .bold))
                        .foregroundStyle(palette.textPrimary)
                        .multilineTextAlignment(.center)
                        .frame(width: 28)
                        .padding(.vertical, 3)
                        .background(
                            palette.inputSurface,
                            in: RoundedRectangle(cornerRadius: 5, style: .circular)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .circular)
                                .strokeBorder(
                                    focusedField == .month ? SubRadarTheme.radarAccent : palette.borderSubtle,
                                    lineWidth: 1
                                )
                        )
                        .focused($focusedField, equals: .month)
                        .onChange(of: monthText) { _, newValue in
                            let filtered = String(newValue.filter(\.isNumber).prefix(2))
                            if filtered != newValue { monthText = filtered }
                            jumpMonthIfValid()
                        }
                        .onSubmit { commitHeaderInputs() }
                }

                Spacer()

                Button {
                    selection = calendar.startOfDay(for: Date())
                    RadarFloatingPanelPresenter.shared.dismiss()
                } label: {
                    Text("今天")
                        .font(SubRadarTheme.uiFont(size: 11, weight: .medium))
                        .foregroundStyle(palette.textSecondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(palette.inputSurface, in: RoundedRectangle(cornerRadius: 5, style: .circular))
                }
                .buttonStyle(.plain)

                RadarIconButton(systemImage: "chevron.left", size: 24, helpText: "上个月") {
                    shiftMonth(by: -1)
                }
                RadarIconButton(systemImage: "chevron.right", size: 24, helpText: "下个月") {
                    shiftMonth(by: 1)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(32), spacing: 4), count: 7), spacing: 4) {
                ForEach(weekdayHeaders, id: \.self) { wd in
                    Text(wd)
                        .font(SubRadarTheme.uiFont(size: 11, weight: .medium))
                        .foregroundStyle(palette.textMuted)
                        .frame(width: 32, height: 22)
                }

                ForEach(cells) { cell in
                    let isSelected = calendar.isDate(cell.date, inSameDayAs: selection)
                    let isToday = calendar.isDateInToday(cell.date)
                    Button {
                        selection = cell.date
                        RadarFloatingPanelPresenter.shared.dismiss()
                    } label: {
                        Text("\(calendar.component(.day, from: cell.date))")
                            .font(SubRadarTheme.font(size: 12, weight: isSelected ? .bold : .regular))
                            .foregroundStyle(
                                isSelected
                                    ? palette.primaryActionForeground
                                    : (cell.isCurrentMonth ? palette.textPrimary : palette.textMuted.opacity(0.55))
                            )
                            .frame(width: 32, height: 28)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .circular)
                                    .fill(isSelected ? palette.primaryActionBackground : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .circular)
                                    .strokeBorder(
                                        isToday && !isSelected ? SubRadarTheme.radarAccent.opacity(0.65) : Color.clear,
                                        lineWidth: 1
                                    )
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(7)
        .onChange(of: focusedField) { oldField, newField in
            if oldField != nil && newField == nil {
                commitHeaderInputs()
            }
        }
        .onChange(of: selection) { _, newSelection in
            let comps = calendar.dateComponents([.year, .month], from: newSelection)
            if let monthStart = calendar.date(from: comps) {
                displayedMonth = monthStart
                syncHeaderText(from: monthStart, force: true)
            }
        }
    }

    private func jumpMonthIfValid() {
        if let target = SubRadarFormatter.resolveYearMonth(
            yearText: yearText,
            monthText: monthText,
            calendar: calendar
        ) {
            displayedMonth = target
        }
    }

    private func commitHeaderInputs() {
        if let target = SubRadarFormatter.resolveYearMonth(
            yearText: yearText,
            monthText: monthText,
            calendar: calendar
        ) {
            displayedMonth = target
            syncHeaderText(from: target, force: true)
        } else {
            syncHeaderText(from: displayedMonth, force: true)
        }
    }

    private func shiftMonth(by delta: Int) {
        focusedField = nil
        if let shifted = calendar.date(byAdding: .month, value: delta, to: displayedMonth) {
            displayedMonth = shifted
            syncHeaderText(from: shifted, force: true)
        }
    }

    private func syncHeaderText(from date: Date, force: Bool) {
        let comps = calendar.dateComponents([.year, .month], from: date)
        if force || focusedField != .year {
            yearText = String(format: "%04d", comps.year ?? 2026)
        }
        if force || focusedField != .month {
            monthText = String(format: "%02d", comps.month ?? 1)
        }
    }

    private struct CalendarCell: Identifiable {
        let date: Date
        let isCurrentMonth: Bool
        var id: Date { date }
    }

    private func monthGridDates() -> [CalendarCell] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth) else {
            return []
        }
        let firstDay = monthInterval.start
        let weekday = calendar.component(.weekday, from: firstDay)
        let leadingDays = (weekday - calendar.firstWeekday + 7) % 7
        guard let gridStart = calendar.date(byAdding: .day, value: -leadingDays, to: firstDay) else {
            return []
        }
        let targetMonth = calendar.component(.month, from: displayedMonth)
        return (0..<42).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: gridStart) else { return nil }
            return CalendarCell(
                date: date,
                isCurrentMonth: calendar.component(.month, from: date) == targetMonth
            )
        }
    }
}
