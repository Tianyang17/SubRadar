import Foundation

extension APIBalanceService {
    /// 处理 New API 余额探测：支持账户总额度（/api/user/self 需 New-Api-User）与普通令牌额度（/api/usage/token）
    func fetchNewAPIBalance(
        item: SubscriptionItem,
        rawEndpoint: String,
        apiKey: String,
        parseRule: String
    ) async throws -> APIBalanceResult {
        let divisor = extractDivisor(from: parseRule) ?? Decimal(500_000)
        let userId = (item.fieldValue(forKey: "api_user_id") ?? item.fieldValue(forKey: "user_id") ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var headers: [String: String] = [:]
        if !userId.isEmpty {
            headers["New-Api-User"] = userId
        }

        var candidatePaths: [String] = []
        if let customLeft = extractCustomPath(from: parseRule), !customLeft.isEmpty {
            candidatePaths.append(customLeft)
        }
        candidatePaths.append(contentsOf: [
            "data.quota",
            "data.user_quota.total_available",
            "data.user_quota.quota",
            "data.total_available",
            "data.balance",
            "quota",
            "total_available",
            "balance"
        ])

        let isSelfExplicit = rawEndpoint.contains("/api/user/self")

        if !userId.isEmpty || isSelfExplicit {
            let targetURL = try resolvedURL(rawEndpoint, appendIfRoot: "/api/user/self")
            do {
                let data = try await performRequest(
                    url: targetURL,
                    method: "GET",
                    apiKey: apiKey,
                    headers: headers
                )
                return try parseDividedCandidates(
                    data: data,
                    candidatePaths: candidatePaths,
                    divisor: divisor,
                    currency: item.currency
                )
            } catch let initialError {
                // 如果是用户 ID 缺失引起的 401，且端点就是 self，先试回退 /api/usage/token
                let fallbackURL = try replacingOrAppendingPath(rawEndpoint, newPath: "/api/usage/token")
                if let fallbackResult = try? await performRequest(
                    url: fallbackURL,
                    method: "GET",
                    apiKey: apiKey,
                    headers: [:]
                ) {
                    if let result = try? parseDividedCandidates(
                        data: fallbackResult,
                        candidatePaths: candidatePaths,
                        divisor: divisor,
                        currency: item.currency
                    ) {
                        return result
                    }
                }

                if let apiErr = initialError as? APIBalanceError {
                    if case .httpStatus(let code) = apiErr, code == 401 || code == 403, userId.isEmpty {
                        throw APIBalanceError.missingNewAPIUserID(
                            "查询 New API 账户总额度（/api/user/self）未提供数字【用户 ID】，请在订阅字段中补充填写以通过 New-Api-User 鉴权。"
                        )
                    }
                }
                throw initialError
            }
        } else {
            let primaryURL = try resolvedURL(rawEndpoint, appendIfRoot: "/api/usage/token")
            do {
                let data = try await performRequest(
                    url: primaryURL,
                    method: "GET",
                    apiKey: apiKey,
                    headers: headers
                )
                return try parseDividedCandidates(
                    data: data,
                    candidatePaths: candidatePaths,
                    divisor: divisor,
                    currency: item.currency
                )
            } catch {
                let fallbackURL = try replacingOrAppendingPath(rawEndpoint, newPath: "/api/user/self")
                do {
                    let data = try await performRequest(
                        url: fallbackURL,
                        method: "GET",
                        apiKey: apiKey,
                        headers: headers
                    )
                    return try parseDividedCandidates(
                        data: data,
                        candidatePaths: candidatePaths,
                        divisor: divisor,
                        currency: item.currency
                    )
                } catch let fallbackError as APIBalanceError {
                    if case .httpStatus(let fallbackCode) = fallbackError,
                        fallbackCode == 401 || fallbackCode == 403,
                        userId.isEmpty
                    {
                        throw APIBalanceError.missingNewAPIUserID(
                            "查询 New API 账户总额度（/api/user/self）未提供数字【用户 ID】，请在订阅字段中补充填写以通过 New-Api-User 鉴权。"
                        )
                    }
                    throw fallbackError
                }
            }
        }
    }
}
