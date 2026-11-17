import SubRadarCore
import SwiftUI

extension SubscriptionDetailView {
    func billingSummaryCard(totalSpent: Decimal, spendSummary: SubscriptionSpendSummary? = nil) -> some View {
        let columns = [
            GridItem(.flexible(minimum: 150), spacing: 12),
            GridItem(.flexible(minimum: 150), spacing: 12)
        ]
        let foreignBreakdownSuffix: String? =
            if let spendSummary, spendSummary.hasForeignCurrencyRecords,
                !spendSummary.originalCurrencySummaryText.isEmpty
            {
                "原币：\(spendSummary.originalCurrencySummaryText) · 共 \(viewModel.selectedRecords.count) 笔"
            } else {
                nil
            }

        return VStack(alignment: .leading, spacing: 14) {
            RadarSectionTitle("计费与周期")

            LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                if item.templateId == TemplateDefinition.BuiltinID.apiBalance {
                    let currentBalStr = item.fieldValue(forKey: "current_balance") ?? "0"
                    let currentBal = Decimal(string: currentBalStr.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
                    let thresholdStr =
                        item.fieldValue(forKey: "low_balance_threshold")?.trimmingCharacters(
                            in: .whitespacesAndNewlines) ?? ""
                    let thresholdVal = Decimal(string: thresholdStr)
                    let isLow = thresholdVal.map { currentBal < $0 } ?? false
                    metricCell(
                        title: "历史充值（实付净额）",
                        value: SubRadarFormatter.formatMoney(totalSpent, currency: item.currency),
                        subtitle: foreignBreakdownSuffix ?? "充值 − 退款（共 \(viewModel.selectedRecords.count) 笔，不含赠送）"
                    )
                    metricCell(
                        title: "当前账户余额",
                        value: SubRadarFormatter.formatMoney(currentBal, currency: item.currency),
                        subtitle: item.fieldValue(forKey: "provider_preset").map {
                            "API 平台：\(APIBalanceProviderPreset(raw: $0).displayName)"
                        } ?? "接口查询"
                    )
                    metricCell(
                        title: "低余额告警阈值",
                        value: thresholdVal.map { SubRadarFormatter.formatMoney($0, currency: item.currency) } ?? "未设置",
                        subtitle: isLow ? "当前余额已低于阈值" : "低于阈值时自动提醒"
                    )
                    metricCell(
                        title: "启用日期",
                        value: SubRadarFormatter.formatDate(item.startDate),
                        subtitle: "按量计费监控中"
                    )
                } else if item.billingCycleType == .oneTime {
                    metricCell(
                        title: "买断价格",
                        value: SubRadarFormatter.formatMoney(item.price, currency: item.currency),
                        subtitle: item.cycleDisplayName
                    )
                    metricCell(
                        title: "历史累计净支出",
                        value: SubRadarFormatter.formatMoney(totalSpent, currency: item.currency),
                        subtitle: foreignBreakdownSuffix ?? "共 \(viewModel.selectedRecords.count) 笔账单"
                    )
                    metricCell(
                        title: "首次购买时间",
                        value: SubRadarFormatter.formatDate(item.startDate),
                        subtitle: "一次性买断"
                    )
                    metricCell(
                        title: "授权性质",
                        value: "永久授权",
                        subtitle: "无需续费"
                    )
                } else {
                    metricCell(
                        title: "购买价格",
                        value: SubRadarFormatter.formatMoney(item.price, currency: item.currency),
                        subtitle: "首期购入价"
                    )
                    metricCell(
                        title: "续期价格",
                        value: SubRadarFormatter.formatMoney(item.effectiveRenewalPrice, currency: item.currency),
                        subtitle: item.cycleDisplayName
                    )
                    metricCell(
                        title: "历史累计净支出",
                        value: SubRadarFormatter.formatMoney(totalSpent, currency: item.currency),
                        subtitle: foreignBreakdownSuffix ?? "含手动账单与退款，共 \(viewModel.selectedRecords.count) 笔"
                    )
                    metricCell(
                        title: "首次开始时间",
                        value: SubRadarFormatter.formatDate(item.startDate),
                        subtitle: "起始入账日期"
                    )
                    metricCell(
                        title: "下次续订日期",
                        value: SubRadarFormatter.formatDate(item.nextRenewalDate),
                        subtitle: "周期 \(item.cycleDisplayName)"
                    )
                    metricCell(
                        title: "续费与提醒策略",
                        value: item.renewalModeDisplayText,
                        subtitle: item.reminderDaysBefore >= 0 ? "提前 \(item.reminderDaysBefore) 天提醒" : "未开启提醒"
                    )
                }
            }
        }
        .customCard()
    }

