import Foundation

public protocol HTTPTransportProtocol: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionHTTPTransport: HTTPTransportProtocol {
    public init() {}

    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIBalanceError.invalidResponse
        }
        return (data, http)
    }
}

public enum APIBalanceProviderPreset: String, CaseIterable, Identifiable, Sendable {
    case deepseek
    case openrouter
    case siliconflow
    case newAPI = "new_api"
    case sub2api
    case custom

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .deepseek: return "DeepSeek"
        case .openrouter: return "OpenRouter"
        case .siliconflow: return "硅基流动 (SiliconFlow)"
        case .newAPI: return "New API"
        case .sub2api: return "Sub2API"
        case .custom: return "自定义接口"
        }
    }

    public var defaultEndpoint: String {
        switch self {
        case .deepseek: return "https://api.deepseek.com/user/balance"
        case .openrouter: return "https://openrouter.ai/api/v1/credits"
        case .siliconflow: return "https://api.siliconflow.cn/v1/user/info"
        case .newAPI: return "https://your-newapi.example.com/api/user/self"
        case .sub2api: return "https://your-sub2api.example.com"
        case .custom: return "https://api.example.com/v1/balance"
        }
    }

    public var defaultParseRule: String {
        switch self {
        case .deepseek: return "balance_infos[0].total_balance"
        case .openrouter: return "total_credits - total_usage"
        case .siliconflow: return "data.totalBalance"
        case .newAPI: return "data.quota / 500000"
        case .sub2api: return "balance / remaining"
        case .custom: return "data.balance"
        }
    }

    public var defaultConsoleURL: String {
        switch self {
        case .deepseek: return "https://platform.deepseek.com"
        case .openrouter: return "https://openrouter.ai/settings/credits"
        case .siliconflow: return "https://cloud.siliconflow.cn"
        case .newAPI: return "https://your-newapi.example.com"
        case .sub2api: return "https://your-sub2api.example.com"
        case .custom: return "https://api.example.com"
        }
    }

    public var defaultCurrency: String {
        switch self {
        case .deepseek, .siliconflow: return "CNY"
        case .openrouter, .newAPI, .sub2api, .custom: return "USD"
        }
    }

    public init(raw: String?) {
        let normalized = (raw ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
        self = APIBalanceProviderPreset(rawValue: normalized) ?? .custom
    }
}

public struct APIBalanceResult: Sendable, Equatable {
    public let balance: Decimal
    public let currency: String
    public let checkedAt: Date

    public init(balance: Decimal, currency: String, checkedAt: Date = Date()) {
        self.balance = balance
        self.currency = currency.uppercased()
        self.checkedAt = checkedAt
    }
}

public enum APIBalanceError: LocalizedError, Sendable {
    case missingEndpoint
    case invalidEndpoint
    case invalidResponse
    case httpStatus(Int)
    case missingNewAPIUserID(String)
    case parseFailed(String)

    public var errorDescription: String? {
        switch self {
        case .missingEndpoint:
            return "尚未配置 API 余额查询地址，请补充接口 URL。"
        case .invalidEndpoint:
            return "API 查询地址格式不正确，请填写以 http:// 或 https:// 开头的完整网址。"
        case .invalidResponse:
            return "服务器返回内容格式异常，暂时无法识别余额。"
        case .missingNewAPIUserID(let detail):
            return "查询 New API 账户总额度（/api/user/self）需要提供纯数字【用户 ID】（用于 New-Api-User 鉴权头）：\(detail)"
        case .httpStatus(let code):
            switch code {
            case 401:
                return "API Key 或凭证无效，无法查询余额，请核对后重试。"
            case 403:
                return "当前密钥无权查询余额（部分平台需使用管理密钥或网页登录 Cookie）。"
            case 404:
                return "未找到对应的余额查询接口，请检查接口地址或所选厂商模版。"
            case 429:
                return "查询过于频繁，请稍后再试。"
            case 500...599:
                return "服务商接口暂时异常（状态码 \(code)），请稍后再试。"
            default:
                return "余额查询未成功（状态码 \(code)），请检查地址、密钥与网络状态。"
            }
        case .parseFailed:
            return "接口返回成功但未找到余额字段，请核对所选厂商模版或自定义 JSON 解析路径。"
        }
    }
}

public protocol APIBalanceServiceProtocol: Sendable {
    func fetchBalance(for item: SubscriptionItem) async throws -> APIBalanceResult
}

public final class APIBalanceService: APIBalanceServiceProtocol {
    private let transport: HTTPTransportProtocol
    private let logger: AppLogService

    public init(
        transport: HTTPTransportProtocol = URLSessionHTTPTransport(),
        logger: AppLogService = .shared
    ) {
        self.transport = transport
        self.logger = logger
    }

