import Foundation
import Observation

/// 分类与模版统一管理 ViewModel
@Observable
@MainActor
public final class TemplateManagerViewModel {
    private let container: AppContainer

    public var categories: [SubscriptionCategory] = []
    public var templates: [TemplateDefinition] = []
    public var errorMessage: String?

    public init(container: AppContainer) {
        self.container = container
    }

    public func loadTemplates() async {
        do {
            async let fetchedCategories = container.repository.fetchCategories()
            async let fetchedTemplates = container.repository.fetchTemplates()
            categories = try await fetchedCategories
            templates = try await fetchedTemplates
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    // MARK: - 分类自定义 CRUD

    @discardableResult
    public func createCustomCategory(
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
        await loadTemplates()
        return category
    }

    public func updateCategory(_ category: SubscriptionCategory) async throws {
        let trimmed = category.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SubscriptionValidationError.emptyName
        }
        var copy = category
        copy.name = trimmed
        try await container.repository.saveCategory(copy)
        await loadTemplates()
    }

    public func deleteCategory(_ category: SubscriptionCategory) async {
        guard !category.isBuiltin else { return }
        do {
            try await container.repository.deleteCategory(id: category.id)
            await loadTemplates()
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    // MARK: - 模版自定义 CRUD

    @discardableResult
    public func createCustomTemplate(
        name: String,
        iconSymbol: String,
        fields: [FieldSchema]
    ) async throws -> TemplateDefinition {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SubscriptionValidationError.emptyName
        }

        let template = TemplateDefinition(
            name: trimmed,
            iconSymbol: iconSymbol.isEmpty ? "square.grid.2x2" : iconSymbol,
            isBuiltin: false,
            defaultFields: fields
        )
        try await container.repository.saveTemplate(template)
        await loadTemplates()
        return template
    }

    public func updateTemplate(_ template: TemplateDefinition) async throws {
        let trimmed = template.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var normalized = template
        normalized.name = trimmed
        try await container.repository.saveTemplate(normalized)
        await loadTemplates()
    }

    public func updateCustomTemplate(_ template: TemplateDefinition) async throws {
        try await updateTemplate(template)
    }

    public func deleteTemplate(_ template: TemplateDefinition) async {
        guard !template.isBuiltin else { return }
        do {
            try await container.repository.deleteTemplate(id: template.id)
            await loadTemplates()
        } catch {
            errorMessage = error.userFacingMessage
        }
    }
}
