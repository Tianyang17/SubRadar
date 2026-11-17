import Foundation
import Testing

@testable import SubRadarCore

#if canImport(AppKit)
    import AppKit
#endif

@Suite("SQLite 迁移、CRUD 与本地图标处理测试")
struct SQLiteMigrationAndRepoTests {
    private func makeTestRepo() async throws -> (SQLiteDatabase, SQLiteSubscriptionRepository, InMemorySecretStore) {
        let db = try SQLiteDatabase(path: ":memory:")
        try await DatabaseMigrator.migrateIfNeeded(db)
        let secretStore = InMemorySecretStore()
        let repo = SQLiteSubscriptionRepository(database: db, secretStore: secretStore)
        return (db, repo, secretStore)
    }

    @Test("数据库 V7 迁移、双价格持久化、6大内置模版同步及 CRUD")
    func testMigrationAndBuiltinTemplates() async throws {
        let (db, repo, _) = try await makeTestRepo()
        let version = try await db.userVersion()
        #expect(version == 21)

        let templates = try await repo.fetchTemplates()
        #expect(templates.count == 7)
        #expect(templates.contains(where: { $0.id == TemplateDefinition.BuiltinID.vps }))
        #expect(templates.contains(where: { $0.id == TemplateDefinition.BuiltinID.apiBalance }))

        let streamingTemplate = templates.first(where: { $0.id == TemplateDefinition.BuiltinID.streaming })
        #expect(streamingTemplate?.defaultFields.contains(where: { $0.key == "plan_tier" }) == true)
        #expect(streamingTemplate?.defaultFields.first(where: { $0.key == "manage_url" })?.label == "官网地址")

        let vpsTemplate = templates.first(where: { $0.id == TemplateDefinition.BuiltinID.vps })
        #expect(vpsTemplate?.defaultFields.contains(where: { $0.key == "instance_type" }) == true)
        #expect(
            vpsTemplate?.defaultFields.contains(where: { $0.key == "operating_system" && $0.label == "操作系统" }) == true)
        #expect(vpsTemplate?.defaultFields.contains(where: { $0.key == "instance_spec" }) == true)
        #expect(vpsTemplate?.defaultFields.contains(where: { $0.key == "traffic_spec" }) == true)
        #expect(vpsTemplate?.defaultFields.first(where: { $0.key == "ssh_port" })?.defaultValue == "22")

