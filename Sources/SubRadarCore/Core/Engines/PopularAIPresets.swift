import Foundation

extension PopularSoftwarePresetManager {
    static let aiAndApiPresets: [PopularSoftwarePreset] = [
        // MARK: - AI 与编程
        PopularSoftwarePreset(
            id: "chatgpt-plus",
            name: "ChatGPT",
            aliases: ["openai", "gpt", "gpt4", "chatgpt", "chatgpt plus", "ai"],
            group: .aiTools,
            monogram: "GPT",
            accentHex: "#10A37F",
            symbolName: "sparkles",
            websiteDomain: "chatgpt.com",
            suggestedCategoryId: SubscriptionCategory.BuiltinID.aiTools,
            suggestedTemplateId: TemplateDefinition.BuiltinID.aiMembership,
            defaultBillingCycle: .monthly,
            defaultPrice: "20",
            defaultCurrency: "USD",
            presetFieldValues: [
                "manage_url": "https://chatgpt.com/#settings/Subscription"
            ]
        ),
        PopularSoftwarePreset(
            id: "claude-pro",
            name: "Claude",
            aliases: ["anthropic", "claude", "claude pro", "claude code", "ai"],
            group: .aiTools,
            monogram: "CLD",
            accentHex: "#D97757",
            symbolName: "sparkles",
            websiteDomain: "claude.ai",
            suggestedCategoryId: SubscriptionCategory.BuiltinID.aiTools,
            suggestedTemplateId: TemplateDefinition.BuiltinID.aiMembership,
            defaultBillingCycle: .monthly,
            defaultPrice: "20",
            defaultCurrency: "USD",
            presetFieldValues: [
                "manage_url": "https://claude.ai/settings/usage"
            ]
        ),
        PopularSoftwarePreset(
            id: "cursor-pro",
            name: "Cursor",
            aliases: ["cursor", "cursor pro", "ide", "ai", "coding"],
            group: .aiTools,
            monogram: "CSR",
            accentHex: "#2F3542",
            symbolName: "terminal.fill",
            websiteDomain: "cursor.com",
            suggestedCategoryId: SubscriptionCategory.BuiltinID.aiTools,
            suggestedTemplateId: TemplateDefinition.BuiltinID.aiMembership,
            defaultBillingCycle: .monthly,
            defaultPrice: "20",
            defaultCurrency: "USD",
            presetFieldValues: [
                "manage_url": "https://www.cursor.com/dashboard"
            ]
        ),
        PopularSoftwarePreset(
            id: "gemini-advanced",
            name: "Gemini",
            aliases: ["google", "gemini", "gemini advanced", "google one", "ai"],
            group: .aiTools,
            monogram: "GEM",
            accentHex: "#4E7CF5",
            symbolName: "sparkles",
            websiteDomain: "gemini.google.com",
            suggestedCategoryId: SubscriptionCategory.BuiltinID.aiTools,
            suggestedTemplateId: TemplateDefinition.BuiltinID.aiMembership,
            defaultBillingCycle: .monthly,
            defaultPrice: "19.99",
            defaultCurrency: "USD",
            presetFieldValues: [
                "manage_url": "https://one.google.com/settings"
            ]
        ),
        PopularSoftwarePreset(
            id: "github-copilot",
            name: "GitHub Copilot",
            aliases: ["copilot", "github", "ai", "coding"],
            group: .aiTools,
            monogram: "CPL",
            accentHex: "#6E56CF",
            symbolName: "chevron.left.forwardslash.chevron.right",
            websiteDomain: "github.com",
            suggestedCategoryId: SubscriptionCategory.BuiltinID.aiTools,
            suggestedTemplateId: TemplateDefinition.BuiltinID.aiMembership,
            defaultBillingCycle: .monthly,
            defaultPrice: "10",
            defaultCurrency: "USD",
            presetFieldValues: [
                "manage_url": "https://github.com/settings/copilot"
            ]
        ),
        PopularSoftwarePreset(
            id: "jetbrains",
            name: "JetBrains",
            aliases: [
                "jetbrains", "idea", "intellij", "pycharm", "webstorm", "goland", "clion", "rider", "datagrip",
                "ide", "coding", "ai"
            ],
            group: .aiTools,
            monogram: "JB",
            accentHex: "#FF318C",
            symbolName: "chevron.left.forwardslash.chevron.right",
            websiteDomain: "jetbrains.com",
            suggestedCategoryId: SubscriptionCategory.BuiltinID.aiTools,
            suggestedTemplateId: TemplateDefinition.BuiltinID.aiMembership,
            defaultBillingCycle: .annually,
            defaultPrice: "",
            defaultCurrency: "USD",
            presetFieldValues: [
                "manage_url": "https://account.jetbrains.com"
            ]
        ),

        // MARK: - AI API 余额监控
        PopularSoftwarePreset(
            id: "deepseek",
            name: "DeepSeek",
            aliases: ["deepseek", "深度求索", "api", "balance"],
            group: .aiApiBalance,
            monogram: "DS",
            accentHex: "#4D6BFE",
            symbolName: "gauge.with.dots.needle.33percent",
            websiteDomain: "platform.deepseek.com",
            suggestedCategoryId: SubscriptionCategory.BuiltinID.aiTools,
            suggestedTemplateId: TemplateDefinition.BuiltinID.apiBalance,
            defaultBillingCycle: .oneTime,
            defaultPrice: "50",
            defaultCurrency: "CNY",
            presetFieldValues: [
                "provider_preset": "deepseek",
                "api_endpoint": "https://api.deepseek.com/user/balance",
                "parse_rule": "balance_infos[0].total_balance",
                "low_balance_threshold": "10",
                "console_url": "https://platform.deepseek.com"
            ]
        ),
        PopularSoftwarePreset(
            id: "new-api",
            name: "New API",
            aliases: ["newapi", "new-api", "oneapi", "one-api", "中转", "api"],
            group: .aiApiBalance,
            monogram: "NAPI",
            accentHex: "#0EA5E9",
            symbolName: "hexagon.fill",
            websiteDomain: "github.com/Calcium-Ion/new-api",
            suggestedCategoryId: SubscriptionCategory.BuiltinID.aiTools,
            suggestedTemplateId: TemplateDefinition.BuiltinID.apiBalance,
            defaultBillingCycle: .oneTime,
            defaultPrice: "20",
            defaultCurrency: "USD",
            presetFieldValues: [
                "provider_preset": "new_api",
                "api_endpoint": "https://your-newapi.example.com/api/user/self",
                "parse_rule": "data.quota / 500000",
                "low_balance_threshold": "10"
            ]
        ),
        PopularSoftwarePreset(
            id: "openrouter",
            name: "OpenRouter",
            aliases: ["openrouter", "or", "credits", "api"],
            group: .aiApiBalance,
            monogram: "OR",
            accentHex: "#0F172A",
            symbolName: "arrow.triangle.branch",
            websiteDomain: "openrouter.ai",
            suggestedCategoryId: SubscriptionCategory.BuiltinID.aiTools,
            suggestedTemplateId: TemplateDefinition.BuiltinID.apiBalance,
            defaultBillingCycle: .oneTime,
            defaultPrice: "20",
            defaultCurrency: "USD",
            presetFieldValues: [
                "provider_preset": "openrouter",
                "api_endpoint": "https://openrouter.ai/api/v1/credits",
                "parse_rule": "total_credits - total_usage",
                "low_balance_threshold": "10",
                "console_url": "https://openrouter.ai/settings/credits"
            ]
        ),
        PopularSoftwarePreset(
            id: "siliconflow",
            name: "SiliconFlow",
            aliases: ["siliconflow", "硅基流动", "api", "balance"],
            group: .aiApiBalance,
            monogram: "SF",
            accentHex: "#7C3AED",
            symbolName: "cpu.fill",
            websiteDomain: "cloud.siliconflow.cn",
            suggestedCategoryId: SubscriptionCategory.BuiltinID.aiTools,
            suggestedTemplateId: TemplateDefinition.BuiltinID.apiBalance,
            defaultBillingCycle: .oneTime,
            defaultPrice: "50",
            defaultCurrency: "CNY",
            presetFieldValues: [
                "provider_preset": "siliconflow",
                "api_endpoint": "https://api.siliconflow.cn/v1/user/info",
                "parse_rule": "data.totalBalance",
                "low_balance_threshold": "10",
                "console_url": "https://cloud.siliconflow.cn"
            ]
        ),
        PopularSoftwarePreset(
            id: "sub2api",
            name: "Sub2API",
            aliases: ["sub2api", "中转", "api"],
            group: .aiApiBalance,
            monogram: "S2A",
            accentHex: "#312E81",
            symbolName: "arrow.left.arrow.right",
            websiteDomain: "sub2api.example.com",
            suggestedCategoryId: SubscriptionCategory.BuiltinID.aiTools,
            suggestedTemplateId: TemplateDefinition.BuiltinID.apiBalance,
            defaultBillingCycle: .oneTime,
            defaultPrice: "20",
            defaultCurrency: "USD",
            presetFieldValues: [
                "provider_preset": "sub2api",
                "parse_rule": "balance / remaining",
                "low_balance_threshold": "10"
            ]
        ),
        PopularSoftwarePreset(
            id: "custom-api",
            name: "纯自定义 API",
            aliases: ["custom", "自定义", "http", "json", "api", "webhook"],
            group: .aiApiBalance,
            monogram: "JSON",
            accentHex: "#334155",
            symbolName: "curlybraces",
            websiteDomain: "api.example.com",
            suggestedCategoryId: SubscriptionCategory.BuiltinID.aiTools,
            suggestedTemplateId: TemplateDefinition.BuiltinID.apiBalance,
            defaultBillingCycle: .oneTime,
            defaultPrice: "20",
            defaultCurrency: "USD",
            presetFieldValues: [
                "provider_preset": "custom",
                "parse_rule": "data.balance",
                "low_balance_threshold": "10"
            ]
        )
    ]
}
