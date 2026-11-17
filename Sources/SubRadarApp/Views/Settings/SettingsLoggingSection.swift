import AppKit
import SubRadarCore
import SwiftUI

struct SettingsLoggingSection: View {
    @Environment(\.radarPalette) private var palette
    var onError: (String) -> Void = { _ in }

    private var logDirectoryURL: URL {
        AppLogService.defaultLogDirectoryURL()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("运行日志")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(palette.textPrimary)
                    Text("记录 API 余额探针与自动更新状态（自动脱敏密钥并按天保留 7 天）")
                        .font(.system(size: 12))
                        .foregroundStyle(palette.textSecondary)
                }

                Spacer(minLength: 12)

                RadarButton(
                    "打开日志目录",
                    systemImage: "folder",
                    variant: .secondary,
                    size: .small
                ) {
                    openLogDirectory()
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "doc.text")
                    .font(.system(size: 11.5))
                    .foregroundStyle(palette.textMuted)
                Text(logDirectoryURL.path)
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundStyle(palette.textSecondary)
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(palette.inputSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(palette.borderSubtle, lineWidth: 1)
            )
        }
        .customCard(padding: 18)
    }

    private func openLogDirectory() {
        let dir = logDirectoryURL
        Task {
            do {
                _ = try await AppLogService.shared.ensureDirectoryExists()
                await AppLogService.shared.log(.info, category: .app, "打开本地运行日志目录")
                await MainActor.run {
                    _ = NSWorkspace.shared.open(dir)
                }
            } catch {
                await MainActor.run {
                    onError("无法打开日志目录：\(error.localizedDescription)")
                }
            }
        }
    }
}
