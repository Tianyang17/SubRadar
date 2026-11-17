import Foundation
import Testing

@testable import SubRadarCore

@Suite("回归测试：预设切换清空与菜单栏设置持久化")
struct WorkflowRegressionTests {
    @Test("选择 Netflix 预设后切换模板或导入其他应用时清空旧预设字段，但保留用户手填值")
    @MainActor
    func testSwitchAwayFromNetflixClearsAutoFilledURL() async {
        let container = AppContainer.makeMock()
        let vm = EditorViewModel(
            container: container,
            templates: TemplatePresetManager.builtinTemplates,
            categories: CategoryPresetManager.builtinCategories
        )

        let netflix = PopularSoftwarePresetManager.allPresets.first { $0.id == "netflix" }!
        vm.applySoftwarePreset(netflix)
        #expect(vm.customFields.first(where: { $0.key == "manage_url" })?.value == "https://www.netflix.com/account")

        // 切换到域名资产模板，Netflix 的官网地址不应残留
        vm.applyInfrastructureKindChoice(isHost: false)
        #expect(vm.customFields.first(where: { $0.key == "manage_url" })?.value.isEmpty == true)

        // 用户手工输入 URL 后，从域名切回 VPS 应保留手填值
        if let idx = vm.customFields.firstIndex(where: { $0.key == "manage_url" }) {
            vm.customFields[idx].value = "https://custom-host.example.com"
        }
        vm.applyInfrastructureKindChoice(isHost: true)
        #expect(vm.customFields.first(where: { $0.key == "panel_url" })?.value == "https://custom-host.example.com")

        // 重新应用 Netflix 再通过本地/AppStore 选择器替换时应清空 Netflix 的 URL
        vm.applySoftwarePreset(netflix)
        await vm.selectAppStoreItem(
            AppStoreSearchItem(
                trackId: 1001,
                trackName: "Notion",
                artworkUrl100: nil,
                artworkUrl512: nil,
                artistName: "Notion Labs",
                bundleId: "notion.id"
            )
        )
        #expect(vm.name == "Notion")
        #expect(vm.customFields.first(where: { $0.key == "manage_url" })?.value.isEmpty == true)
    }

    @Test("菜单栏常驻偏好持久化且通知文案无 osascript 字样")
    @MainActor
    func testRuntimeDefaultsAndNotificationSanitization() async {
        let suiteName = "subradar.workflow.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = AppSettingsStore(userDefaults: defaults)
        #expect(store.keepRunningInMenuBar == true)
        #expect(store.hideDockWhenWindowClosed == false)

        store.keepRunningInMenuBar = false
        store.hideDockWhenWindowClosed = true

        let reloaded = AppSettingsStore(userDefaults: defaults)
        #expect(reloaded.keepRunningInMenuBar == false)
        #expect(reloaded.hideDockWhenWindowClosed == true)

        let mainVM = MainViewModel(container: AppContainer.makeMock(), settings: reloaded)
        let report = await mainVM.sendTestNotification()
        #expect(!report.channel.localizedCaseInsensitiveContains("osascript"))
        #expect(!report.detail.localizedCaseInsensitiveContains("osascript"))
        mainVM.clearToast()
        #expect(mainVM.toastMessage == nil)
    }

    @Test("Phase 27: SubRadarFormatter.normalizedWebURL 自动补全协议并拦截危险或非法地址")
    func testNormalizedWebURLValidationAndSchemeSafety() {
        #expect(
            SubRadarFormatter.normalizedWebURL(from: " https://pan.baidu.com/buy/center ")?.absoluteString
                == "https://pan.baidu.com/buy/center"
        )
        #expect(
            SubRadarFormatter.normalizedWebURL(from: "pan.baidu.com/buy/center")?.absoluteString
                == "https://pan.baidu.com/buy/center"
        )
        #expect(
            SubRadarFormatter.normalizedWebURL(from: "http://localhost:8080/panel")?.absoluteString
                == "http://localhost:8080/panel"
        )

        #expect(SubRadarFormatter.normalizedWebURL(from: "") == nil)
        #expect(SubRadarFormatter.normalizedWebURL(from: "   ") == nil)
        #expect(SubRadarFormatter.normalizedWebURL(from: "ftp://files.example.com") == nil)
        #expect(SubRadarFormatter.normalizedWebURL(from: "javascript:alert(1)") == nil)
        #expect(SubRadarFormatter.normalizedWebURL(from: "file:///etc/passwd") == nil)
        #expect(SubRadarFormatter.normalizedWebURL(from: "只是普通文本") == nil)
    }
}
