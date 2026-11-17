import Foundation

extension PopularSoftwarePresetManager {
    static let cloudAndInfraPresets: [PopularSoftwarePreset] = [
        // MARK: - 网盘与存储
        PopularSoftwarePreset(
            id: "icloud-plus",
            name: "iCloud+",
            aliases: ["icloud", "icloud+", "apple", "苹果云"],
            group: .cloudStorage,
            monogram: "iC+",
            accentHex: "#007AFF",
            symbolName: "icloud.fill",
            websiteDomain: "icloud.com",
            suggestedCategoryId: SubscriptionCategory.BuiltinID.cloudStorage,
            suggestedTemplateId: TemplateDefinition.BuiltinID.streaming,
            defaultBillingCycle: .monthly,
            defaultPrice: "21",
            defaultCurrency: "CNY",
            presetFieldValues: [
                "manage_url": "https://www.icloud.com"
            ]
        ),
        PopularSoftwarePreset(
            id: "oppo-cloud",
            name: "OPPO 云空间",
            aliases: ["oppo", "oppocloud", "oppo云", "oppo云空间", "欢太云", "网盘"],
            group: .cloudStorage,
            monogram: "OPPO",
            accentHex: "#059669",
            symbolName: "icloud.fill",
            websiteDomain: "cloud.oppo.com",
            suggestedCategoryId: SubscriptionCategory.BuiltinID.cloudStorage,
            suggestedTemplateId: TemplateDefinition.BuiltinID.streaming,
            defaultBillingCycle: .monthly,
            defaultPrice: "6",
            defaultCurrency: "CNY",
            presetFieldValues: [
                "manage_url": "https://cloud.oppo.com"
            ]
        ),
        PopularSoftwarePreset(
            id: "aliyun-drive",
            name: "阿里云盘",
            aliases: ["aliyun", "alipan", "阿里云盘", "网盘"],
            group: .cloudStorage,
            monogram: "阿盘",
            accentHex: "#6172F3",
            symbolName: "icloud.fill",
            websiteDomain: "alipan.com",
            suggestedCategoryId: SubscriptionCategory.BuiltinID.cloudStorage,
            suggestedTemplateId: TemplateDefinition.BuiltinID.streaming,
            defaultBillingCycle: .annually,
            defaultPrice: "218",
            defaultCurrency: "CNY",
            presetFieldValues: [
                "manage_url": "https://www.alipan.com"
            ]
        ),
        PopularSoftwarePreset(
            id: "baidu-netdisk",
            name: "百度网盘",
            aliases: ["baidu", "pan", "百度网盘", "svip", "网盘"],
            group: .cloudStorage,
            monogram: "百盘",
            accentHex: "#06A7FF",
            symbolName: "externaldrive.fill.badge.icloud",
            websiteDomain: "pan.baidu.com",
            suggestedCategoryId: SubscriptionCategory.BuiltinID.cloudStorage,
            suggestedTemplateId: TemplateDefinition.BuiltinID.streaming,
            defaultBillingCycle: .annually,
            defaultPrice: "263",
            defaultCurrency: "CNY",
            presetFieldValues: [
                "manage_url": "https://pan.baidu.com/buy/center"
            ]
        ),
        PopularSoftwarePreset(
            id: "quark-drive",
            name: "夸克网盘",
            aliases: ["quark", "夸克", "网盘"],
            group: .cloudStorage,
            monogram: "夸克",
            accentHex: "#2E6BE6",
            symbolName: "cloud.fill",
            websiteDomain: "pan.quark.cn",
            suggestedCategoryId: SubscriptionCategory.BuiltinID.cloudStorage,
            suggestedTemplateId: TemplateDefinition.BuiltinID.streaming,
            defaultBillingCycle: .annually,
            defaultPrice: "158",
            defaultCurrency: "CNY",
            presetFieldValues: [
                "manage_url": "https://pan.quark.cn"
            ]
        ),

        // MARK: - 主机与域名
        PopularSoftwarePreset(
            id: "cloudflare",
            name: "Cloudflare",
            aliases: ["cloudflare", "cf", "dns", "域名"],
            group: .infrastructure,
            monogram: "CF",
            accentHex: "#F38020",
            symbolName: "globe",
            websiteDomain: "cloudflare.com",
            suggestedCategoryId: SubscriptionCategory.BuiltinID.domainNetwork,
            suggestedTemplateId: TemplateDefinition.BuiltinID.domain,
            defaultBillingCycle: .annually,
            defaultPrice: "10.44",
            defaultCurrency: "USD",
            presetFieldValues: [
                "registrar": "Cloudflare",
                "manage_url": "https://dash.cloudflare.com"
            ]
        ),
        PopularSoftwarePreset(
            id: "dedirock",
            name: "DediRock",
            aliases: ["dedirock", "dedi", "vps", "server", "主机"],
            group: .infrastructure,
            monogram: "DR",
            accentHex: "#F97316",
            symbolName: "server.rack",
            websiteDomain: "dedirock.com",
            suggestedCategoryId: SubscriptionCategory.BuiltinID.cloudInfra,
            suggestedTemplateId: TemplateDefinition.BuiltinID.vps,
            defaultBillingCycle: .annually,
            defaultPrice: "15",
            defaultCurrency: "USD",
            presetFieldValues: [
                "panel_url": "https://billing.dedirock.com"
            ]
        ),
        PopularSoftwarePreset(
            id: "namecheap",
            name: "Namecheap",
            aliases: ["namecheap", "domain", "域名"],
            group: .infrastructure,
            monogram: "NC",
            accentHex: "#DE3723",
            symbolName: "network",
            websiteDomain: "namecheap.com",
            suggestedCategoryId: SubscriptionCategory.BuiltinID.domainNetwork,
            suggestedTemplateId: TemplateDefinition.BuiltinID.domain,
            defaultBillingCycle: .annually,
            defaultPrice: "13.98",
            defaultCurrency: "USD",
            presetFieldValues: [
                "registrar": "Namecheap",
                "manage_url": "https://ap.www.namecheap.com"
            ]
        ),
        PopularSoftwarePreset(
            id: "spaceship",
            name: "Spaceship",
            aliases: ["spaceship", "domain", "dns", "域名"],
            group: .infrastructure,
            monogram: "SS",
            accentHex: "#6D28D9",
            symbolName: "globe",
            websiteDomain: "spaceship.com",
            suggestedCategoryId: SubscriptionCategory.BuiltinID.domainNetwork,
            suggestedTemplateId: TemplateDefinition.BuiltinID.domain,
            defaultBillingCycle: .annually,
            defaultPrice: "9.88",
            defaultCurrency: "USD",
            presetFieldValues: [
                "registrar": "Spaceship",
                "manage_url": "https://www.spaceship.com"
            ]
        ),
        PopularSoftwarePreset(
            id: "xiaotu-cloud",
            name: "小兔互联",
            aliases: ["xiaotu", "moebun", "小兔", "小兔互联", "vps", "主机"],
            group: .infrastructure,
            monogram: "小兔",
            accentHex: "#E11D48",
            symbolName: "server.rack",
            websiteDomain: "moebun.com",
            suggestedCategoryId: SubscriptionCategory.BuiltinID.cloudInfra,
            suggestedTemplateId: TemplateDefinition.BuiltinID.vps,
            defaultBillingCycle: .monthly,
            defaultPrice: "29",
            defaultCurrency: "CNY",
            presetFieldValues: [
                "panel_url": "https://www.moebun.com"
            ]
        ),
        PopularSoftwarePreset(
            id: "yecaoyun",
            name: "野草云",
            aliases: ["yecaoyun", "yecao", "野草云", "香港vps", "vps", "主机"],
            group: .infrastructure,
            monogram: "野草",
            accentHex: "#059669",
            symbolName: "server.rack",
            websiteDomain: "yecaoyun.com",
            suggestedCategoryId: SubscriptionCategory.BuiltinID.cloudInfra,
            suggestedTemplateId: TemplateDefinition.BuiltinID.vps,
            defaultBillingCycle: .annually,
            defaultPrice: "88",
            defaultCurrency: "CNY",
            presetFieldValues: [
                "panel_url": "https://my.yecaoyun.com"
            ]
        )
    ]
}
