import SubRadarCore
import SwiftUI

struct SubscriptionEditorManualHistorySection: View {
    @Environment(\.radarPalette) private var palette
    @Bindable var viewModel: EditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RadarDivider()

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("手动添加历史开销（\(viewModel.manualHistoryEntries.count) 笔待入账）")
                        .font(SubRadarTheme.font(size: 12.5, weight: .semibold))
                        .foregroundStyle(palette.textPrimary)
                    Text("可逐笔记录过去不同时间与价格的历史花费、充值或退款，保存时一并写入账本")
                        .font(SubRadarTheme.font(size: 11))
                        .foregroundStyle(palette.textMuted)
                }

                Spacer()

                if !viewModel.manualHistoryEntries.isEmpty {
                    Text("待入账净额 \(viewModel.manualHistoryNetSummaryText)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(SubRadarTheme.radarAccent)
                }

                RadarButton("添加历史开销", systemImage: "plus", variant: .secondary, size: .small) {
                    withAnimation(.snappy(duration: 0.16)) {
                        viewModel.addManualHistoryEntry()
                    }
                }
            }

            if !viewModel.manualHistoryEntries.isEmpty {
                VStack(spacing: 8) {
                    ForEach(viewModel.manualHistoryEntries) { entry in
                        entryRow(entry: entryBinding(for: entry))
                    }
                }
            }
        }
    }

    private func entryBinding(for fallback: EditorManualHistoryEntry) -> Binding<EditorManualHistoryEntry> {
        let entryId = fallback.id
        return Binding(
            get: { viewModel.manualHistoryEntries.first(where: { $0.id == entryId }) ?? fallback },
            set: { updated in
                guard let idx = viewModel.manualHistoryEntries.firstIndex(where: { $0.id == entryId }) else { return }
                viewModel.manualHistoryEntries[idx] = updated
            }
        )
    }

    private func entryRow(entry: Binding<EditorManualHistoryEntry>) -> some View {
        let entryId = entry.wrappedValue.id
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                RadarDatePicker(
                    selection: Binding(
                        get: { entry.wrappedValue.billedAt },
                        set: { newDate in
                            withAnimation(.snappy(duration: 0.18)) {
                                viewModel.updateManualHistoryDate(id: entryId, to: newDate)
                            }
                        }
                    ),
                    fullWidth: false
                )
                .frame(width: 150)

                RadarSelectMenu(
                    options: BillingRecordKind.allCases,
                    selection: entry.kind,
                    label: { $0.displayName }
                )
                .frame(width: 92)

                RadarSelectMenu(
                    options: CommonCurrency.allCases.map(\.rawValue),
                    selection: entry.currency,
                    label: { "\($0) (\(CommonCurrency.symbol(for: $0)))" }
                )
                .frame(width: 106)

                Spacer()

                RadarIconButton(
                    systemImage: "minus.circle.fill",
                    size: 26,
                    tint: palette.textMuted,
                    helpText: "移除此笔历史开销"
                ) {
                    withAnimation(.snappy(duration: 0.15)) {
                        viewModel.removeManualHistoryEntry(entry.wrappedValue.id)
                    }
                }
            }

            HStack(spacing: 8) {
                RadarTextField(
                    "0.00",
                    text: entry.amountText,
                    prefixText: CommonCurrency.symbol(for: entry.wrappedValue.currency),
                    monospaced: true
                )
                .frame(width: 150)
                .onSubmit {
                    withAnimation(.snappy(duration: 0.18)) {
                        viewModel.sortManualHistoryEntries()
                    }
                }

                RadarTextField(
                    "备注（如：黑五优惠购入 / 首年促销 / 退款差价）",
                    text: entry.note,
                    showClearButton: true
                )
                .onSubmit {
                    withAnimation(.snappy(duration: 0.18)) {
                        viewModel.sortManualHistoryEntries()
                    }
                }
            }
        }
        .padding(10)
        .background(palette.inputSurface.opacity(0.65), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(palette.borderSubtle, lineWidth: 1)
        )
    }
}
