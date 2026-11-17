import AppKit
import SubRadarCore
import SwiftUI
import UniformTypeIdentifiers

extension SubscriptionEditorFormBody {
    var quickImportCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(SubRadarTheme.radarAccent)

                VStack(alignment: .leading, spacing: 2) {
                    Text("预置服务库与外部导入")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.textPrimary)
                    Text("从常用软件预置库、App Store 或本机应用中快速填入名称、图标与计费模板")
                        .font(.system(size: 11))
                        .foregroundStyle(palette.textSecondary)
                }

                Spacer()

                if viewModel.isFetchingIcon {
                    ProgressView().controlSize(.small)
                }

                RadarButton(
                    isQuickImportExpanded ? "收起" : "展开选择",
                    systemImage: isQuickImportExpanded ? "chevron.up" : "chevron.down",
                    variant: .secondary,
                    size: .small
                ) {
                    withAnimation(.snappy(duration: 0.16)) {
                        isQuickImportExpanded.toggle()
                    }
                }
            }

            if isQuickImportExpanded {
                RadarDivider()

                stepBadge(number: 1, title: "选择常见软件或服务")
                presetGridSection

                RadarDivider()

                HStack {
                    stepBadge(number: 2, title: "预置库没有？从外部导入")
                    Spacer()
                    Text("App Store / 本机应用自动带入图标")
                        .font(SubRadarTheme.uiFont(size: 11))
                        .foregroundStyle(palette.textMuted)
                }
                externalImportSection

                RadarDivider()

                HStack {
                    Spacer()
                    RadarButton(
                        "收起预置服务库与外部导入",
                        systemImage: "chevron.up",
                        variant: .ghost,
                        size: .small
                    ) {
                        withAnimation(.snappy(duration: 0.16)) {
                            isQuickImportExpanded = false
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .customCard()
    }

    var identityConfirmationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            RadarSectionTitle("确认订阅名称与图标")
            identityConfirmationRow
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .customCard()
    }

    func stepBadge(number: Int, title: String) -> some View {
        HStack(spacing: 8) {
            Text(String(format: "%02d", number))
                .font(SubRadarTheme.font(size: 10.5, weight: .bold))
                .foregroundStyle(SubRadarTheme.radarAccent)
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background(
                    SubRadarTheme.radarAccent.opacity(0.10), in: RoundedRectangle(cornerRadius: 5, style: .circular)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .circular)
                        .strokeBorder(SubRadarTheme.radarAccent.opacity(0.24), lineWidth: 0.75)
                )

            Text(title)
                .font(SubRadarTheme.uiFont(size: 12.5, weight: .semibold))
                .foregroundStyle(palette.textPrimary)
        }
    }

    func iconMenuItems() -> [RadarContextMenuItem] {
        var items: [RadarContextMenuItem] = [
            RadarContextMenuItem(title: "上传本地图片...", systemImage: "photo") {
                showImagePicker = true
            },
            RadarContextMenuItem(title: "从剪贴板粘贴", systemImage: "doc.on.clipboard") {
                pasteImageFromClipboard()
            },
            RadarContextMenuItem(title: "从网站获取图标...", systemImage: "globe") {
                withAnimation(.snappy(duration: 0.16)) {
                    showFaviconBar = true
                }
                isFaviconFieldFocused = true
            }
        ]
        if viewModel.iconData != nil {
            items.append(
                RadarContextMenuItem(title: "清除图标", systemImage: "trash", isDestructive: true) {
                    viewModel.iconData = nil
                }
            )
        }
        return items
    }

    var identityConfirmationRow: some View {
        let menuItems = iconMenuItems()
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                Button {
                    RadarFloatingMenuPresenter.show(items: menuItems, palette: palette)
                } label: {
                    SubscriptionAvatarView(
                        iconData: viewModel.iconData,
                        categoryId: viewModel.selectedCategoryId,
                        categories: viewModel.categories,
                        templateId: viewModel.selectedTemplateId,
                        templates: templates,
                        size: 62,
                        showEmptyHint: true
                    )
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(SubRadarTheme.radarAccent, palette.cardSurface)
                            .offset(x: 4, y: 4)
                    }
                }
                .buttonStyle(.plain)
                .radarContextMenu(menuItems)
                .help("左键点击或右键点击左侧图标，均可更换图标")

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("订阅名称")
                            .font(SubRadarTheme.uiFont(size: 12, weight: .medium))
                            .foregroundStyle(palette.textSecondary)
                        Spacer()
                        Text("左键或右键左侧图标可更换（上传 / 剪贴板 / 网站抓图）")
                            .font(SubRadarTheme.uiFont(size: 11))
                            .foregroundStyle(palette.textMuted)
                    }
                    RadarTextField("例如：ChatGPT、QQ音乐、野草云...", text: $viewModel.name)
                }
            }

            if showFaviconBar {
                HStack(spacing: 8) {
                    RadarTextField(
                        "输入网站域名或链接，例如 openai.com 或 yecaoyun.com",
                        text: $viewModel.faviconURLInput,
                        systemImage: "globe",
                        monospaced: true,
                        focusBinding: $isFaviconFieldFocused
                    )
                    .onSubmit {
                        Task { await viewModel.fetchFavicon() }
                    }

                    if viewModel.isFetchingIcon {
                        ProgressView().controlSize(.small)
                    }

                    RadarButton("提取图标", variant: .secondary) {
                        Task { await viewModel.fetchFavicon() }
                    }

                    Button {
                        withAnimation(.snappy(duration: 0.14)) {
                            showFaviconBar = false
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(palette.textMuted)
                            .frame(width: 26, height: 26)
                            .background(palette.inputSurface, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if let iconErr = viewModel.iconErrorMessage {
                Text(iconErr)
                    .font(SubRadarTheme.uiFont(size: 11.5))
                    .foregroundStyle(SubRadarTheme.coral)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
