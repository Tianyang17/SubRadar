import Foundation

extension APIBalanceService {
    func parseDeepSeek(data: Data, preferredCurrency: String) throws -> APIBalanceResult {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let infos = root["balance_infos"] as? [[String: Any]],
            !infos.isEmpty
        else {
            return try parseFirstMatching(
                data: data,
                rules: ["balance_infos[0].total_balance", "total_balance", "data.balance"],
                defaultCurrency: preferredCurrency
            )
        }
        let upperPreferred = preferredCurrency.uppercased()
        let selected = infos.first(where: { ($0["currency"] as? String)?.uppercased() == upperPreferred }) ?? infos[0]
        guard let bal = decimalValue(from: selected["total_balance"]) else {
            throw APIBalanceError.parseFailed("balance_infos[0].total_balance")
        }
        let cur = (selected["currency"] as? String) ?? upperPreferred
        return APIBalanceResult(balance: bal, currency: cur)
    }

    func parseOpenRouter(data: Data, defaultCurrency: String) throws -> APIBalanceResult {
        let json = try JSONSerialization.jsonObject(with: data)
        let totalCredits = evaluatePath("data.total_credits", in: json) ?? evaluatePath("total_credits", in: json)
        let totalUsage = evaluatePath("data.total_usage", in: json) ?? evaluatePath("total_usage", in: json) ?? 0
        guard let credits = totalCredits else {
            throw APIBalanceError.parseFailed("data.total_credits")
        }
        return APIBalanceResult(balance: credits - totalUsage, currency: defaultCurrency)
    }

    func parseDividedCandidates(
        data: Data,
        candidatePaths: [String],
        divisor: Decimal,
        currency: String
    ) throws -> APIBalanceResult {
        let json = try JSONSerialization.jsonObject(with: data)
        for path in candidatePaths where !path.isEmpty {
            if let rawVal = evaluatePath(path, in: json) {
                let effective = divisor > 0 ? rawVal / divisor : rawVal
                return APIBalanceResult(balance: effective, currency: currency)
            }
        }
        if let dict = json as? [String: Any] {
            if let msg = (dict["message"] ?? dict["msg"]) as? String,
                !msg.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            {
                throw APIBalanceError.serverMessage(msg)
            }
            if let errObj = dict["error"] as? [String: Any],
                let msg = errObj["message"] as? String,
                !msg.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            {
                throw APIBalanceError.serverMessage(msg)
            }
        }
        throw APIBalanceError.parseFailed(candidatePaths.joined(separator: " / "))
    }

    func parseFirstMatching(
        data: Data,
        rules: [String],
        defaultCurrency: String
    ) throws -> APIBalanceResult {
        let json = try JSONSerialization.jsonObject(with: data)
        for rule in rules where !rule.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let value = evaluateExpression(rule, in: json) {
                return APIBalanceResult(balance: value, currency: defaultCurrency)
            }
        }
        throw APIBalanceError.parseFailed(rules.first(where: { !$0.isEmpty }) ?? "balance")
    }

    func extractDivisor(from rule: String) -> Decimal? {
        let parts = rule.split(separator: "/")
        guard parts.count == 2 else { return nil }
        return Decimal(string: String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func extractCustomPath(from rule: String) -> String? {
        let trimmed = rule.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let slashIdx = trimmed.firstIndex(of: "/") {
            let left = String(trimmed[..<slashIdx]).trimmingCharacters(in: .whitespacesAndNewlines)
            return left.isEmpty ? nil : left
        }
        return trimmed
    }

    private func evaluateExpression(_ expr: String, in json: Any) -> Decimal? {
        let trimmed = expr.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let minusRange = trimmed.range(of: " - ") {
            let left = String(trimmed[..<minusRange.lowerBound])
            let right = String(trimmed[minusRange.upperBound...])
            if let lVal = evaluatePath(left, in: json), let rVal = evaluatePath(right, in: json) {
                return lVal - rVal
            }
        }

        if trimmed.contains("/") {
            let tokens = trimmed.components(separatedBy: "/").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            if tokens.count == 2, let divisor = Decimal(string: tokens[1]), divisor > 0 {
                if let lhs = evaluatePath(tokens[0], in: json) {
                    return lhs / divisor
                }
            } else {
                for candidate in tokens {
                    if let hit = evaluatePath(candidate, in: json) {
                        return hit
                    }
                }
            }
        }

        return evaluatePath(trimmed, in: json)
    }

    private func evaluatePath(_ path: String, in json: Any) -> Decimal? {
        let clean = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        let segments = clean.split(separator: ".").map(String.init)
        var current: Any = json

        for segment in segments {
            if let bracketOpen = segment.firstIndex(of: "["),
                let bracketClose = segment.firstIndex(of: "]"),
                bracketClose > bracketOpen
            {
                let key = String(segment[..<bracketOpen])
                let idxStr = String(segment[segment.index(after: bracketOpen)..<bracketClose])
                guard let idx = Int(idxStr) else { return nil }
                if !key.isEmpty {
                    guard let dict = current as? [String: Any], let next = dict[key] else { return nil }
                    current = next
                }
                guard let arr = current as? [Any], arr.indices.contains(idx) else { return nil }
                current = arr[idx]
            } else {
                guard let dict = current as? [String: Any], let next = dict[segment] else { return nil }
                current = next
            }
        }
        return decimalValue(from: current)
    }

    private func decimalValue(from raw: Any?) -> Decimal? {
        switch raw {
        case let str as String:
            return Decimal(string: str.trimmingCharacters(in: .whitespacesAndNewlines))
        case let num as NSNumber:
            if CFGetTypeID(num) == CFBooleanGetTypeID() { return nil }
            return num.decimalValue
        case let dec as Decimal:
            return dec
        default:
            return nil
        }
    }
}