    func metricCell(title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(palette.textMuted)
            Text(value)
                .font(SubRadarTheme.font(size: 17, weight: .bold))
                .foregroundStyle(palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(palette.textSecondary)
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.inputSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    var billingRecordsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        isRecordsExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isRecordsExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(palette.textMuted)
                            .frame(width: 14)

                        RadarSectionTitle("计费与历史流水")

                        Text("\(viewModel.selectedRecords.count) 条")
                            .font(SubRadarTheme.font(size: 11.5))
                            .foregroundStyle(palette.textMuted)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()

                RadarButton("记一笔", systemImage: "plus", variant: .secondary, size: .small) {
                    editingRecord = nil
                    ledgerKind = item.templateId == TemplateDefinition.BuiltinID.apiBalance ? .topUp : .charge
                    ledgerAmountText = ""
                    ledgerCurrency = item.currency
                    ledgerDate = Date()
                    ledgerNote = ""
                    showLedgerSheet = true
                }
            }

            if isRecordsExpanded {
                if viewModel.selectedRecords.isEmpty {
                    Text("暂无扣费或充值记录，点击右上角「记一笔」可随时补录历史花费、充值或退款。")
                        .font(SubRadarTheme.font(size: 12.5))
                        .foregroundStyle(palette.textSecondary)
                        .padding(.vertical, 6)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(viewModel.selectedRecords.enumerated()), id: \.element.id) { index, record in
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(kindColor(record.kind))
                                        .frame(width: 7, height: 7)
                                    Text(SubRadarFormatter.formatDate(record.billedAt))
                                        .font(SubRadarTheme.font(size: 12))
                                        .foregroundStyle(palette.textSecondary)
                                    Text(record.kind.displayName)
                                        .font(SubRadarTheme.font(size: 10, weight: .semibold))
                                        .foregroundStyle(kindColor(record.kind))
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3)
                                        .background(kindColor(record.kind).opacity(0.11), in: Capsule())
                                    if !record.note.isEmpty {
                                        Text(record.note)
                                            .font(SubRadarTheme.font(size: 11))
                                            .foregroundStyle(palette.textMuted)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    let prefix = record.kind == .refund ? "-" : ""
                                    Text(
                                        "\(prefix)\(SubRadarFormatter.formatMoney(record.amount, currency: record.currency))"
                                    )
                                    .font(SubRadarTheme.font(size: 13, weight: .semibold))
                                    .foregroundStyle(
                                        record.kind == .refund ? SubRadarTheme.emerald : palette.textPrimary)

                                    RadarIconButton(systemImage: "pencil", size: 22, helpText: "编辑该笔流水") {
                                        editingRecord = record
                                        ledgerKind = record.kind
                                        ledgerAmountText = NSDecimalNumber(decimal: record.amount).stringValue
                                        ledgerCurrency = record.currency
                                        ledgerDate = record.billedAt
                                        ledgerNote = record.note
                                        showLedgerSheet = true
                                    }
                                    RadarIconButton(
                                        systemImage: "trash", size: 22, tint: SubRadarTheme.coral, helpText: "删除该笔流水"
                                    ) {
                                        Task { await viewModel.deleteBillingRecord(record) }
                                    }
                                }
                                .padding(.vertical, 8)

                                if index < viewModel.selectedRecords.count - 1 {
                                    RadarDivider()
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 240)
                }
            }
        }
        .customCard()
    }

    func kindColor(_ kind: BillingRecordKind) -> Color {
        switch kind {
        case .charge: return SubRadarTheme.templateColor(for: item.templateId)
        case .topUp: return SubRadarTheme.radarAccent
        case .refund: return SubRadarTheme.emerald
        }
    }
}
