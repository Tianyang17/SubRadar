import AppKit
import SubRadarCore
import SwiftUI
import UniformTypeIdentifiers

extension SubscriptionEditorFormBody {
    var billingConfigurationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                RadarSectionTitle("分类、模版与计费设置")
                Spacer()
                if viewModel.isInfrastructureTemplate && !viewModel.isEditing {
                    RadarSegmentedBar(
                        options: InfraAssetKind.allCases,
                        selection: Binding(
                            get: {
                                viewModel.selectedTemplateId == TemplateDefinition.BuiltinID.domain ? .domain : .host
                            },
                            set: { newKind in
                                selectedInfraKind = newKind
                                withAnimation(.snappy(duration: 0.16)) {
                                    viewModel.applyInfrastructureKindChoice(isHost: newKind == .host)
                                }
                            }
                        ),
                        label: { $0.rawValue }
                    )
                    .frame(maxWidth: 210)
                }
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible(minimum: 220), spacing: 14, alignment: .top),
                    GridItem(.flexible(minimum: 220), spacing: 14, alignment: .top)
                ],
                alignment: .leading,
                spacing: 12
            ) {
                formField(label: "所属分类") {
                    RadarSelectMenu(
                        options: viewModel.categories.map(\.id),
                        selection: $viewModel.selectedCategoryId,
                        fullWidth: true,
                        iconSymbol: { id in
                            viewModel.categories.first(where: { $0.id == id })?.iconSymbol
                        },
                        accentColor: { id in
                            viewModel.categories.first(where: { $0.id == id }).map {
                                SubRadarTheme.categoryColor(for: $0.colorKey)
                            }
                        },
                        footerAction: RadarSelectMenuAction(title: "新建分类...", systemImage: "plus.circle.fill") {
                            newCategoryName = ""
                            newCategorySymbol = "sparkles"
                            newCategoryColor = .indigo
                            showInlineCategorySheet = true
                        },
                        label: { id in
                            viewModel.categories.first(where: { $0.id == id })?.name ?? "默认分类"
                        }
                    )
                }

                formField(label: "字段模版") {
                    RadarSelectMenu(
                        options: templates.map(\.id),
                        selection: Binding(
                            get: { viewModel.selectedTemplateId },
                            set: { newId in
                                withAnimation(.snappy(duration: 0.2)) {
                                    viewModel.switchTemplate(to: newId)
                                }
                            }
                        ),
                        fullWidth: true,
                        iconSymbol: { id in
                            templates.first(where: { $0.id == id })?.iconSymbol
                        },
                        accentColor: { id in
                            SubRadarTheme.templateColor(for: id)
                        },
                        label: { id in
                            templates.first(where: { $0.id == id })?.name ?? "自定义"
                        }
                    )
                }

                if !viewModel.isApiBalanceTemplate {
                    formField(label: viewModel.billingCycleType == .oneTime ? "买断价格" : "购买价格") {
                        HStack(spacing: 8) {
                            RadarSelectMenu(
                                options: CommonCurrency.allCases.map(\.rawValue),
                                selection: $viewModel.currency,
                                label: { $0 }
                            )

                            RadarTextField(
                                "请输入金额",
                                text: Binding(
                                    get: { viewModel.priceText },
                                    set: { viewModel.updatePurchasePriceText($0) }
                                ),
                                prefixText: CommonCurrency.symbol(for: viewModel.currency),
                                monospaced: true
                            )
                        }
                    }

                    if viewModel.billingCycleType != .oneTime {
                        formField(label: "续期价格") {
                            RadarTextField(
                                "0.00（默认同购买价）",
                                text: Binding(
                                    get: { viewModel.renewalPriceText },
                                    set: { viewModel.updateRenewalPriceText($0) }
                                ),
                                prefixText: CommonCurrency.symbol(for: viewModel.currency),
                                monospaced: true
                            )
                        }
                    }

                    billingFrequencyField
                    billingReminderAndDatesFields
                }
            }

            if viewModel.isApiBalanceTemplate {
                apiBalanceBillingContent
            }

            renewalModeSelectionSection
            historicalBillingToggleSection

            if !viewModel.isApiBalanceTemplate {
                SubscriptionEditorManualHistorySection(viewModel: viewModel)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .customCard()
    }
}
