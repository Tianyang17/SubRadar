import Foundation

extension PopularSoftwarePresetManager {
    static let mediaPresets: [PopularSoftwarePreset] = [
        // MARK: - 影音娱乐
        PopularSoftwarePreset(
            id: "netflix",
            name: "Netflix",
            aliases: ["netflix", "奈飞", "流媒体"],
            group: .entertainment,
            monogram: "NFLX",
            accentHex: "#E50914",
            symbolName: "tv.fill",
            websiteDomain: "netflix.com",
            suggestedCategoryId: SubscriptionCategory.BuiltinID.streaming,
            suggestedTemplateId: TemplateDefinition.BuiltinID.streaming,
            defaultBillingCycle: .monthly,
            defaultPrice: "15.49",
            defaultCurrency: "USD",
            presetFieldValues: [
                "manage_url": "https://www.netflix.com/account"
            ]
        ),
        PopularSoftwarePreset(
            id: "qq-music",
            name: "QQ音乐",
            aliases: ["qqmusic", "qq", "音乐", "绿钻", "qq音乐 豪华绿钻"],
            group: .entertainment,
            monogram: "QQM",
            accentHex: "#20B46A",
            symbolName: "music.note",
            websiteDomain: "y.qq.com",
            suggestedCategoryId: SubscriptionCategory.BuiltinID.streaming,
            suggestedTemplateId: TemplateDefinition.BuiltinID.streaming,
            defaultBillingCycle: .monthly,
            defaultPrice: "15",
            defaultCurrency: "CNY",
            presetFieldValues: [
                "manage_url": "https://y.qq.com"
            ]
        ),
        PopularSoftwarePreset(
            id: "spotify",
            name: "Spotify",
            aliases: ["spotify", "spotify premium", "music", "音乐"],
            group: .entertainment,
            monogram: "SPF",
            accentHex: "#1DB954",
            symbolName: "music.note.list",
            websiteDomain: "spotify.com",
            suggestedCategoryId: SubscriptionCategory.BuiltinID.streaming,
            suggestedTemplateId: TemplateDefinition.BuiltinID.streaming,
            defaultBillingCycle: .monthly,
            defaultPrice: "11.99",
            defaultCurrency: "USD",
            presetFieldValues: [
                "manage_url": "https://www.spotify.com/account"
            ]
        ),
        PopularSoftwarePreset(
            id: "youtube-premium",
            name: "YouTube",
            aliases: ["youtube", "youtube premium", "ytb", "油管"],
            group: .entertainment,
            monogram: "YTB",
            accentHex: "#FF0000",
            symbolName: "play.rectangle.fill",
            websiteDomain: "youtube.com",
            suggestedCategoryId: SubscriptionCategory.BuiltinID.streaming,
            suggestedTemplateId: TemplateDefinition.BuiltinID.streaming,
            defaultBillingCycle: .monthly,
            defaultPrice: "13.99",
            defaultCurrency: "USD",
            presetFieldValues: [
                "manage_url": "https://www.youtube.com/paid_memberships"
            ]
        ),
        PopularSoftwarePreset(
            id: "iqiyi-vip",
            name: "爱奇艺",
            aliases: ["iqiyi", "爱奇艺", "爱奇艺黄金会员", "视频"],
            group: .entertainment,
            monogram: "奇艺",
            accentHex: "#00BE06",
            symbolName: "film.fill",
            websiteDomain: "iqiyi.com",
            suggestedCategoryId: SubscriptionCategory.BuiltinID.streaming,
            suggestedTemplateId: TemplateDefinition.BuiltinID.streaming,
            defaultBillingCycle: .monthly,
            defaultPrice: "25",
            defaultCurrency: "CNY",
            presetFieldValues: [
                "manage_url": "https://vip.iqiyi.com"
            ]
        ),
        PopularSoftwarePreset(
            id: "bilibili-vip",
            name: "哔哩哔哩",
            aliases: ["bilibili", "b站", "大会员", "bili"],
            group: .entertainment,
            monogram: "B站",
            accentHex: "#FB7299",
            symbolName: "play.tv.fill",
            websiteDomain: "bilibili.com",
            suggestedCategoryId: SubscriptionCategory.BuiltinID.streaming,
            suggestedTemplateId: TemplateDefinition.BuiltinID.streaming,
            defaultBillingCycle: .annually,
            defaultPrice: "148",
            defaultCurrency: "CNY",
            presetFieldValues: [
                "manage_url": "https://account.bilibili.com/big"
            ]
        ),
        PopularSoftwarePreset(
            id: "mango-tv",
            name: "芒果TV",
            aliases: ["mango", "mangotv", "mgtv", "芒果", "芒果tv", "视频"],
            group: .entertainment,
            monogram: "芒果",
            accentHex: "#FF5F00",
            symbolName: "play.square.fill",
            websiteDomain: "mgtv.com",
            suggestedCategoryId: SubscriptionCategory.BuiltinID.streaming,
            suggestedTemplateId: TemplateDefinition.BuiltinID.streaming,
            defaultBillingCycle: .monthly,
            defaultPrice: "25",
            defaultCurrency: "CNY",
            presetFieldValues: [
                "manage_url": "https://www.mgtv.com"
            ]
        ),
        PopularSoftwarePreset(
            id: "netease-music",
            name: "网易云音乐",
            aliases: ["netease", "cloudmusic", "网易云", "黑胶"],
            group: .entertainment,
            monogram: "云音",
            accentHex: "#E60026",
            symbolName: "headphones",
            websiteDomain: "music.163.com",
            suggestedCategoryId: SubscriptionCategory.BuiltinID.streaming,
            suggestedTemplateId: TemplateDefinition.BuiltinID.streaming,
            defaultBillingCycle: .monthly,
            defaultPrice: "15",
            defaultCurrency: "CNY",
            presetFieldValues: [
                "manage_url": "https://music.163.com"
            ]
        ),
        PopularSoftwarePreset(
            id: "youku",
            name: "优酷",
            aliases: ["youku", "yk", "优酷", "优酷vip", "酷喵", "视频"],
            group: .entertainment,
            monogram: "优酷",
            accentHex: "#00A2FF",
            symbolName: "play.tv.fill",
            websiteDomain: "youku.com",
            suggestedCategoryId: SubscriptionCategory.BuiltinID.streaming,
            suggestedTemplateId: TemplateDefinition.BuiltinID.streaming,
            defaultBillingCycle: .monthly,
            defaultPrice: "25",
            defaultCurrency: "CNY",
            presetFieldValues: [
                "manage_url": "https://vip.youku.com"
            ]
        )
    ]
}
