import AppKit
import SubRadarCore
import SwiftUI

struct SettingsRuntimeSection: View {
    @Environment(\.radarPalette) private var palette
    @Bindable var settings: AppSettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("菜单栏与窗口常驻")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(palette.textPrimary)

            settingRow(
                title: "关闭主窗口后保持菜单栏常驻",
                subtitle: "关闭主界面窗口时不退出应用，可通过顶部菜单栏快速查看临期订阅与记一笔"
            ) {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { settings.keepRunningInMenuBar },
                        set: { newValue in
                            settings.keepRunningInMenuBar = newValue
                            if !newValue {
                                settings.hideDockWhenWindowClosed = false
                                NSApplication.shared.setActivationPolicy(.regular)
                            }
                        }
                    )
                )
                .labelsHidden()
                .toggleStyle(.switch)
            }

            RadarDivider()

            settingRow(
                title: "主窗口关闭时隐藏程序坞（Dock）图标",
                subtitle: "开启后，关闭主窗口仅在菜单栏运行，重新打开主窗口时自动恢复程序坞图标"
            ) {
                Toggle("", isOn: $settings.hideDockWhenWindowClosed)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .disabled(!settings.keepRunningInMenuBar)
            }
        }
        .customCard(padding: 18)
    }

    private func settingRow<Control: View>(
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
