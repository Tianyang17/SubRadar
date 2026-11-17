import AppKit
import SubRadarCore
import SwiftUI
import UniformTypeIdentifiers

extension SubscriptionEditorFormBody {
    @ViewBuilder
    var billingFrequencyField: some View {
        formField(label: "付费频率") {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    if viewModel.billingCycleUnit != .oneTime {
                        Text("每")
                            .font(SubRadarTheme.font(size: 12, weight: .medium))
                            .foregroundStyle(palette.textSecondary)

                        RadarTextField(
                            "1",
                            text: Binding(
                                get: { viewModel.billingCycleIntervalText },
                                set: { viewModel.updateBillingIntervalText($0) }
                            ),
                            monospaced: true
                        )
                        .frame(width: 58)
                    }

                    RadarSelectMenu(
                        options: BillingCycleUnit.allCases,
                        selection: $viewModel.billingCycleUnit,
                        fullWidth: true,
                        label: { unit in
                            viewModel.billingCycleUnit == .oneTime
                                ? unit.selectionLabel
                                : unit.intervalUnitLabel
                        }
                    )
                }

                Text("当前：\(viewModel.billingCycleDisplayName)（支持多期，如 4 个月 / 3 年）")
                    .font(SubRadarTheme.font(size: 10.5))
                    .foregroundStyle(palette.textMuted)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    var billingReminderAndDatesFields: some View {
        if viewModel.billingCycleType != .oneTime {
            formField(label: "到期前提醒") {
                RadarSelectMenu(
                    options: reminderDayOptions,
                    selection: $viewModel.reminderDaysBefore,
                    fullWidth: true,
                    label: { SubscriptionItem.reminderOptionLabel($0) }
                )
            }
        }

        formField(label: "开始时间") {
            RadarDatePicker(selection: $viewModel.startDate, fullWidth: true)
        }

        if viewModel.billingCycleType != .oneTime {
            formField(label: "结束 / 下次续订") {
                RadarDatePicker(selection: $viewModel.nextRenewalDate, fullWidth: true)
            }
        }
    }

    @ViewBuilder
    var renewalModeSelectionSection: some View {
        if !viewModel.isApiBalanceTemplate && viewModel.billingCycleType != .oneTime {
            formField(label: "续订方式") {
                VStack(alignment: .leading, spacing: 8) {
                    RadarSegmentedBar(
                        options: RenewalMode.allCases,
                        selection: $viewModel.renewalMode,
                        label: { $0.displayName }
                    )

                    if viewModel.renewalMode == .custom {
                        RadarTextField(
                            "填写自定义续订方式（如：到期联系渠道代续 / 群内通知拼车 / 发工单续期）",
                            text: $viewModel.customRenewalNote,
                            showClearButton: true
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    var historicalBillingToggleSection: some View {
        if !viewModel.isEditing && !viewModel.isApiBalanceTemplate && viewModel.billingCycleType != .oneTime {
            RadarDivider()

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("计入历史计费（按周期自动累加）")
                        .font(SubRadarTheme.font(size: 12.5, weight: .semibold))
                        .foregroundStyle(palette.textPrimary)
                    Text("若开始时间与结束时间跨越多期，保存时将自动生成历史扣费流水并计入总开销")
                        .font(SubRadarTheme.font(size: 11))
                        .foregroundStyle(palette.textMuted)
                }
                Spacer()
                RadarToggle(
                    "",
                    isOn: Binding(
                        get: { viewModel.includeHistoricalBilling },
                        set: { newValue in
                            withAnimation(.snappy) {
                                viewModel.includeHistoricalBilling = newValue
                            }
                        }
                    ))
            }

            if viewModel.includeHistoricalBilling {
                let preview = viewModel.historicalPreview
                HStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundStyle(SubRadarTheme.radarAccent)
                    Text(
                        "检测到 \(preview.cycleCount) 个完整计费周期，将自动累加历史支出 \(SubRadarFormatter.formatMoney(preview.totalAmount, currency: viewModel.currency))"
                    )
                    .font(SubRadarTheme.font(size: 11.5, weight: .medium))
                    .foregroundStyle(palette.textPrimary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    SubRadarTheme.radarAccent.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: SubRadarTheme.controlCornerRadius, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: SubRadarTheme.controlCornerRadius, style: .continuous)
                        .strokeBorder(SubRadarTheme.radarAccent.opacity(0.24), lineWidth: 1)
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    @ViewBuilder
    func formField<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(SubRadarTheme.font(size: 11.5, weight: .medium))
                .foregroundStyle(palette.textSecondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
