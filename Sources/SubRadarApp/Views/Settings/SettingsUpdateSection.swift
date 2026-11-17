import AppKit
import SubRadarCore
import SwiftUI

struct SettingsUpdateSection: View {
    @Environment(\.radarPalette) private var palette
    @Bindable var updateManager: AppUpdateManager
    @Bindable var settings: AppSettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("应用更新")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(palette.textPrimary)
                    Text("当前版本 v\(updateManager.currentVersion)（\(AppUpdateArchitecture.current.rawValue)）")
                        .font(.system(size: 12))
                        .foregroundStyle(palette.textSecondary)
                }
                Spacer()
                RadarButton(
                    isChecking ? "检查中..." : "立即检查更新",
                    systemImage: "arrow.clockwise",
                    variant: .secondary,
                    size: .small
                ) {
                    Task { await updateManager.checkForUpdates(manual: true) }
                }
                .disabled(isChecking || isInstalling)
            }

            RadarDivider()

            toggleRow(
                title: "启动与定时自动检查更新",
                subtitle: "应用启动及菜单栏后台运行时默认每 15 分钟自动检测新版本，发现后静默下载并提醒你重启完成安装"
            ) {
                RadarToggle("", isOn: $settings.autoCheckForUpdates)
            }

            statusView
        }
        .customCard(padding: 18)
    }

    private var isChecking: Bool {
        if case .checking = updateManager.state { return true }
        return false
    }

    private var isInstalling: Bool {
        if case .installing = updateManager.state { return true }
        return false
    }

    @ViewBuilder
    private var statusView: some View {
        switch updateManager.state {
        case .idle:
            if let checkedAt = updateManager.lastCheckedAt {
                Text("上次检查：\(checkedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.system(size: 11.5))
                    .foregroundStyle(palette.textMuted)
            }
        case .checking:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("正在检查 GitHub Release 最新版本...")
                    .font(.system(size: 11.5))
                    .foregroundStyle(palette.textSecondary)
            }
        case .upToDate(let version):
            Text("当前已是最新版本（v\(version)）。")
                .font(.system(size: 11.5))
                .foregroundStyle(SubRadarTheme.emerald)
        case .available(let release):
            HStack(spacing: 10) {
                Text("发现新版本 v\(release.version)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SubRadarTheme.radarAccent)
                Spacer()
                RadarButton("查看详情", systemImage: "arrow.down.circle.fill", variant: .primary, size: .small) {
                    updateManager.showUpdatePrompt = true
                }
            }
        case .installing(_, let stage):
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text(stage)
                    .font(.system(size: 11.5))
                    .foregroundStyle(SubRadarTheme.radarAccent)
            }
        case .readyToRestart(let staged):
            HStack(spacing: 10) {
                Text("新版本 v\(staged.release.version) 已下载就绪，重启后完成更新")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SubRadarTheme.emerald)
                Spacer()
                RadarButton(
                    "立即重启并更新",
                    systemImage: "arrow.triangle.2.circlepath.circle.fill",
                    variant: .primary,
                    size: .small
                ) {
                    updateManager.restartAndInstallReadyUpdate()
                }
            }
        case .failed(let message):
            Text(message)
                .font(.system(size: 11.5))
                .foregroundStyle(SubRadarTheme.coral)
                .textSelection(.enabled)
        }
    }

    private func toggleRow<Control: View>(
        title: String,
        subtitle: String,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(palette.textSecondary)
            }
            Spacer(minLength: 12)
            control()
        }
    }
}

struct AppUpdatePromptSheet: View {
    @Environment(\.radarPalette) private var palette
    @Environment(\.openURL) private var openURL
    @Bindable var updateManager: AppUpdateManager

    private var isReadyToRestart: Bool {
        if case .readyToRestart = updateManager.state { return true }
        return false
    }

    private var isDownloading: Bool {
        if case .installing = updateManager.state { return true }
        return false
    }

    var body: some View {
        let release = updateManager.availableRelease
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: isReadyToRestart ? "checkmark.circle.fill" : "arrow.down.app.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(isReadyToRestart ? SubRadarTheme.emerald : SubRadarTheme.radarAccent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(
                        isReadyToRestart
                            ? "新版本 v\(release?.version ?? "") 已准备就绪"
                            : "发现新版本 v\(release?.version ?? "")"
                    )
                    .font(SubRadarTheme.sheetTitleFont)
                    .foregroundStyle(palette.textPrimary)
                    Text(
                        isReadyToRestart
                            ? "安装包已校验完成，重启 SubRadar 后即可完成自动替换（当前版本 v\(updateManager.currentVersion)）"
                            : "当前版本 v\(updateManager.currentVersion)"
                    )
                    .font(.system(size: 12))
                    .foregroundStyle(palette.textSecondary)
                }
                Spacer()
            }

            RadarDivider()

            if let notes = release?.notes, !notes.isEmpty {
                ScrollView {
                    Text(notes)
                        .font(.system(size: 12))
                        .foregroundStyle(palette.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 160)
                .padding(10)
                .background(palette.inputSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            if case .installing(_, let stage) = updateManager.state {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(stage)
                        .font(.system(size: 12))
                        .foregroundStyle(SubRadarTheme.radarAccent)
                }
            }

            if case .failed(let message) = updateManager.state {
                Text(message)
                    .font(.system(size: 11.5))
                    .foregroundStyle(SubRadarTheme.coral)
                    .textSelection(.enabled)
            }

            HStack(spacing: 8) {
                RadarButton("跳过此版本", variant: .ghost, size: .small) {
                    updateManager.skipCurrentAvailableVersion()
                }
                if let pageURL = release?.releasePageURL {
                    RadarButton("前往发布页", variant: .ghost, size: .small) {
                        openURL(pageURL)
                    }
                }
                Spacer()
                RadarButton(isReadyToRestart ? "稍后重启" : "稍后提醒", variant: .secondary, size: .small) {
                    updateManager.showUpdatePrompt = false
                }
                if isReadyToRestart {
                    RadarButton(
                        "立即重启并更新",
                        systemImage: "arrow.triangle.2.circlepath.circle.fill",
                        variant: .primary,
                        size: .small
                    ) {
                        updateManager.restartAndInstallReadyUpdate()
                    }
                } else {
                    RadarButton(
                        isDownloading ? "正在准备..." : "立即下载更新",
                        systemImage: "arrow.down.circle.fill",
                        variant: .primary,
                        size: .small
                    ) {
                        Task { await updateManager.installAvailableUpdate() }
                    }
                    .disabled(isDownloading)
                }
            }
        }
        .padding(20)
        .frame(width: 460)
        .background(palette.windowBackground)
    }
}
