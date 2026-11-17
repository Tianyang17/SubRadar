import AppKit
import SubRadarCore
import SwiftUI
import UniformTypeIdentifiers

extension SubscriptionEditorFormBody {
    var customFieldsEditorCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            RadarSectionTitle("订阅详情字段")

            if viewModel.customFields.isEmpty {
                Text("当前模版暂无扩展字段，可在下方自由添加。")
                    .font(SubRadarTheme.font(size: 11.5))
                    .foregroundStyle(palette.textMuted)
            } else {
                VStack(spacing: 10) {
                    ForEach(viewModel.customFields) { field in
                        let isDragging = draggingCustomFieldId == field.id
                        HStack(alignment: .top, spacing: 8) {
                            CustomFieldDragHandle(isDragging: isDragging)
                                .padding(.top, 2)
                                .onDrag {
                                    draggingCustomFieldId = field.id
                                    return NSItemProvider(object: field.id.uuidString as NSString)
                                }

                            Text(field.label)
                                .font(SubRadarTheme.font(size: 11.5, weight: .medium))
                                .foregroundStyle(palette.textSecondary)
                                .frame(width: 110, alignment: .leading)
                                .padding(.top, 7)

                            customFieldControl(for: fieldBinding(for: field))
                                .frame(maxWidth: .infinity, alignment: .leading)

                            RadarIconButton(
                                systemImage: "minus.circle.fill",
                                size: 26,
                                tint: palette.textMuted,
                                helpText: "移除此字段"
                            ) {
                                NSApp.keyWindow?.makeFirstResponder(nil)
                                withAnimation(.snappy) {
                                    viewModel.removeCustomField(id: field.id)
                                }
                            }
                            .padding(.top, 3)
                        }
                        .padding(.vertical, 2)
                        .padding(.horizontal, 4)
                        .background(
                            isDragging ? SubRadarTheme.radarAccent.opacity(0.06) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(
                                    isDragging ? SubRadarTheme.radarAccent.opacity(0.35) : Color.clear,
                                    lineWidth: 1
                                )
                        )
                        .onDrop(
                            of: [.text],
                            delegate: CustomFieldReorderDropDelegate(
                                targetFieldId: field.id,
                                draggingFieldId: $draggingCustomFieldId,
                                onMove: { fromId, targetId in
                                    viewModel.moveCustomField(fromId: fromId, toTargetId: targetId)
                                }
                            )
                        )
                    }
                }
            }

            RadarDivider()

            HStack(spacing: 8) {
                RadarTextField("新字段名称（如：机房面板）", text: $newFieldLabel)

                RadarSelectMenu(
                    options: CustomFieldType.allCases,
                    selection: $newFieldType,
                    label: { $0.displayName }
                )

                RadarButton("添加字段", systemImage: "plus", variant: .secondary) {
                    NSApp.keyWindow?.makeFirstResponder(nil)
                    withAnimation(.snappy) {
                        viewModel.addCustomField(label: newFieldLabel, type: newFieldType)
                        newFieldLabel = ""
                    }
                }
                .disabled(newFieldLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .customCard()
    }

    private func fieldBinding(for fallback: CustomField) -> Binding<CustomField> {
        let fieldId = fallback.id
        return Binding(
            get: { viewModel.customFields.first(where: { $0.id == fieldId }) ?? fallback },
            set: { updated in
                guard let idx = viewModel.customFields.firstIndex(where: { $0.id == fieldId }) else { return }
                viewModel.customFields[idx] = updated
            }
        )
    }

    var notesEditorCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            RadarSectionTitle("备注")
            RadarTextArea("补充续订注意事项、优惠码说明等...", text: $viewModel.notes, lineRange: 2...4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .customCard()
    }

    @ViewBuilder
    func customFieldControl(for field: Binding<CustomField>) -> some View {
        let key = field.wrappedValue.key
        switch key {
        case "provider_preset":
            RadarSelectMenu(
                options: APIBalanceProviderPreset.allCases,
                selection: Binding(
                    get: { APIBalanceProviderPreset(raw: field.wrappedValue.value) },
                    set: { viewModel.updateAPIProviderPreset($0) }
                ),
                fullWidth: true,
                label: { $0.displayName }
            )

        case "current_balance":
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "gauge.with.needle")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(SubRadarTheme.radarAccent)

                        if field.wrappedValue.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("尚未查询（点击右侧查询余额）")
                                .font(SubRadarTheme.font(size: 12))
                                .foregroundStyle(palette.textMuted)
                        } else {
                            Text("\(viewModel.currency) \(field.wrappedValue.value)")
                                .font(SubRadarTheme.font(size: 12.5, weight: .semibold))
                                .fontDesign(.monospaced)
                                .foregroundStyle(palette.textPrimary)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 32)
                    .background(
                        palette.inputSurface,
                        in: RoundedRectangle(cornerRadius: SubRadarTheme.controlCornerRadius, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: SubRadarTheme.controlCornerRadius, style: .continuous)
                            .strokeBorder(palette.borderSubtle, lineWidth: 1)
                    )

                    RadarButton(
                        viewModel.isProbingBalance ? "查询中..." : "查询余额",
                        systemImage: "arrow.clockwise",
                        variant: .secondary,
                        size: .small
                    ) {
                        Task { await viewModel.probeCurrentAPIBalance() }
                    }
                    .disabled(viewModel.isProbingBalance)
                }