    public func fetchBalance(for item: SubscriptionItem) async throws -> APIBalanceResult {
        let preset = APIBalanceProviderPreset(raw: item.fieldValue(forKey: "provider_preset"))
        let rawEndpoint = (item.fieldValue(forKey: "api_endpoint") ?? "").trimmingCharacters(
            in: .whitespacesAndNewlines)
        guard !rawEndpoint.isEmpty else {
            throw APIBalanceError.missingEndpoint
        }
        let apiKey = (item.fieldValue(forKey: "api_key") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let parseRule = (item.fieldValue(forKey: "parse_rule") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        switch preset {
        case .deepseek:
            let url = try resolvedURL(rawEndpoint, appendIfRoot: "/user/balance")
            let data = try await performGET(url: url, apiKey: apiKey)
            return try parseDeepSeek(data: data, preferredCurrency: item.currency)

        case .openrouter:
            let url = try resolvedURL(rawEndpoint, appendIfRoot: "/api/v1/credits")
            let data = try await performGET(url: url, apiKey: apiKey)
            return try parseOpenRouter(data: data, defaultCurrency: item.currency)

        case .siliconflow:
            let url = try resolvedURL(rawEndpoint, appendIfRoot: "/v1/user/info")
            let data = try await performGET(url: url, apiKey: apiKey)
            return try parseFirstMatching(
                data: data,
                rules: [parseRule, "data.totalBalance", "data.balance", "totalBalance"],
                defaultCurrency: item.currency
            )

        case .newAPI:
            return try await fetchNewAPIBalance(
                item: item,
                rawEndpoint: rawEndpoint,
                apiKey: apiKey,
                parseRule: parseRule
            )

        case .sub2api:
            let url = try resolvedURL(rawEndpoint, appendIfRoot: "/v1/usage")
            let data = try await performGET(url: url, apiKey: apiKey)
            return try parseFirstMatching(
                data: data,
                rules: [
                    parseRule, "remaining", "balance", "data.remaining", "data.balance", "total_available",
                    "data.total_available"
                ],
                defaultCurrency: item.currency
            )

        case .custom:
            let usePost = parseRule.uppercased().hasPrefix("POST:")
            let cleanRule =
                usePost ? String(parseRule.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines) : parseRule
            let url = try resolvedURL(rawEndpoint, appendIfRoot: nil)
            let data = try await performRequest(url: url, method: usePost ? "POST" : "GET", apiKey: apiKey)
            return try parseFirstMatching(
                data: data,
                rules: [cleanRule, "data.balance", "balance", "data.remaining", "remaining"],
                defaultCurrency: item.currency
            )
        }
    }

    // MARK: - HTTP Execution

    func performGET(url: URL, apiKey: String, headers: [String: String] = [:]) async throws -> Data {
        try await performRequest(url: url, method: "GET", apiKey: apiKey, headers: headers)
    }

    func performRequest(
        url: URL,
        method: String,
        apiKey: String,
        headers: [String: String] = [:]
    ) async throws -> Data {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = 15
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if !apiKey.isEmpty {
            req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        for (headerKey, headerVal) in headers {
            req.setValue(headerVal, forHTTPHeaderField: headerKey)
        }
        let (data, http) = try await transport.data(for: req)
        guard (200...299).contains(http.statusCode) else {
            await logger.log(
                .error, category: .balance,
                "余额探针失败 method=\(method) status=\(http.statusCode) url=\(LogSanitizer.sanitizeURL(url))")
            throw APIBalanceError.httpStatus(http.statusCode)
        }
        await logger.log(
            .info, category: .balance,
            "余额探针完成 method=\(method) status=\(http.statusCode) url=\(LogSanitizer.sanitizeURL(url))")
        return data
    }

    func resolvedURL(_ raw: String, appendIfRoot suffix: String?) throws -> URL {
        let normalized = raw.hasPrefix("http://") || raw.hasPrefix("https://") ? raw : "https://\(raw)"
        guard var components = URLComponents(string: normalized), components.host != nil else {
            throw APIBalanceError.invalidEndpoint
        }
        if let suffix, components.path.isEmpty || components.path == "/" {
            components.path = suffix
        }
        guard let url = components.url else {
            throw APIBalanceError.invalidEndpoint
        }
        return url
    }

    func replacingOrAppendingPath(_ raw: String, newPath: String) throws -> URL {
        let normalized = raw.hasPrefix("http://") || raw.hasPrefix("https://") ? raw : "https://\(raw)"
        guard var components = URLComponents(string: normalized), components.host != nil else {
            throw APIBalanceError.invalidEndpoint
        }
        components.path = newPath
        guard let url = components.url else {
            throw APIBalanceError.invalidEndpoint
        }
        return url
    }
}
