import Foundation
import Observation

/// 侧边栏导航项
extension MainViewModel {
    // MARK: - 侧边栏直接管理分类 CRUD

    @discardableResult
    public func createCategory(
        name: String,
        iconSymbol: String,
        colorKey: CategoryColorKey
    ) async throws -> SubscriptionCategory {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SubscriptionValidationError.emptyName
        }

        let maxOrder = (categories.map(\.sortOrder).max() ?? 3) + 1
        let category = SubscriptionCategory(
            name: trimmed,
            iconSymbol: iconSymbol.isEmpty ? "tag.fill" : iconSymbol,
            colorKey: colorKey,
            isBuiltin: false,
            sortOrder: maxOrder
        )
        try await container.repository.saveCategory(category)
        await loadAll()
        showToast("已创建分类「\(trimmed)」")
        return category
    }

    public func updateCategory(_ category: SubscriptionCategory) async throws {
        let trimmed = category.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SubscriptionValidationError.emptyName
        }
        var updated = category
        updated.name = trimmed
        try await container.repository.saveCategory(updated)
        await loadAll()
        showToast("已更新分类「\(trimmed)」")
    }

    public func deleteCategory(_ category: SubscriptionCategory) async {
        guard !category.isBuiltin else { return }
        do {
            try await container.repository.deleteCategory(id: category.id)
            if sidebarSelection == .category(category.id) {
                sidebarSelection = .all
            }
            await loadAll()
            showToast("已删除分类「\(category.name)」")
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    // MARK: - API 余额实时查询 & 数据导出/备份恢复

    @discardableResult
    public func refreshAPIBalance(for item: SubscriptionItem) async -> APIBalanceResult? {
        guard !isRefreshingAPIBalance else { return nil }
        isRefreshingAPIBalance = true
        defer { isRefreshingAPIBalance = false }

        do {
            let result = try await container.apiBalanceService.fetchBalance(for: item)
            let formatted = Self.formatBalanceString(result.balance)

            var updated = item
            if let index = updated.customFields.firstIndex(where: { $0.key == "current_balance" }) {
                updated.customFields[index].value = formatted
            } else {
                let nextOrder = (updated.customFields.map(\.sortOrder).max() ?? -1) + 1
                updated.customFields.append(
                    CustomField(
                        subscriptionId: updated.id,
                        key: "current_balance",
                        label: "当前账户余额",
                        type: .number,
                        value: formatted,
                        sortOrder: nextOrder
                    )
                )
            }
            updated.updatedAt = Date()

            try await container.repository.saveSubscription(updated, initialRecords: [])
            await loadAll()

            if let thresholdRaw = updated.fieldValue(forKey: "low_balance_threshold")?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                let threshold = Decimal(string: thresholdRaw),
                threshold > 0,
                result.balance <= threshold
            {
                await container.notificationService.notifyLowBalance(
                    for: updated,
                    currentBalance: result.balance,
                    threshold: threshold
                )
                showToast("⚠️ \(updated.name) 余额 \(formatted) \(result.currency) 已低于阈值 \(thresholdRaw)")
            } else {
                showToast("已刷新「\(updated.name)」余额：\(formatted) \(result.currency)")
            }
            return result
        } catch {
            let msg = error.userFacingMessage
            errorMessage = msg
            showToast("查询余额失败：\(msg)")
            return nil
        }
    }

    public func exportCSVString() async throws -> String {
        try await BackupExportService().exportLedgerCSV(
            from: container.repository,
            baseCurrency: baseCurrency
        )
    }

    public func exportBackupJSONData(includeSecrets: Bool = false) async throws -> Data {
        try await BackupExportService().exportJSONBackup(
            from: container.repository,
            includeSecrets: includeSecrets
        )
    }

    @discardableResult
    public func restoreBackup(from data: Data) async throws -> BackupRestoreStats {
        let stats = try await BackupExportService().restoreJSONBackup(
            data: data,
            into: container.repository
        )
        await loadAll()
        showToast("已恢复 \(stats.restoredSubscriptions) 项订阅与 \(stats.restoredRecords) 条账单记录")
        return stats
    }
}
