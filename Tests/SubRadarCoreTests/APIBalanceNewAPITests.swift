import Foundation
import Testing

@testable import SubRadarCore

private final class StubHTTPTransport: HTTPTransportProtocol, @unchecked Sendable {
    let handler: @Sendable (URLRequest) throws -> (Data, HTTPURLResponse)

    init(handler: @escaping @Sendable (URLRequest) throws -> (Data, HTTPURLResponse)) {
        self.handler = handler
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try handler(request)
    }
}

@Suite("New API 账户总额度与用户 ID (New-Api-User) 鉴权测试")
struct APIBalanceNewAPITests {
    private func makeHTTPResponse(url: URL, statusCode: Int = 200) -> HTTPURLResponse {
        HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: nil)!
    }

    private func makeItem(
        endpoint: String,
        userId: String? = nil,
        apiKey: String = "sk-test-token",
        parseRule: String = "data.quota / 500000"
    ) -> SubscriptionItem {
        let subId = UUID()
        let now = Date()
        var fields: [CustomField] = [
            CustomField(
                subscriptionId: subId, key: "provider_preset", label: "API 平台", type: .text, value: "new_api",
                sortOrder: 0),
            CustomField(
                subscriptionId: subId, key: "api_endpoint", label: "接口地址", type: .url, value: endpoint,
                sortOrder: 1),
            CustomField(
                subscriptionId: subId, key: "api_key", label: "API Key", type: .secret, value: apiKey,
                sortOrder: 2),
            CustomField(
                subscriptionId: subId, key: "parse_rule", label: "解析规则", type: .text, value: parseRule,
                sortOrder: 3)
        ]
        if let userId {
            fields.append(
                CustomField(
                    subscriptionId: subId, key: "api_user_id", label: "用户 ID", type: .text, value: userId,
                    sortOrder: 4)
            )
        }
        return SubscriptionItem(
            id: subId,
            name: "New API 账户",
            categoryId: SubscriptionCategory.BuiltinID.aiTools,
            templateId: TemplateDefinition.BuiltinID.apiBalance,
            price: 50,
            currency: "USD",
            billingCycleType: .oneTime,
            startDate: now,
            nextRenewalDate: now,
            customFields: fields
        )
    }

    @Test("提供用户 ID 时请求 /api/user/self 且携带 New-Api-User 请求头")
    func fetchBalanceWithNewApiUserHeader() async throws {
        let transport = StubHTTPTransport { req in
            #expect(req.value(forHTTPHeaderField: "New-Api-User") == "42")
            #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer sk-test-token")
            #expect(req.url?.path == "/api/user/self")
            let json = #"{"success":true,"data":{"id":42,"username":"alice","quota":5000000}}"#
            return (Data(json.utf8), self.makeHTTPResponse(url: req.url!))
        }

        let service = APIBalanceService(transport: transport)
        let item = makeItem(endpoint: "https://cf.cpass.cc/api/user/self", userId: "42")
        let result = try await service.fetchBalance(for: item)
        #expect(result.balance == Decimal(10))
    }

    @Test("未提供用户 ID 但请求 /api/user/self 遇 401 且回退 usage 也失败时返回友好的用户 ID 缺失提示")
    func missingUserIdOnSelfEndpointGivesClearError() async throws {
        let transport = StubHTTPTransport { req in
            let errorJson = #"{"success":false,"message":"无权进行此操作，未提供 New-Api-User"}"#
            return (Data(errorJson.utf8), self.makeHTTPResponse(url: req.url!, statusCode: 401))
        }

        let service = APIBalanceService(transport: transport)
        let item = makeItem(endpoint: "https://cf.cpass.cc/api/user/self", userId: nil)

        do {
            _ = try await service.fetchBalance(for: item)
            Issue.record("应当抛出缺少用户 ID 的友好错误")
        } catch {
            let desc = error.localizedDescription
            #expect(desc.contains("用户 ID") || desc.contains("New-Api-User"))
        }
    }

    @Test("HTTP 200 但返回业务错误信息时提取并展示服务商具体报错")
    func serverBusinessErrorWith200Extracted() async throws {
        let transport = StubHTTPTransport { req in
            if req.url?.path == "/api/user/self" {
                let errorJson = #"{"success":false,"message":"普通令牌无权访问用户管理接口，请使用系统访问令牌"}"#
                return (Data(errorJson.utf8), self.makeHTTPResponse(url: req.url!, statusCode: 200))
            }
            return (
                Data(#"{"success":false,"message":"令牌不存在"}"#.utf8),
                self.makeHTTPResponse(url: req.url!, statusCode: 404)
            )
        }

        let service = APIBalanceService(transport: transport)
        let item = makeItem(endpoint: "https://cf.cpass.cc/api/user/self", userId: "3315")

        do {
            _ = try await service.fetchBalance(for: item)
            Issue.record("应当抛出业务错误")
        } catch {
            let desc = error.localizedDescription
            #expect(desc.contains("普通令牌无权访问用户管理接口") || desc.contains("服务商接口提示"))
        }
    }

    @Test("当 /api/user/self 失败时自动尝试 /api/usage/token 并解析 user_quota")
    func fallbackToUsageTokenExtractsUserQuota() async throws {
        let transport = StubHTTPTransport { req in
            if req.url?.path == "/api/user/self" {
                return (
                    Data(#"{"success":false,"message":"无权"}"#.utf8),
                    self.makeHTTPResponse(url: req.url!, statusCode: 403)
                )
            }
            #expect(req.url?.path == "/api/usage/token")
            let tokenJson = """
                {
                    "code": true,
                    "message": "ok",
                    "data": {
                        "total_available": 1000000,
                        "user_quota": {
                            "total_available": 8500000
                        }
                    }
                }
                """
            return (Data(tokenJson.utf8), self.makeHTTPResponse(url: req.url!, statusCode: 200))
        }

        let service = APIBalanceService(transport: transport)
        let item = makeItem(endpoint: "https://cf.cpass.cc/api/user/self", userId: "3315")
        let result = try await service.fetchBalance(for: item)
        #expect(result.balance == Decimal(17))  // 8500000 / 500000 = 17
    }
}