                if let msg = viewModel.balanceProbeStatusMessage {
                    Text(msg)
                        .font(SubRadarTheme.font(size: 11, weight: .medium))
                        .foregroundStyle(viewModel.balanceProbeIsError ? SubRadarTheme.coral : SubRadarTheme.emerald)
                }
            }

        case "instance_type":
            PresetSelectOrCustomField(
                options: FieldOptionCatalog.serverTypes,
                customPlaceholder: "输入自定义服务器类型",
                text: field.value
            )

        case "region":
            PresetSelectOrCustomField(
                options: FieldOptionCatalog.globalRegions,
                customPlaceholder: "输入自定义机房 / 地区（如 德国法兰克福 CN2）",
                searchable: true,
                text: field.value
            )

        case "account_alive_status":
            PresetSelectOrCustomField(
                options: FieldOptionCatalog.aliveStatuses,
                customPlaceholder: "输入自定义存活状态说明",
                text: field.value
            )

        case "account_source":
            PresetSelectOrCustomField(
                options: FieldOptionCatalog.accountSources,
                customPlaceholder: "输入自定义来源（如发卡站 / 合租群）",
                text: Binding(
                    get: { field.wrappedValue.value },
                    set: { viewModel.updateAccountSource($0) }
                )
            )

        case "account_source_detail":
            RadarTextField(
                "请输入具体渠道来源（如：淘宝店铺 / 发卡平台 / 拼车群名称）",
                text: field.value
            )

        case "purchase_source":
            PresetSelectOrCustomField(
                options: FieldOptionCatalog.purchaseSources,
                customPlaceholder: "输入自定义购买来源",
                text: Binding(
                    get: { field.wrappedValue.value },
                    set: { viewModel.updatePurchaseSource($0) }
                )
            )

        case "purchase_source_detail":
            RadarTextField(
                "请输入具体来源（如：淘宝店铺 / 发卡平台 / 拼车群名称）",
                text: field.value
            )

        case "supported_platforms":
            PlatformMultiSelectField(value: field.value)

        case "operating_system":
            VPSOperatingSystemComposerField(value: field.value)

        case "instance_spec":
            VPSSpecComposerField(value: field.value)

        case "traffic_spec":
            VPSTrafficComposerField(value: field.value)

        default:
            if field.wrappedValue.isSensitive {
                RadarSecureField("请输入\(field.wrappedValue.label)", text: field.value)
            } else if field.wrappedValue.type == .url {
                HStack(spacing: 8) {
                    RadarTextField(
                        "请输入\(field.wrappedValue.label)",
                        text: field.value,
                        monospaced: true
                    )

                    let targetURL = SubRadarFormatter.normalizedWebURL(from: field.wrappedValue.value)
                    RadarButton("打开", systemImage: "arrow.up.right.square", variant: .secondary, size: .small) {
                        if let targetURL {
                            NSWorkspace.shared.open(targetURL)
                        }
                    }
                    .disabled(targetURL == nil)
                }
            } else {
                RadarTextField(
                    key == "plan_tier"
                        ? "请输入\(field.wrappedValue.label)（如 Plus / Pro / SVIP 年卡）" : "请输入\(field.wrappedValue.label)",
                    text: field.value,
                    monospaced: field.wrappedValue.type == .number
                )
            }
        }
    }
}
