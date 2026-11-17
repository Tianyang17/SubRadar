import SubRadarCore
import SwiftUI

private enum APITopUpInputMode: String, CaseIterable, Identifiable {
    case perCharge = "逐笔填写"
    case averageTotal = "按总额平均"
    var id: String { rawValue }
}

extension SubscriptionEditorFormBody {
    @ViewBuilder
    var apiBalanceBillingContent: some View {
        let count = viewModel.parsedAPITopUpCount
        let symbol = CommonCurrency.symbol(for: viewModel.currency)

        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(minimum: 220), spacing: 14, alignment: .top),
                    GridItem(.flexible(minimum: 220), spacing: 14, alignment: .top)
                ],
                alignment: .leading,
                spacing: 12
            ) {
                formField(label: "结算币种") {
                    RadarSelectMenu(
                        options: CommonCurrency.allCases.map(\.rawValue),
                        selection: $viewModel.currency,
                        fullWidth: true,
                        label: { "\($0) (\(CommonCurrency.symbol(for: $0)))" }
                    )
                }

                formField(label: "开始记录时间") {
                    RadarDatePicker(selection: $viewModel.startDate, fullWidth: true)
                }

                if !viewModel.isEditing {
                    formField(label: "充值次数") {
                        HStack(spacing: 8) {
                            RadarIconButton(
                                systemImage: "minus",
                                size: 28,
                                tint: palette.textSecondary,
                                helpText: "减少充值次数"
                            ) {
                                viewModel.updateAPITopUpCount(count - 1)
                            }
                            .background(
                                palette.inputSurface,
                                in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .strokeBorder(palette.borderSubtle, lineWidth: 1)
                            )

                            RadarTextField(
                                "1",
                                text: Binding(
                                    get: { viewModel.apiTopUpCountText },
                                    set: { viewModel.syncAPITopUpCountText($0) }
                                ),
                                monospaced: true
                            )
                            .frame(width: 72)

                            RadarIconButton(
                                systemImage: "plus",
                                size: 28,
                                tint: palette.textSecondary,
                                helpText: "增加充值次数"
                            ) {
                                viewModel.updateAPITopUpCount(count + 1)
                            }
                            .background(
                                palette.inputSurface,
                                in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .strokeBorder(palette.borderSubtle, lineWidth: 1)
                            )

                            Text("次")
                                .font(SubRadarTheme.font(size: 12, weight: .medium))
                                .foregroundStyle(palette.textSecondary)

                            Spacer(minLength: 0)
                        }
                    }

                    formField(label: "金额录入方式") {
                        RadarSegmentedBar(
                            options: APITopUpInputMode.allCases,
                            selection: Binding(
                                get: { viewModel.isAPITopUpAverageMode ? .averageTotal : .perCharge },
                                set: { viewModel.setAPITopUpAverageMode($0 == .averageTotal) }
                            ),
                            label: { $0.rawValue }
                        )
                    }
                } else {
                    formField(label: "初始入账金额") {
                        RadarTextField(
                            "请输入金额",
                            text: Binding(
                                get: { viewModel.priceText },
                                set: { viewModel.updatePurchasePriceText($0) }
                            ),
                            prefixText: symbol,
                            monospaced: true
                        )
                    }
                }
            }

            if !viewModel.isEditing {
                if viewModel.isAPITopUpAverageMode {
                    averageTopUpSection(count: count, symbol: symbol)
                } else {
                    perRechargeTopUpSection(count: count, symbol: symbol)
                }
            }
        }
    }

    private func averageTopUpSection(count: Int, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                formField(label: "充值总金额") {
                    RadarTextField(
                        "输入总金额（自动均分到 \(count) 次充值）",
                        text: $viewModel.apiTopUpTotalText,
                        prefixText: symbol,
                        monospaced: true
                    )
                }
                .frame(maxWidth: 280)

                VStack(alignment: .leading, spacing: 3) {
                    Text("自动均分结果")
                        .font(SubRadarTheme.font(size: 11, weight: .medium))
                        .foregroundStyle(palette.textSecondary)
                    Text(
                        "每次约 \(SubRadarFormatter.formatMoney(viewModel.averageAPITopUpPerCharge, currency: viewModel.currency)) × \(count) 次"
                    )
                    .font(SubRadarTheme.font(size: 12.5, weight: .semibold))
                    .foregroundStyle(SubRadarTheme.radarAccent)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(12)
        .background(palette.inputSurface.opacity(0.65), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(palette.borderSubtle, lineWidth: 1)
        )
    }

    private func perRechargeTopUpSection(count: Int, symbol: String) -> some View {
        let columns =
            count > 1
            ? [
                GridItem(.flexible(minimum: 180), spacing: 10),
                GridItem(.flexible(minimum: 180), spacing: 10)
            ]
            : [GridItem(.flexible(minimum: 220))]

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("逐次充值金额明细")
                    .font(SubRadarTheme.uiFont(size: 11.5, weight: .semibold))
                    .foregroundStyle(palette.textSecondary)
                Spacer()
                Text(
                    "合计：\(SubRadarFormatter.formatMoney(viewModel.estimatedTotalTopUpAmount, currency: viewModel.currency))（共 \(count) 笔流水）"
                )
                .font(SubRadarTheme.font(size: 11.5, weight: .semibold))
                .foregroundStyle(SubRadarTheme.radarAccent)
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(0..<count, id: \.self) { index in
                    HStack(spacing: 8) {
                        Text("第 \(index + 1) 次")
                            .font(SubRadarTheme.font(size: 11, weight: .medium))
                            .foregroundStyle(palette.textMuted)
                            .frame(width: 48, alignment: .leading)

                        RadarTextField(
                            "金额",
                            text: Binding(
                                get: {
                                    index < viewModel.apiTopUpAmounts.count ? viewModel.apiTopUpAmounts[index] : ""
                                },
                                set: { viewModel.updateAPITopUpAmount($0, at: index) }
                            ),
                            prefixText: symbol,
                            monospaced: true
                        )
                    }
                }
            }
        }
        .padding(12)
        .background(palette.inputSurface.opacity(0.65), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(palette.borderSubtle, lineWidth: 1)
        )
    }
}