        let softwareTemplate = templates.first(where: { $0.id == TemplateDefinition.BuiltinID.softwareLicense })
        #expect(softwareTemplate != nil)
        #expect(softwareTemplate?.defaultFields.contains(where: { $0.key == "purchase_source" }) == true)
        #expect(softwareTemplate?.defaultFields.contains(where: { $0.key == "username" }) == true)
        #expect(
            softwareTemplate?.defaultFields.contains(where: { $0.key == "account_password" && $0.type == .secret })
                == true)

        let aiTemplate = templates.first(where: { $0.id == TemplateDefinition.BuiltinID.aiMembership })
        #expect(aiTemplate != nil)
        #expect(
            aiTemplate?.defaultFields.contains(where: { $0.key == "account_password" && $0.type == .secret }) == true)
        #expect(aiTemplate?.defaultFields.contains(where: { $0.key == "warranty_policy" }) == true)
        #expect(aiTemplate?.defaultFields.contains(where: { $0.key == "account_alive_status" }) == true)
        #expect(aiTemplate?.defaultFields.contains(where: { $0.key == "account_source" }) == true)
        #expect(aiTemplate?.defaultFields.contains(where: { $0.key == "manage_url" }) == true)
        #expect(
            aiTemplate?.defaultFields.contains(where: { $0.key == "quota_limit" || $0.key == "usage_url" }) == false)

        let apiTemplate = templates.first(where: { $0.id == TemplateDefinition.BuiltinID.apiBalance })
        #expect(apiTemplate?.defaultFields.first(where: { $0.key == "provider_preset" })?.label == "API 平台")
        #expect(apiTemplate?.defaultFields.contains(where: { $0.key == "account_source" }) == true)
        #expect(apiTemplate?.defaultFields.contains(where: { $0.key == "warranty_policy" }) == true)
        #expect(apiTemplate?.defaultFields.contains(where: { $0.key == "api_key" && $0.type == .secret }) == true)
        #expect(
            apiTemplate?.defaultFields.contains(where: { $0.key == "current_balance" && $0.type == .number }) == true)
        #expect(
            apiTemplate?.defaultFields.contains(where: { $0.key == "low_balance_threshold" && $0.type == .number })
                == true)

        // 验证内置模版也支持直接编辑持久化
        if var mutableAI = aiTemplate {
            mutableAI.name = "AI 会员账号"
            try await repo.saveTemplate(mutableAI)
            let updatedTemplates = try await repo.fetchTemplates()
            #expect(
                updatedTemplates.first(where: { $0.id == TemplateDefinition.BuiltinID.aiMembership })?.name == "AI 会员账号"
            )
        }

        // 验证旧库 V5 -> V6 增量升级会补齐 apiBalance 并同步内置模版字段
        try await db.performTransaction { conn in
            try conn.execute(
                "DELETE FROM templates WHERE id = ?;",
                bindings: [.text(TemplateDefinition.BuiltinID.apiBalance.uuidString)]
            )
            try conn.execute(
                "UPDATE templates SET default_fields_json = '[]' WHERE id = ?;",
                bindings: [.text(TemplateDefinition.BuiltinID.vps.uuidString)]
            )
            try conn.execute("PRAGMA user_version = 5;")
        }
        try await DatabaseMigrator.migrateIfNeeded(db)
        #expect(try await db.userVersion() == 21)
        let upgraded = try await repo.fetchTemplates()
        #expect(upgraded.count == 7)
        #expect(
            upgraded.first(where: { $0.id == TemplateDefinition.BuiltinID.vps })?.defaultFields.contains(where: {
                $0.key == "operating_system"
            }) == true)
        #expect(
            upgraded.first(where: { $0.id == TemplateDefinition.BuiltinID.vps })?.defaultFields.contains(where: {
                $0.key == "instance_spec"
            }) == true)

        let categories = try await repo.fetchCategories()
        #expect(categories.count == 6)
        #expect(categories.first(where: { $0.id == SubscriptionCategory.BuiltinID.streaming })?.name == "影音娱乐")
        #expect(categories.first(where: { $0.id == SubscriptionCategory.BuiltinID.aiTools })?.name == "AI 与 API 服务")
        #expect(categories.first(where: { $0.id == SubscriptionCategory.BuiltinID.cloudStorage })?.name == "网盘存储")
        #expect(categories.first(where: { $0.id == SubscriptionCategory.BuiltinID.cloudInfra })?.name == "云服务器")
        #expect(categories.first(where: { $0.id == SubscriptionCategory.BuiltinID.domainNetwork })?.name == "域名服务")
        #expect(categories.first(where: { $0.id == SubscriptionCategory.BuiltinID.productivity })?.name == "软件工具")

        // 自定义分类 CRUD
        let aiCategory = SubscriptionCategory(
            name: "AI 工具",
            iconSymbol: "cpu",
            colorKey: .indigo,
            isBuiltin: false,
            sortOrder: 10
        )
        try await repo.saveCategory(aiCategory)
        let afterSave = try await repo.fetchCategories()
        #expect(afterSave.contains(where: { $0.id == aiCategory.id && $0.name == "AI 工具" }))

        try await repo.deleteCategory(id: aiCategory.id)
        let afterDelete = try await repo.fetchCategories()
        #expect(afterDelete.contains(where: { $0.id == aiCategory.id }) == false)
    }

    @Test("Phase 7.9 Batch B: 账单类型(扣费/充值/退款)、净花销统计及单条流水增改删")
    func testBillingRecordKindAndSingleRecordCRUD() async throws {
        let (_, repo, _) = try await makeTestRepo()
        let subId = UUID()
        let item = SubscriptionItem(
            id: subId,
            name: "DeepSeek API",
            templateId: TemplateDefinition.BuiltinID.apiBalance,
            price: 100,
            currency: "CNY",
            billingCycleType: .oneTime,
            nextRenewalDate: Date()
        )
        let topUp1 = BillingRecord(
            subscriptionId: subId,
            amount: 100,
            currency: "CNY",
            baseCurrencyAmount: 100,
            billedAt: Date(timeIntervalSince1970: 1_750_000_000),
            source: .manualLedger,
            kind: .topUp,
            note: "首次充值"
        )
        let refund1 = BillingRecord(
            subscriptionId: subId,
            amount: 20,
            currency: "CNY",
            baseCurrencyAmount: 20,
            billedAt: Date(timeIntervalSince1970: 1_750_086_400),
            source: .manualLedger,
            kind: .refund,
            note: "优惠券退回"
        )
        try await repo.saveSubscription(item, initialRecords: [topUp1, refund1])
        #expect(try await repo.totalSpent(for: subId) == 80)

        var updatedRefund = refund1
        updatedRefund.amount = 30
        updatedRefund.baseCurrencyAmount = 30
        updatedRefund.note = "补退差额"
        try await repo.updateBillingRecord(updatedRefund)
        #expect(try await repo.totalSpent(for: subId) == 70)

        try await repo.deleteBillingRecord(id: updatedRefund.id)
        #expect(try await repo.totalSpent(for: subId) == 100)
    }

    @Test("订阅保存、敏感字段隔离加密、自定义时间段流水查询与级联删除")
    func testSubscriptionCRUDAndCascadeDelete() async throws {
        let (db, repo, _) = try await makeTestRepo()
        let engine = BillingEngine()

        let subId = UUID()
        let start = Date(timeIntervalSince1970: 1_672_531_200)  // 2023-01-01
        let end = Date(timeIntervalSince1970: 1_767_225_600)  // 2026-01-01
        let passwordFieldId = UUID()

        let item = SubscriptionItem(
            id: subId,
            name: "测试 VPS",
            templateId: TemplateDefinition.BuiltinID.vps,
            price: Decimal(string: "50.00")!,
            renewalPrice: Decimal(string: "68.00")!,
            currency: "USD",
            billingCycleType: .annually,
            startDate: start,
            nextRenewalDate: end,
            customFields: [
                CustomField(
                    subscriptionId: subId, key: "ipv4", label: "IPv4", type: .text, value: "198.51.100.10", sortOrder: 0
                ),
                CustomField(
                    id: passwordFieldId, subscriptionId: subId, key: "ssh_password", label: "密码", type: .secret,
                    value: "SuperSecret#123", sortOrder: 1)
            ]
        )

        let records = await engine.generateHistoricalRecords(for: item, endDate: end) { _, _ in Decimal(7.2) }
        #expect(records.count == 3)  // 2023, 2024, 2025

        try await repo.saveSubscription(item, initialRecords: records)

        // 1. 验证读取回来的字段含解密后密码
        let fetched = try await repo.fetchSubscription(id: subId)
        #expect(fetched?.name == "测试 VPS")
        #expect(fetched?.price == Decimal(string: "50.00")!)
        #expect(fetched?.renewalPrice == Decimal(string: "68.00")!)
        #expect(fetched?.sshCommand == "ssh root@198.51.100.10")
        #expect(fetched?.fieldValue(forKey: "ssh_password") == "SuperSecret#123")

        // 2. 验证 SQLite 表中绝不存储明文密码
        let rawRows = try await db.query(
            "SELECT field_value FROM subscription_custom_fields WHERE id = ?;",
            bindings: [.text(passwordFieldId.uuidString)]
        )
        let storedVal = rawRows.first?.string("field_value") ?? ""
        #expect(storedVal.hasPrefix("__KEYCHAIN_REF__:"))
        #expect(!storedVal.contains("SuperSecret#123"))

        // 3. 验证自定义时间段过滤（仅查询 2024 年账单）
        let rangeStart = Date(timeIntervalSince1970: 1_704_067_200)  // 2024-01-01
        let rangeEnd = Date(timeIntervalSince1970: 1_735_603_200)  // 2024-12-31
        let rangeRecords = try await repo.fetchBillingRecords(from: rangeStart, to: rangeEnd)
        #expect(rangeRecords.count == 1)

        // 4. 验证删除订阅时级联清理扩展字段与流水
        try await repo.deleteSubscription(id: subId)
        let afterDeleteRecords = try await repo.fetchBillingRecords(for: subId)
        #expect(afterDeleteRecords.isEmpty)
    }

    @Test("本地上传图片自动居中裁剪并归一化为 256x256 PNG")
    func testIconNormalizationAndInvalidAppBundle() throws {
        let iconService = IconService()

        // 验证非 .app 路径拦截
        #expect(throws: IconServiceError.invalidApplicationBundle) {
            _ = try iconService.extractLocalAppInfo(at: URL(fileURLWithPath: "/Applications/NotAnApp.txt"))
        }

        #if canImport(AppKit)
            // 构造一张 400x200 矩形测试图，验证裁剪后输出为 256x256 PNG
            let rectSize = NSSize(width: 400, height: 200)
            let sourceImage = NSImage(size: rectSize)
            sourceImage.lockFocus()
            NSColor.systemIndigo.setFill()
            NSBezierPath(rect: NSRect(origin: .zero, size: rectSize)).fill()
            sourceImage.unlockFocus()

            let rawTiff = try #require(sourceImage.tiffRepresentation)
            let normalizedPNG = try iconService.normalizeImageData(rawTiff, targetDimension: 256)
            let outputRep = try #require(NSBitmapImageRep(data: normalizedPNG))

            #expect(outputRep.pixelsWide == 256)
            #expect(outputRep.pixelsHigh == 256)
        #endif
    }

    @Test("从系统应用提取图标与名称（若存在 Calculator.app）")
    func testExtractLocalCalculatorAppIfPresent() throws {
        let calcURL = URL(fileURLWithPath: "/System/Applications/Calculator.app")
        guard FileManager.default.fileExists(atPath: calcURL.path) else {
            return
        }
        let info = try IconService().extractLocalAppInfo(at: calcURL)
        #expect(!info.name.isEmpty)
        #expect((info.iconData?.count ?? 0) > 0)
    }
}
