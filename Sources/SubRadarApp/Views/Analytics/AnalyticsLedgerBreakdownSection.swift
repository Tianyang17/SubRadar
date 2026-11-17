import AppKit
import Charts
import SubRadarCore
import SwiftUI

extension AnalyticsDashboardView {
    func recordsBreakdownCard(summary: ExpenseAnalyticsSummary) -> some View {
        let records = viewModel.filteredRecords.filter { record in
            if let selectedMonth {
                return monthKey(for: record.billedAt) == selectedMonth
            }
            return true
        }

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        isLedgerExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isLedgerExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(palette.textMuted)
                            .frame(width: 14)

                        Text("区间流水明细")
                            .font(SubRadarTheme.cardTitleFont)
                            .foregroundStyle(palette.textPrimary)

                        Spacer()

                        Text("共 \(records.count) 条 · \(isLedgerExpanded ? "收起" : "点击展开")")
                            .font(SubRadarTheme.font(size: 11.5, weight: .medium))
                            .foregroundStyle(palette.textMuted)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if let selectedMonth {
                    Button {
                        self.selectedMonth = nil
                    } label: {
                        HStack(spacing: 4) {
                            Text("月份：\(selectedMonth)")
                            Image(systemName: "xmark")
                                .font(.system(size: 8.5, weight: .bold))
                        }
                        .font(SubRadarTheme.font(size: 10, weight: .semibold))
                        .foregroundStyle(SubRadarTheme.radarAccent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(SubRadarTheme.radarAccent.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            if isLedgerExpanded {
                if records.isEmpty {
                    Text("当前筛选条件下暂无扣费流水。")
                        .font(SubRadarTheme.font(size: 12.5))
                        .foregroundStyle(palette.textSecondary)
                        .padding(.vertical, 8)
                } else {
                    RadarDivider()
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                                HStack(spacing: 12) {
                                    Text(SubRadarFormatter.formatDate(record.billedAt))
                                        .font(SubRadarTheme.font(size: 12))
                                        .foregroundStyle(palette.textMuted)
                                        .frame(width: 92, alignment: .leading)

                                    Text(viewModel.subscriptionNamesById[record.subscriptionId] ?? "已删除订阅")
                                        .font(SubRadarTheme.font(size: 12.5, weight: .medium))
                                        .foregroundStyle(palette.textPrimary)

                                    Text(record.kind == .charge ? record.source.displayName : record.kind.displayName)
                                        .font(SubRadarTheme.font(size: 10, weight: .semibold))
                                        .foregroundStyle(
                                            record.kind == .refund ? SubRadarTheme.emerald : palette.textSecondary
                                        )
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3)
                                        .background(
                                            (record.kind == .refund
                                                ? SubRadarTheme.emerald.opacity(0.12) : palette.inputSurface),
                                            in: Capsule()
                                        )

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: 1) {
                                        let prefix = record.kind == .refund ? "-" : ""
                                        Text(
                                            "\(prefix)\(SubRadarFormatter.formatMoney(record.baseCurrencyAmount, currency: summary.baseCurrency))"
                                        )
                                        .font(SubRadarTheme.font(size: 12.5, weight: .semibold))
                                        .foregroundStyle(
                                            record.kind == .refund ? SubRadarTheme.emerald : palette.textPrimary)
                                        if record.currency != summary.baseCurrency {
                                            Text(
                                                "原币: \(SubRadarFormatter.formatCompactMoney(record.amount, currency: record.currency))"
                                            )
                                            .font(SubRadarTheme.font(size: 10))
                                            .foregroundStyle(palette.textMuted)
                                        }
                                    }
                                }
                                .padding(.vertical, 9)

                                if index < records.count - 1 {
                                    RadarDivider()
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 260)
                }
            }
        }
        .customCard(padding: 18)
    }
}
