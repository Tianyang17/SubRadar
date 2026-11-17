import Foundation

extension PopularSoftwarePresetManager {
    static let productivityPresets: [PopularSoftwarePreset] = [
        // MARK: - 效率与办公
        PopularSoftwarePreset(
            id: "1password",
            name: "1Password",
            aliases: ["1password", "password", "密码"],
            group: .productivity,
            monogram: "1PW",
            accentHex: "#1A8CFF",
            symbolName: "key.fill",
            websiteDomain: "1password.com",
            suggestedCategoryId: SubscriptionCategory.BuiltinID.productivity,
            suggestedTemplateId: TemplateDefinition.BuiltinID.softwareLicense,
            defaultBillingCycle: .annually,
            defaultPrice: "35.88",
            defaultCurrency: "USD",
            presetFieldValues: [
                "download_url": "https://1password.com/account"
            ]
        ),
        PopularSoftwarePreset(
            id: "figma-pro",
            name: "Figma",
            aliases: ["figma", "figma professional", "design", "设计"],
            group: .productivity,
            monogram: "FIG",
            accentHex: "#A259FF",
            symbolName: "paintpalette.fill",
            websiteDomain: "figma.com",
            suggestedCategoryId: SubscriptionCategory.BuiltinID.productivity,
            suggestedTemplateId: TemplateDefinition.BuiltinID.softwareLicense,
            defaultBillingCycle: .monthly,
            defaultPrice: "15",
            defaultCurrency: "USD",
            presetFieldValues: [
                "download_url": "https://www.figma.com/settings"
            ]
        ),
        PopularSoftwarePreset(
            id: "microsoft-365",
            name: "Microsoft 365",
            aliases: ["office", "office 365", "o365", "microsoft", "microsoft 365", "word", "excel", "ppt"],
            group: .productivity,
            monogram: "M365",
            accentHex: "#6366F1",
            symbolName: "doc.on.doc.fill",
            websiteDomain: "microsoft365.com",
            suggestedCategoryId: SubscriptionCategory.BuiltinID.productivity,
            suggestedTemplateId: TemplateDefinition.BuiltinID.softwareLicense,
            defaultBillingCycle: .annually,
            defaultPrice: "398",
            defaultCurrency: "CNY",
            presetFieldValues: [
                "download_url": "https://account.microsoft.com/services"
            ]
        ),
        PopularSoftwarePreset(
            id: "notion-plus",
            name: "Notion",
            aliases: ["notion", "notion plus", "笔记", "知识库"],
            group: .productivity,
            monogram: "NOT",
            accentHex: "#37352F",
            symbolName: "doc.text.fill",
            websiteDomain: "notion.so",
            suggestedCategoryId: SubscriptionCategory.BuiltinID.productivity,
            suggestedTemplateId: TemplateDefinition.BuiltinID.streaming,
            defaultBillingCycle: .monthly,
            defaultPrice: "10",
            defaultCurrency: "USD",
            presetFieldValues: [
                "manage_url": "https://www.notion.so/my-account"
            ]
        ),
        PopularSoftwarePreset(
            id: "raycast-pro",
            name: "Raycast",
            aliases: ["raycast", "raycast pro", "launcher", "mac"],
            group: .productivity,
            monogram: "RAY",
            accentHex: "#FF6363",
            symbolName: "command",
            websiteDomain: "raycast.com",
            suggestedCategoryId: SubscriptionCategory.BuiltinID.productivity,
            suggestedTemplateId: TemplateDefinition.BuiltinID.softwareLicense,
            defaultBillingCycle: .monthly,
            defaultPrice: "8",
            defaultCurrency: "USD",
            presetFieldValues: [
                "download_url": "https://raycast.com/pricing"
            ]
        ),
        PopularSoftwarePreset(
            id: "wps-svip",
            name: "WPS",
            aliases: ["wps", "wps 超级会员", "office", "金山", "文档"],
            group: .productivity,
            monogram: "WPS",
            accentHex: "#E14938",
            symbolName: "doc.richtext.fill",
            websiteDomain: "wps.cn",
            suggestedCategoryId: SubscriptionCategory.BuiltinID.productivity,
            suggestedTemplateId: TemplateDefinition.BuiltinID.softwareLicense,
            defaultBillingCycle: .annually,
            defaultPrice: "148",
            defaultCurrency: "CNY",
            presetFieldValues: [
                "download_url": "https://vip.wps.cn"
            ]
        )
    ]
}
