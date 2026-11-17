import Foundation

/// 系统预置模版管理器
public enum TemplatePresetManager {
    public static let builtinTemplates: [TemplateDefinition] = [
        TemplateDefinition(
            id: TemplateDefinition.BuiltinID.streaming,
            name: "流媒体与会员",
            iconSymbol: "play.tv.fill",
            isBuiltin: true,
            defaultFields: [
                FieldSchema(key: "account", label: "订阅账号", type: .text, placeholder: "手机号 / 邮箱 / 用户名"),
                FieldSchema(key: "plan_tier", label: "套餐档位", type: .text, placeholder: "例如 SVIP 年卡 / 家庭组 / 4K 尊享"),
                FieldSchema(key: "payment_method", label: "扣款方式", type: .text, placeholder: "微信自动扣费 / Apple Pay / 银行卡"),
                FieldSchema(key: "manage_url", label: "官网地址", type: .url, placeholder: "https://...")
            ]
        ),
        TemplateDefinition(
            id: TemplateDefinition.BuiltinID.vps,
            name: "VPS 与服务器",
            iconSymbol: "server.rack",
            isBuiltin: true,
            defaultFields: [
                FieldSchema(
                    key: "instance_type", label: "服务器类型", type: .text, placeholder: "VPS / 独立服务器 / NAT / 虚拟主机"),
                FieldSchema(
                    key: "operating_system", label: "操作系统", type: .text,
                    placeholder: "Rocky Linux 9.4 / Ubuntu 24.04 LTS / Windows Server 2022 / macOS 15"),
                FieldSchema(
                    key: "instance_spec", label: "配置规格", type: .text, placeholder: "2C / 4G RAM / 40G SSD / No GPU"),
                FieldSchema(key: "traffic_spec", label: "流量与限制", type: .text, placeholder: "1 Gbps / 不限流量"),
                FieldSchema(
                    key: "region", label: "机房 / 地区", type: .text, placeholder: "例如 中国香港 (HKG / BGP)"),
                FieldSchema(key: "ipv4", label: "IPv4 地址", type: .text, placeholder: "例如 198.51.100.24"),
                FieldSchema(key: "ipv6", label: "IPv6 地址", type: .text, placeholder: "例如 2001:db8::1"),
                FieldSchema(key: "ssh_port", label: "SSH 端口", type: .number, placeholder: "22", defaultValue: "22"),
                FieldSchema(key: "ssh_user", label: "用户名", type: .text, placeholder: "root", defaultValue: "root"),
                FieldSchema(key: "ssh_password", label: "密码 / 密钥口令", type: .secret, placeholder: "加密存储"),
                FieldSchema(key: "panel_url", label: "官网 / 控制面板", type: .url, placeholder: "https://...")
            ]
        ),
        TemplateDefinition(
            id: TemplateDefinition.BuiltinID.domain,
            name: "域名资产",
            iconSymbol: "globe",
            isBuiltin: true,
            defaultFields: [
                FieldSchema(key: "domain_name", label: "域名名称", type: .text, placeholder: "例如 subradar.app"),
                FieldSchema(
                    key: "registrar", label: "注册商", type: .text, placeholder: "Cloudflare / Spaceship / Namecheap"),
                FieldSchema(key: "dns_provider", label: "DNS 解析商", type: .text, placeholder: "Cloudflare / DNSPod"),
                FieldSchema(key: "manage_url", label: "官网地址", type: .url, placeholder: "https://dash.cloudflare.com")
            ]
        ),
        TemplateDefinition(
            id: TemplateDefinition.BuiltinID.softwareLicense,
            name: "软件与激活码",
            iconSymbol: "key.fill",
            isBuiltin: true,
            defaultFields: [
                FieldSchema(
                    key: "purchase_source", label: "购买来源", type: .text, placeholder: "官网直购 / App Store / Steam"),
                FieldSchema(
                    key: "supported_platforms", label: "平台", type: .text,
                    placeholder: "Mac / iPhone / iPad / Android / Windows / Linux"),
                FieldSchema(key: "username", label: "用户名", type: .text, placeholder: "登录用户名 / 账号昵称"),
                FieldSchema(key: "account_password", label: "密码", type: .secret, placeholder: "加密存储"),
                FieldSchema(
                    key: "license_key", label: "激活码 / License Key", type: .secret, placeholder: "XXXX-XXXX-XXXX-XXXX"),
                FieldSchema(key: "licensed_email", label: "绑定邮箱", type: .text, placeholder: "user@example.com"),
                FieldSchema(key: "device_limit", label: "授权设备数", type: .number, placeholder: "例如 3"),
                FieldSchema(key: "download_url", label: "官网地址", type: .url, placeholder: "https://...")
            ]
        ),
        TemplateDefinition(
            id: TemplateDefinition.BuiltinID.aiMembership,
            name: "AI 会员与额度",
            iconSymbol: "sparkles",
            isBuiltin: true,
            defaultFields: [
                FieldSchema(key: "account_email", label: "登录账号", type: .text, placeholder: "user@example.com"),
                FieldSchema(key: "account_password", label: "登录密码", type: .secret, placeholder: "加密存储"),
                FieldSchema(key: "plan_tier", label: "会员档位", type: .text, placeholder: "Plus / Pro / Ultra / Max"),
                FieldSchema(
                    key: "account_source", label: "来源", type: .text, placeholder: "官网直充 / 渠道代充 / 第三方合租"),
                FieldSchema(
                    key: "warranty_policy", label: "质保与售后说明", type: .text, placeholder: "例如 官号直充 / 质保 1 个月 / 翻车包赔"),
                FieldSchema(
                    key: "account_alive_status", label: "存活状态", type: .text, placeholder: "正常存活 / 降智 / 已封号"),
                FieldSchema(key: "manage_url", label: "官网地址", type: .url, placeholder: "https://...")
            ]
        ),
        TemplateDefinition(
            id: TemplateDefinition.BuiltinID.apiBalance,
            name: "AI API 与余额监控",
            iconSymbol: "gauge.with.dots.needle.33percent",
            isBuiltin: true,
            defaultFields: [
                FieldSchema(
                    key: "provider_preset", label: "API 平台", type: .text,
                    placeholder: "DeepSeek / OpenRouter / SiliconFlow / New API / Sub2API / 自定义"),
                FieldSchema(
                    key: "api_endpoint", label: "接口 Base / 查询地址", type: .url,
                    placeholder: "https://api.deepseek.com/user/balance"),
                FieldSchema(key: "api_key", label: "API Key", type: .secret, placeholder: "sk-...（本地 SQLite 独立表存储）"),
                FieldSchema(
                    key: "parse_rule", label: "解析与换算规则", type: .text,
                    placeholder: "JSON 路径与换算除数，如 total_available / 500000"),
                FieldSchema(key: "current_balance", label: "当前账户余额", type: .number, placeholder: "点击右侧查询获取"),
                FieldSchema(key: "low_balance_threshold", label: "低余额告警阈值", type: .number, placeholder: "例如 10"),
                FieldSchema(
                    key: "account_source", label: "来源", type: .text, placeholder: "官网直充 / 渠道代充 / 第三方合租"),
                FieldSchema(key: "warranty_policy", label: "质保与售后说明", type: .text, placeholder: "例如 官方账户 / 渠道质保说明"),
                FieldSchema(
                    key: "console_url", label: "官网充值地址", type: .url, placeholder: "https://platform.deepseek.com")
            ]
        ),
        TemplateDefinition(
            id: TemplateDefinition.BuiltinID.custom,
            name: "自定义",
            iconSymbol: "slider.horizontal.3",
            isBuiltin: true,
            defaultFields: []
        )
    ]

