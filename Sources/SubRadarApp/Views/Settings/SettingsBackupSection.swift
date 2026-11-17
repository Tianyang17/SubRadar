import AppKit
import SubRadarCore
import SwiftUI
import UniformTypeIdentifiers

extension SettingsView {
    var backupAndExportSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("数据导出与全量备份")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)
                Text("导出 UTF-8 CSV 财务账单流水（支持 Excel / Numbers），或导出/恢复完整 JSON 镜像备份")
                    .font(.system(size: 12))
                    .foregroundStyle(palette.textSecondary)
            }

            Divider().overlay(palette.borderSubtle)

            settingRow(
                title: "JSON 备份包含敏感明文",
                subtitle: "开启后将把 API Key、SSH 密码或密钥序列号明文写入导出的 JSON 文件，请妥善保管"
            ) {
                RadarToggle("", isOn: $includeSecretsInBackup)
            }

            HStack(spacing: 10) {
                RadarButton("导出 CSV 财务账单明细", systemImage: "tablecells", variant: .secondary) {
                    Task { await exportCSV() }
                }
                .disabled(isExportingOrRestoring)

                RadarButton("导出 JSON 全量备份", systemImage: "externaldrive.badge.plus", variant: .secondary) {
                    Task { await exportJSON() }
                }
                .disabled(isExportingOrRestoring)

                Spacer()

                RadarButton("从 JSON 备份恢复...", systemImage: "arrow.counterclockwise.circle", variant: .primary) {
                    pickJSONBackupToRestore()
                }
                .disabled(isExportingOrRestoring)
            }
        }
        .customCard(padding: 18)
    }

    @MainActor
    private func exportCSV() async {
        isExportingOrRestoring = true
        defer { isExportingOrRestoring = false }

        do {
            let csv = try await viewModel.exportCSVString()
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.commaSeparatedText]
            panel.nameFieldStringValue = "SubRadar-账单明细-\(dateStamp()).csv"
            panel.canCreateDirectories = true
            guard panel.runModal() == .OK, let url = panel.url else { return }
            try Data(csv.utf8).write(to: url, options: .atomic)
            viewModel.showToast("已导出 CSV 账单明细至 \(url.lastPathComponent)")
        } catch {
            let msg = error.userFacingMessage
            viewModel.errorMessage = msg
            viewModel.showToast("导出 CSV 失败：\(msg)")
        }
    }

    @MainActor
    private func exportJSON() async {
        isExportingOrRestoring = true
        defer { isExportingOrRestoring = false }

        do {
            let data = try await viewModel.exportBackupJSONData(includeSecrets: includeSecretsInBackup)
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.json]
            panel.nameFieldStringValue = "SubRadar-全量备份-\(dateStamp()).json"
            panel.canCreateDirectories = true
            guard panel.runModal() == .OK, let url = panel.url else { return }
            try data.write(to: url, options: .atomic)
            viewModel.showToast("已导出 JSON 全量备份至 \(url.lastPathComponent)")
        } catch {
            let msg = error.userFacingMessage
            viewModel.errorMessage = msg
            viewModel.showToast("导出 JSON 失败：\(msg)")
        }
    }

    @MainActor
    private func pickJSONBackupToRestore() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            pendingRestoreData = data
            showRestoreConfirm = true
        } catch {
            let msg = error.userFacingMessage
            viewModel.errorMessage = msg
            viewModel.showToast("读取备份文件失败：\(msg)")
        }
    }

    private func dateStamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: Date())
    }

    var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("关于 SubRadar")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(palette.textPrimary)

            VStack(alignment: .leading, spacing: 8) {
                infoLine(label: "开源协议", value: "GNU General Public License v3.0 (GPL-3.0)")
                infoLine(label: "隐私存储", value: "纯本地 SQLite3 存储，零遥测")
            }
        }
        .customCard(padding: 18)
    }

    private func infoLine(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(palette.textMuted)
                .frame(width: 72, alignment: .leading)
            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(palette.textSecondary)
            Spacer()
        }
    }
}
