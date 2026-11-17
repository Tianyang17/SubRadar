import AppKit
import SubRadarCore
import SwiftUI
import UniformTypeIdentifiers

extension SubscriptionEditorFormBody {
    var externalImportSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            RadarSegmentedBar(
                options: IconImportTab.allCases,
                selection: $activeIconTab,
                label: { $0.rawValue }
            )

            switch activeIconTab {
            case .appStore:
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        RadarTextField(
                            "输入 App Store 应用名称联想搜索...",
                            text: $viewModel.appStoreKeyword,
                            systemImage: "magnifyingglass",
                            showClearButton: true
                        )
                        .onSubmit {
                            Task { await viewModel.searchAppStore() }
                        }
                        RadarButton("搜索", variant: .secondary) {
                            Task { await viewModel.searchAppStore() }
                        }
                    }

                    if !viewModel.appStoreResults.isEmpty {
                        VStack(spacing: 5) {
                            ForEach(viewModel.appStoreResults) { result in
                                Button {
                                    Task { await viewModel.selectAppStoreItem(result) }
                                } label: {
                                    HStack(spacing: 10) {
                                        appStoreResultThumbnail(url: result.bestArtworkURL)
                                        Text(result.trackName)
                                            .font(SubRadarTheme.uiFont(size: 12.5, weight: .medium))
                                            .foregroundStyle(palette.textPrimary)
                                            .lineLimit(1)
                                        Spacer()
                                        Text(result.artistName ?? "")
                                            .font(SubRadarTheme.uiFont(size: 11))
                                            .foregroundStyle(palette.textMuted)
                                            .lineLimit(1)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        palette.inputSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

            case .localApp:
                HStack(spacing: 10) {
                    RadarButton("打开 /Applications 目录选择应用...", systemImage: "folder.fill", variant: .secondary) {
                        openApplicationsPicker()
                    }
                    Text("仅支持选择 .app 应用包自动读取名称与高清图标")
                        .font(SubRadarTheme.uiFont(size: 12))
                        .foregroundStyle(palette.textMuted)
                }
            }
        }
    }

    func openApplicationsPicker() {
        let panel = NSOpenPanel()
        panel.title = "从应用程序目录选择应用"
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        if panel.runModal() == .OK, let url = panel.url {
            viewModel.importLocalApp(at: url)
        }
    }

    func pasteImageFromClipboard() {
        let pb = NSPasteboard.general
        if let image = NSImage(pasteboard: pb), let tiff = image.tiffRepresentation {
            viewModel.importUploadedImageData(tiff)
        } else {
            viewModel.iconErrorMessage = "剪贴板中未检测到图片内容"
        }
    }

    @ViewBuilder
    func presetThumbnail(for preset: PopularSoftwarePreset) -> some View {
        if let iconData = PopularSoftwarePresetManager.bundledIconData(for: preset),
            let nsImage = NSImage(data: iconData)
        {
            Image(nsImage: nsImage)
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .aspectRatio(contentMode: .fill)
                .frame(width: 24, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                )
        } else {
            Text(preset.monogram)
                .font(SubRadarTheme.font(size: 8.5, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(
                    presetAccentColor(preset.accentHex),
                    in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                )
        }
    }

    @ViewBuilder
    func appStoreResultThumbnail(url: URL?) -> some View {
        if let url {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fill)
                default:
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(palette.cardSurface)
                        .overlay(
                            Image(systemName: "app.badge")
                                .font(.system(size: 13))
                                .foregroundStyle(SubRadarTheme.radarAccent)
                        )
                }
            }
            .frame(width: 26, height: 26)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            Image(systemName: "app.badge")
                .font(.system(size: 16))
                .foregroundStyle(SubRadarTheme.radarAccent)
                .frame(width: 26, height: 26)
        }
    }

    func presetAccentColor(_ hex: String) -> Color {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        guard Scanner(string: cleaned).scanHexInt64(&int), cleaned.count == 6 else {
            return SubRadarTheme.radarAccent
        }
        return Color(
            red: Double((int >> 16) & 0xFF) / 255.0,
            green: Double((int >> 8) & 0xFF) / 255.0,
            blue: Double(int & 0xFF) / 255.0
        )
    }
}