    public static func template(for id: UUID, from templates: [TemplateDefinition]) -> TemplateDefinition? {
        templates.first(where: { $0.id == id }) ?? builtinTemplates.first(where: { $0.id == id })
    }

    /// 统一模版展示顺序：其余内置模版按预设顺序在前 → 用户自建模版在中间 → 「自定义」空白模版恒置最后
    public static func sortedTemplates(_ templates: [TemplateDefinition]) -> [TemplateDefinition] {
        let builtinOrder = Dictionary(
            uniqueKeysWithValues: builtinTemplates.enumerated().map { ($1.id, $0) }
        )
        return templates.sorted { lhs, rhs in
            let lRank = sortBucket(for: lhs, builtinOrder: builtinOrder)
            let rRank = sortBucket(for: rhs, builtinOrder: builtinOrder)
            if lRank != rRank {
                return lRank < rRank
            }
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    private static func sortBucket(
        for template: TemplateDefinition,
        builtinOrder: [UUID: Int]
    ) -> (group: Int, order: Int) {
        if template.id == TemplateDefinition.BuiltinID.custom {
            return (2, 0)
        }
        if let idx = builtinOrder[template.id] {
            return (0, idx)
        }
        if template.isBuiltin {
            return (0, Int.max)
        }
        return (1, 0)
    }

    public static func allKnownSchemaKeys(including customTemplates: [TemplateDefinition] = []) -> Set<String> {
        var keys = Set<String>()
        for template in builtinTemplates + customTemplates {
            for field in template.defaultFields {
                keys.insert(field.key)
            }
        }
        keys.insert("ip_address")
        keys.insert("account_source_detail")
        keys.insert("purchase_source_detail")
        return keys
    }
}
