import SubRadarCore
import SwiftUI

extension SubscriptionDetailView {
    var customFieldsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                RadarSectionTitle("专属属性与资产信息")
                Spacer()
                if let sshURL = item.sshURL, let sshCommand = item.sshCommand {
                    HStack(spacing: 8) {
                        RadarButton("复制 SSH", systemImage: "doc.on.doc", variant: .secondary, size: .small) {
                            ClipboardHelper.copy(sshCommand)
                            viewModel.showToast("已复制命令: \(sshCommand)")
                        }
                        RadarButton("连接 SSH", systemImage: "terminal.fill", variant: .primary, size: .small) {
                            NSWorkspace.shared.open(sshURL)
                        }
                    }
                }
            }

            RadarDivider()

            VStack(spacing: 10) {
                ForEach(item.customFields.sorted(by: { $0.sortOrder < $1.sortOrder })) { field in
                    customFieldRow(field)
                }
            }
        }
        .customCard()
    }

    @ViewBuilder
    func customFieldRow(_ field: CustomField) -> some View {
        let isRevealed = viewModel.revealedSecretFieldIds.contains(field.id)
        let displayValue: String = {
            if field.value.isEmpty { return "未填写" }
            if field.isSensitive && !isRevealed { return "••••••••••••" }
            return field.value
        }()

        HStack(spacing: 12) {
            Text(field.label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(palette.textSecondary)
                .frame(width: 120, alignment: .leading)

            Group {
                if field.key == "supported_platforms", !field.value.isEmpty {
                    let platforms = FieldOptionCatalog.parsedPlatforms(from: field.value)
                    HStack(spacing: 5) {
                        ForEach(platforms, id: \.self) { platform in
                            Text(platform)
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundStyle(SubRadarTheme.radarAccent)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2.5)
                                .background(
                                    SubRadarTheme.radarAccent.opacity(0.1),
                                    in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                                )
                        }
                    }
                } else if field.type == .url,
                    let url = SubRadarFormatter.normalizedWebURL(from: field.value),
                    !field.value.isEmpty
                {
                    Link(field.value, destination: url)
                        .font(.system(size: 13))
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text(displayValue)
                        .font(
                            field.type == .number || field.key.contains("ip") || field.isSensitive
                                ? .system(size: 13, design: .monospaced)
                                : .system(size: 13)
                        )
                        .foregroundStyle(field.value.isEmpty ? palette.textMuted : palette.textPrimary)
                        .textSelection(.enabled)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()

            if !field.value.isEmpty {
                HStack(spacing: 6) {
                    if field.type == .url, let url = SubRadarFormatter.normalizedWebURL(from: field.value) {
                        RadarIconButton(
                            systemImage: "arrow.up.right.square",
                            size: 26,
                            tint: SubRadarTheme.radarAccent,
                            helpText: "在浏览器中打开链接"
                        ) {
                            NSWorkspace.shared.open(url)
                        }
                    }

                    if field.isSensitive {
                        RadarIconButton(
                            systemImage: isRevealed ? "eye.slash" : "eye",
                            size: 26,
                            helpText: isRevealed ? "隐藏敏感内容" : "验证身份并显示"
                        ) {
                            Task { await viewModel.toggleSecretReveal(for: field.id) }
                        }
                    }

                    RadarIconButton(
                        systemImage: "doc.on.doc",
                        size: 26,
                        helpText: "复制到剪贴板"
                    ) {
                        ClipboardHelper.copy(field.value)
                        viewModel.showToast("已复制「\(field.label)」")
                    }
                }
            }
        }
        .padding(.vertical, 3)
    }

    var notesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            RadarSectionTitle("备注")
            Text(item.notes)
                .font(.system(size: 13))
                .foregroundStyle(palette.textPrimary)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .customCard()
    }

    var ledgerRecordSheetContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(editingRecord == nil ? "记一笔历史花费 / 充值 / 退款" : "编辑流水记录")
                .font(SubRadarTheme.uiFont(size: 15, weight: .bold))
                .foregroundStyle(palette.textPrimary)

            VStack(alignment: .leading, spacing: 10) {
                Text("记账类型")
                    .font(SubRadarTheme.uiFont(size: 11.5, weight: .medium))
                    .foregroundStyle(palette.textSecondary)
                RadarSegmentedBar(
                    options: BillingRecordKind.allCases,
                    selection: $ledgerKind,
                    label: { $0.displayName }
                )

                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("币种")
                            .font(SubRadarTheme.uiFont(size: 11.5, weight: .medium))
                            .foregroundStyle(palette.textSecondary)
                        RadarSelectMenu(
                            options: CommonCurrency.allCases.map(\.rawValue),
                            selection: $ledgerCurrency,
                            label: { "\($0) (\(CommonCurrency.symbol(for: $0)))" }
                        )
                        .frame(width: 116)
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text("金额")
                            .font(SubRadarTheme.uiFont(size: 11.5, weight: .medium))
                            .foregroundStyle(palette.textSecondary)
                        RadarTextField(
                            "0.00",
                            text: $ledgerAmountText,
                            prefixText: CommonCurrency.symbol(for: ledgerCurrency),
                            monospaced: true
                        )
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("入账日期")
                        .font(SubRadarTheme.uiFont(size: 11.5, weight: .medium))
                        .foregroundStyle(palette.textSecondary)
                    RadarDatePicker(selection: $ledgerDate, fullWidth: true)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("备注（可选）")
                        .font(SubRadarTheme.uiFont(size: 11.5, weight: .medium))
                        .foregroundStyle(palette.textSecondary)
                    RadarTextField("例如：黑五优惠购入 / API 充值 / 退款差价", text: $ledgerNote)
                }
            }

            HStack {
                Spacer()
                RadarButton("取消", variant: .ghost, size: .small) {
                    showLedgerSheet = false
                }
                RadarButton("保存", systemImage: "checkmark", variant: .primary, size: .small) {
                    guard
                        let amount = Decimal(string: ledgerAmountText.trimmingCharacters(in: .whitespacesAndNewlines)),
                        amount >= 0
                    else {
                        return
                    }
                    let existing = editingRecord
                    let kind = ledgerKind
                    let curr = ledgerCurrency
                    let date = ledgerDate
                    let note = ledgerNote
                    showLedgerSheet = false
                    isRecordsExpanded = true
                    Task {
                        if let existing {
                            await viewModel.updateBillingRecord(
                                existing,
                                newAmount: amount,
                                currency: curr,
                                kind: kind,
                                billedAt: date,
                                note: note
                            )
                        } else {
                            await viewModel.addManualBillingRecord(
                                for: item,
                                amount: amount,
                                currency: curr,
                                kind: kind,
                                billedAt: date,
                                note: note
                            )
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 390)
        .background(palette.windowBackground)
    }
}
