import Foundation

@testable import SubRadarCore

/// Phase 2 Mock 体验数据集（无任何真实个人隐私或生产密钥）
public enum MockSampleData {
    public static func makeInitialData(
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> (subscriptions: [SubscriptionItem], records: [BillingRecord]) {
        let billingEngine = BillingEngine(calendar: calendar)

        // 1. QQ 音乐绿钻（按月，还有 2 天到期）
        let qqId = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
        let qqStart = calendar.date(byAdding: .month, value: -8, to: referenceDate) ?? referenceDate
        let qqNext = calendar.date(byAdding: .day, value: 2, to: referenceDate) ?? referenceDate
        let qqMusic = SubscriptionItem(
            id: qqId,
            name: "QQ音乐",
            templateId: TemplateDefinition.BuiltinID.streaming,
            iconData: PopularSoftwarePresetManager.bundledIconData(forPresetId: "qq-music"),
            price: 15,
            currency: "CNY",
            billingCycleType: .monthly,
            startDate: qqStart,
            nextRenewalDate: qqNext,
            autoRenew: true,
            status: .active,
            reminderDaysBefore: 3,
            notes: "连续包月自动续费，每月检查是否听歌",
            customFields: [
                CustomField(
                    subscriptionId: qqId, key: "account", label: "订阅账号", type: .text, value: "qq_demo_user",
                    sortOrder: 0),
                CustomField(
                    subscriptionId: qqId, key: "plan_tier", label: "套餐档位", type: .text, value: "豪华绿钻", sortOrder: 1),
                CustomField(
                    subscriptionId: qqId, key: "payment_method", label: "扣款方式", type: .text, value: "微信免密支付",
                    sortOrder: 2),
                CustomField(
                    subscriptionId: qqId, key: "manage_url", label: "官网地址", type: .url, value: "https://y.qq.com",
                    sortOrder: 3)
            ]
        )

        // 2. 百度网盘 SVIP（按年，连续 3 年历史账单，5 天后到期）
        let baiduId = UUID(uuidString: "10000000-0000-0000-0000-000000000002")!
        let baiduStart = calendar.date(byAdding: .year, value: -3, to: referenceDate) ?? referenceDate
        let baiduNext = calendar.date(byAdding: .day, value: 5, to: referenceDate) ?? referenceDate
        let baiduNetdisk = SubscriptionItem(
            id: baiduId,
            name: "百度网盘 SVIP",
            categoryId: SubscriptionCategory.BuiltinID.cloudStorage,
            templateId: TemplateDefinition.BuiltinID.streaming,
            iconData: PopularSoftwarePresetManager.bundledIconData(forPresetId: "baidu-netdisk"),
            price: 298,
            currency: "CNY",
            billingCycleType: .annually,
            startDate: baiduStart,
            nextRenewalDate: baiduNext,
            autoRenew: false,
            status: .active,
            reminderDaysBefore: 7,
            notes: "大促续费年卡，存储设计素材",
            customFields: [
                CustomField(
                    subscriptionId: baiduId, key: "account", label: "订阅账号", type: .text, value: "138****0000",
                    sortOrder: 0),
                CustomField(
                    subscriptionId: baiduId, key: "plan_tier", label: "套餐档位", type: .text, value: "SVIP 年卡",
                    sortOrder: 1),
                CustomField(
                    subscriptionId: baiduId, key: "payment_method", label: "扣款方式", type: .text, value: "支付宝",
                    sortOrder: 2),
                CustomField(
                    subscriptionId: baiduId, key: "manage_url", label: "官网地址", type: .url,
                    value: "https://pan.baidu.com", sortOrder: 3)
            ]
        )

        // 3. 野草云香港 BGP VPS（人民币年付，连续 4 年，RFC 文档保留 IP）
        let vpsId = UUID(uuidString: "10000000-0000-0000-0000-000000000003")!
        let vpsStart = calendar.date(byAdding: .year, value: -4, to: referenceDate) ?? referenceDate
        let vpsNext = calendar.date(byAdding: .day, value: 18, to: referenceDate) ?? referenceDate
        let vpsItem = SubscriptionItem(
            id: vpsId,
            name: "野草云 HK-BGP",
            templateId: TemplateDefinition.BuiltinID.vps,
            iconData: PopularSoftwarePresetManager.bundledIconData(forPresetId: "yecaoyun"),
            price: Decimal(string: "89.99")!,
            currency: "USD",
            billingCycleType: .annually,
            startDate: vpsStart,
            nextRenewalDate: vpsNext,
            autoRenew: true,
            status: .active,
            reminderDaysBefore: 7,
            notes: "香港 BGP 生产与个人博客节点",
            customFields: [
                CustomField(
                    subscriptionId: vpsId, key: "instance_type", label: "服务器类型", type: .text, value: "VPS", sortOrder: 0
                ),
                CustomField(
                    subscriptionId: vpsId, key: "operating_system", label: "操作系统", type: .text,
                    value: "Rocky Linux 9.4", sortOrder: 1),
                CustomField(
                    subscriptionId: vpsId, key: "instance_spec", label: "配置规格", type: .text,
                    value: "2C / 2G RAM / 30G NVMe / No GPU", sortOrder: 2),
                CustomField(
                    subscriptionId: vpsId, key: "traffic_spec", label: "流量与限制", type: .text, value: "500 Mbps / 1 TB/月",
                    sortOrder: 3),
                CustomField(
                    subscriptionId: vpsId, key: "region", label: "机房 / 地区", type: .text, value: "中国香港 (HKG / BGP)",
                    sortOrder: 4),
                CustomField(
                    subscriptionId: vpsId, key: "ipv4", label: "IPv4 地址", type: .text, value: "198.51.100.24",
                    sortOrder: 5),
                CustomField(
                    subscriptionId: vpsId, key: "ipv6", label: "IPv6 地址", type: .text, value: "2001:db8::1",
                    sortOrder: 6),
                CustomField(
                    subscriptionId: vpsId, key: "ssh_port", label: "SSH 端口", type: .number, value: "2222", sortOrder: 7),
                CustomField(
                    subscriptionId: vpsId, key: "ssh_user", label: "用户名", type: .text, value: "root", sortOrder: 8),
                CustomField(
                    subscriptionId: vpsId, key: "ssh_password", label: "密码 / 密钥口令", type: .secret,
                    value: "DemoPass!2026", sortOrder: 9),
                CustomField(
                    subscriptionId: vpsId, key: "panel_url", label: "官网 / 控制面板", type: .url,
                    value: "https://my.yecaoyun.com", sortOrder: 10)
            ]
        )

        // 4. 域名资产 subradar.app
        let domainId = UUID(uuidString: "10000000-0000-0000-0000-000000000004")!
        let domainStart = calendar.date(byAdding: .year, value: -2, to: referenceDate) ?? referenceDate
        let domainNext = calendar.date(byAdding: .day, value: 45, to: referenceDate) ?? referenceDate
        let domainItem = SubscriptionItem(
            id: domainId,
            name: "subradar.app",
            templateId: TemplateDefinition.BuiltinID.domain,
            iconData: PopularSoftwarePresetManager.bundledIconData(forPresetId: "cloudflare"),
            price: Decimal(string: "14.00")!,
            currency: "USD",
            billingCycleType: .annually,
            startDate: domainStart,
            nextRenewalDate: domainNext,
            autoRenew: true,
            status: .active,
            reminderDaysBefore: 30,
            notes: "开源项目主页与下载域名",
            customFields: [
                CustomField(
                    subscriptionId: domainId, key: "domain_name", label: "域名名称", type: .text, value: "subradar.app",
                    sortOrder: 0),
                CustomField(
                    subscriptionId: domainId, key: "registrar", label: "注册商", type: .text, value: "Cloudflare",
                    sortOrder: 1),
                CustomField(
                    subscriptionId: domainId, key: "dns_provider", label: "DNS 解析商", type: .text,
                    value: "Cloudflare DNS", sortOrder: 2),
                CustomField(
                    subscriptionId: domainId, key: "manage_url", label: "官网地址", type: .url,
                    value: "https://dash.cloudflare.com", sortOrder: 3)
            ]
        )

        // 5. 软件与激活码 Sublime Text 4（买断制）
        let licenseId = UUID(uuidString: "10000000-0000-0000-0000-000000000005")!
        let licenseStart = calendar.date(byAdding: .year, value: -1, to: referenceDate) ?? referenceDate
        let licenseItem = SubscriptionItem(
            id: licenseId,
            name: "Sublime Text 4",
            templateId: TemplateDefinition.BuiltinID.softwareLicense,
            iconData: PopularSoftwarePresetManager.bundledIconData(forPresetId: "sublime-text"),
            price: 99,
            currency: "USD",
            billingCycleType: .oneTime,
            startDate: licenseStart,
            nextRenewalDate: licenseStart,
            autoRenew: false,
            status: .active,
            reminderDaysBefore: -1,
            notes: "个人永久授权",
            customFields: [
                CustomField(
                    subscriptionId: licenseId, key: "purchase_source", label: "购买来源", type: .text, value: "官网直购",
                    sortOrder: 0),
                CustomField(
                    subscriptionId: licenseId, key: "username", label: "用户名", type: .text, value: "dev_user",
                    sortOrder: 1),
                CustomField(
                    subscriptionId: licenseId, key: "account_password", label: "密码", type: .secret,
                    value: "LicensePass!2026", sortOrder: 2),
                CustomField(
                    subscriptionId: licenseId, key: "license_key", label: "激活码 / License Key", type: .secret,
                    value: "SUBL-DEMO-9988-7766", sortOrder: 3),
                CustomField(
                    subscriptionId: licenseId, key: "licensed_email", label: "绑定邮箱", type: .text,
                    value: "dev@subradar.app", sortOrder: 4),
                CustomField(
                    subscriptionId: licenseId, key: "device_limit", label: "授权设备数", type: .number, value: "3",
                    sortOrder: 5),
                CustomField(
                    subscriptionId: licenseId, key: "download_url", label: "官网地址", type: .url,
                    value: "https://www.sublimetext.com", sortOrder: 6)
            ]
        )

        var items = [qqMusic, baiduNetdisk, vpsItem, domainItem, licenseItem]
        items.append(contentsOf: makeAISampleItems(referenceDate: referenceDate, calendar: calendar))
        let allRecords = buildSampleRecords(for: items, billingEngine: billingEngine)
        return (items, allRecords)
    }
}
