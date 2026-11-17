import AppKit
import SubRadarCore
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.radarPalette) var palette
    @Bindable var viewModel: MainViewModel
    var updateManager: AppUpdateManager? = nil

    @State var includeSecretsInBackup = false
    @State var pendingRestoreData: Data?
    @State var showRestoreConfirm = false
    @State var isExportingOrRestoring = false
    @State var notificationTestReport: NotificationDeliveryReport?
    @State var isTestingNotification = false

    private let reminderDayOptions = SubscriptionItem.reminderDayOptions

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                RadarPageHeader("应用设置", subtitle: "自定义外观主题、统计基准币种、菜单栏常驻、备份导出与运行日志")
                appearanceSection
                billingPreferenceSection
                SettingsRuntimeSection(settings: viewModel.settings)
                backupAndExportSection
                SettingsLoggingSection { msg in
                    viewModel.errorMessage = msg
                    viewModel.showToast(msg)
                }
                if let updateManager {
                    SettingsUpdateSection(updateManager: updateManager, settings: viewModel.settings)
                }
                aboutSection
            }
            .padding(24)
            .frame(maxWidth: 880, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(palette.windowBackground)
        .sheet(isPresented: $showRestoreConfirm) {
            RadarConfirmSheet(
                title: "确认从 JSON 备份恢复数据？",
                message: "将把备份文件中的分类、模版、订阅条目及历史账单流水合并写入当前本地数据库（同 ID 记录会以备份为准覆盖）。建议恢复前先导出一份当前备份。",
                confirmTitle: "确认恢复",
                cancelTitle: "取消",
                isDestructive: false
            ) {
                guard let data = pendingRestoreData else { return }
                pendingRestoreData = nil
                Task {
                    isExportingOrRestoring = true
                    defer { isExportingOrRestoring = false }
                    do {
                        try await viewModel.restoreBackup(from: data)
                    } catch {
                        let msg = error.userFacingMessage
                        viewModel.errorMessage = msg
                        viewModel.showToast("恢复备份失败：\(msg)")
                    }
                }
            }
            .radarTheme(viewModel.settings.themeMode)
        }
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("外观主题")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)
                Text("支持暗黑黑曜石、极简浅色与跟随 macOS 系统外观")
                    .font(.system(size: 12))
                    .foregroundStyle(palette.textSecondary)
            }

            HStack(spacing: 12) {
                ForEach(ThemeMode.allCases) { mode in
                    themeOptionCard(mode: mode)
                }
            }
        }
        .customCard(padding: 18)
    }

    private func themeOptionCard(mode: ThemeMode) -> some View {
        let isSelected = viewModel.settings.themeMode == mode

        return Button {
            withAnimation(.snappy(duration: 0.22)) {
                viewModel.settings.themeMode = mode
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                themePreviewThumbnail(for: mode)

                HStack(spacing: 6) {
                    Image(systemName: mode.iconSymbol)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isSelected ? SubRadarTheme.radarAccent : palette.textSecondary)

                    Text(mode.displayName)
                        .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                        .foregroundStyle(palette.textPrimary)

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(SubRadarTheme.radarAccent)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected
                    ? SubRadarTheme.radarAccent.opacity(palette.isDark ? 0.14 : 0.08)
                    : palette.inputSurface
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isSelected ? SubRadarTheme.radarAccent : palette.borderSubtle,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func themePreviewThumbnail(for mode: ThemeMode) -> some View {
        switch mode {
        case .light:
            previewShell(targetPalette: .light, accent: SubRadarTheme.radarAccent)
        case .dark:
            previewShell(targetPalette: .dark, accent: SubRadarTheme.radarCyan)
        case .system:
            HStack(spacing: 0) {
                previewShell(targetPalette: .light, accent: SubRadarTheme.radarAccent)
                previewShell(targetPalette: .dark, accent: SubRadarTheme.radarCyan)
            }
            .frame(height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private func previewShell(targetPalette: SubRadarPalette, accent: Color) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(targetPalette.sidebarBackground)
                .frame(width: 24)
                .overlay(alignment: .top) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(accent)
                        .frame(width: 14, height: 5)
                        .padding(.top, 8)
                }

            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(targetPalette.cardSurface)
                    .frame(height: 22)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(targetPalette.elevatedSurface)
                    .frame(height: 16)
            }
        }
        .padding(6)
        .frame(height: 56)
        .frame(maxWidth: .infinity)
        .background(targetPalette.windowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var billingPreferenceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("账单与提醒偏好")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(palette.textPrimary)

            settingRow(
                title: "统计基准币种",
                subtitle: "费用统计大盘与历史流水汇总将按汇率统一折算为此币种"
            ) {
                RadarSelectMenu(
                    options: CommonCurrency.allCases.map(\.rawValue),
                    selection: Binding(
                        get: { viewModel.baseCurrency },
                        set: { newCurrency in
                            Task {
                                await viewModel.updateBaseCurrency(newCurrency)
                            }
                        }
                    ),
                    label: { $0 }
                )
            }

            RadarDivider()

            settingRow(
                title: "默认提前提醒天数",
                subtitle: "新建订阅卡片时默认预填的到期提醒提前量"
            ) {
                RadarSelectMenu(
                    options: reminderDayOptions,
                    selection: Binding(
                        get: { viewModel.settings.defaultReminderDays },
                        set: { viewModel.settings.defaultReminderDays = $0 }
                    ),
                    label: { SubscriptionItem.reminderOptionLabel($0) }
                )
            }

            RadarDivider()

            settingRow(
                title: "系统通知连通性测试",
                subtitle: "向 macOS 通知中心立即发送一条测试通知，确认到期提醒与低余额告警权限正常"
            ) {
                RadarButton(
                    isTestingNotification ? "发送中..." : "发送测试通知",
                    systemImage: "bell.badge",
                    variant: .secondary,
                    size: .small
                ) {
                    Task {
                        isTestingNotification = true
                        defer { isTestingNotification = false }
                        notificationTestReport = await viewModel.sendTestNotification()
                    }
                }
                .disabled(isTestingNotification)
            }

            if let report = notificationTestReport {
                HStack(spacing: 6) {
                    Image(systemName: report.delivered ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                    Text(report.detail)
                        .font(.system(size: 11.5))
                }
                .foregroundStyle(report.delivered ? SubRadarTheme.emerald : SubRadarTheme.coral)
            }
        }
        .customCard(padding: 18)
    }

    func settingRow<Control: View>(
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
