import Foundation

/// 基于 Frankfurter + fawazahmed0 双源与 SQLite 永久按日缓存的汇率服务
public final class ExchangeRateService: ExchangeRateServiceProtocol, Sendable {
    private let database: SQLiteDatabase
    private let session: URLSession

    /// 无网络且从未缓存过时的静态兜底基准汇率（兑换为 CNY）
    private static let fallbackRatesToCNY: [String: Double] = [
        "CNY": 1.0,
        "USD": 7.20,
        "EUR": 7.80,
        "HKD": 0.92,
        "JPY": 0.048,
        "GBP": 9.15,
        "SGD": 5.38,
        "CAD": 5.15,
        "AUD": 4.70
    ]

    public init(database: SQLiteDatabase, session: URLSession? = nil) {
        self.database = database
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 8
            config.timeoutIntervalForResource = 12
            self.session = URLSession(configuration: config)
        }
    }

    public func rate(from currency: String, to baseCurrency: String, on date: Date) async -> Decimal {
        let src = currency.uppercased()
        let dst = baseCurrency.uppercased()
        if src == dst { return 1 }

        let dateKey = Self.dateString(from: min(date, Date()))

        // 1. 优先查 SQLite 本地永久缓存
        if let cached = try? await loadCachedRate(from: src, to: dst, on: dateKey) {
            return Decimal(cached)
        }

        // 2. 主源：Frankfurter API（按具体日期查询）
        if let rate = await fetchFromFrankfurter(from: src, to: dst, dateString: dateKey) {
            try? await saveCachedRate(from: src, to: dst, on: dateKey, rate: rate)
            return Decimal(rate)
        }

        // 3. 备源：fawazahmed0 CDN 静态托管（支持 200+ 币种）
        if let rate = await fetchFromFawazCDN(from: src, to: dst, dateString: dateKey) {
            try? await saveCachedRate(from: src, to: dst, on: dateKey, rate: rate)
            return Decimal(rate)
        }

        // 4. 降级读取该币种最近一次本地缓存的汇率
        if let latestCached = try? await loadLatestCachedRate(from: src, to: dst) {
            return Decimal(latestCached)
        }

        // 5. 最终静态离线兜底
        return Decimal(Self.staticFallbackRate(from: src, to: dst))
    }

    public func prefetchRates(from currency: String, to baseCurrency: String, startDate: Date, endDate: Date) async {
        let src = currency.uppercased()
        let dst = baseCurrency.uppercased()
        guard src != dst else { return }

        let clampedEnd = min(endDate, Date())
        let clampedStart = min(startDate, clampedEnd)
        let startStr = Self.dateString(from: clampedStart)
        let endStr = Self.dateString(from: clampedEnd)

        guard let url = URL(string: "https://api.frankfurter.dev/\(startStr)..\(endStr)?from=\(src)&to=\(dst)") else {
            return
        }

        struct RangeResponse: Decodable {
            let rates: [String: [String: Double]]
        }

        guard let (data, response) = try? await session.data(from: url),
            (response as? HTTPURLResponse)?.statusCode == 200,
            let decoded = try? JSONDecoder().decode(RangeResponse.self, from: data)
        else {
            return
        }

        let now = Date().timeIntervalSince1970
        let pairs: [(String, Double)] = decoded.rates.compactMap { dateKey, map in
            guard let rate = map[dst] else { return nil }
            return (dateKey, rate)
        }
        guard !pairs.isEmpty else { return }

        try? await database.performTransaction { conn in
            for (dateKey, rate) in pairs {
                try conn.execute(
                    """
                    INSERT OR REPLACE INTO exchange_rates (currency_code, rate_date, base_currency, rate_to_base, updated_at)
                    VALUES (?, ?, ?, ?, ?);
                    """,
                    bindings: [
                        .text(src),
                        .text(dateKey),
                        .text(dst),
                        .double(rate),
                        .double(now)
                    ]
                )
            }
        }
    }

    // MARK: - SQLite Cache Helpers

    private func loadCachedRate(from src: String, to dst: String, on dateKey: String) async throws -> Double? {
        let rows = try await database.query(
            """
            SELECT rate_to_base FROM exchange_rates
            WHERE currency_code = ? AND rate_date = ? AND base_currency = ?
            LIMIT 1;
            """,
            bindings: [.text(src), .text(dateKey), .text(dst)]
        )
        return rows.first?.double("rate_to_base")
    }

    private func loadLatestCachedRate(from src: String, to dst: String) async throws -> Double? {
        let rows = try await database.query(
            """
            SELECT rate_to_base FROM exchange_rates
            WHERE currency_code = ? AND base_currency = ?
            ORDER BY rate_date DESC
            LIMIT 1;
            """,
            bindings: [.text(src), .text(dst)]
        )
        return rows.first?.double("rate_to_base")
    }

    private func saveCachedRate(from src: String, to dst: String, on dateKey: String, rate: Double) async throws {
        try await database.execute(
            """
            INSERT OR REPLACE INTO exchange_rates (currency_code, rate_date, base_currency, rate_to_base, updated_at)
            VALUES (?, ?, ?, ?, ?);
            """,
            bindings: [
                .text(src),
                .text(dateKey),
                .text(dst),
                .double(rate),
                .double(Date().timeIntervalSince1970)
            ]
        )
    }

    // MARK: - Network Fetchers

    private func fetchFromFrankfurter(from src: String, to dst: String, dateString: String) async -> Double? {
        guard let url = URL(string: "https://api.frankfurter.dev/\(dateString)?from=\(src)&to=\(dst)") else {
            return nil
        }
        struct SingleResponse: Decodable {
            let rates: [String: Double]
        }
        guard let (data, response) = try? await session.data(from: url),
            (response as? HTTPURLResponse)?.statusCode == 200,
            let decoded = try? JSONDecoder().decode(SingleResponse.self, from: data)
        else {
            return nil
        }
        return decoded.rates[dst]
    }

    private func fetchFromFawazCDN(from src: String, to dst: String, dateString: String) async -> Double? {
        let lowerSrc = src.lowercased()
        let lowerDst = dst.lowercased()
        let urls = [
            "https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@\(dateString)/v1/currencies/\(lowerSrc).min.json",
            "https://\(dateString).currency-api.pages.dev/v1/currencies/\(lowerSrc).min.json",
            "https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/\(lowerSrc).min.json"
        ]

        for urlStr in urls {
            guard let url = URL(string: urlStr),
                let (data, response) = try? await session.data(from: url),
                (response as? HTTPURLResponse)?.statusCode == 200,
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let map = json[lowerSrc] as? [String: Any],
                let value = map[lowerDst] as? Double
            else {
                continue
            }
            return value
        }
        return nil
    }

    // MARK: - Utilities

    public static func staticFallbackRate(from src: String, to dst: String) -> Double {
        let srcToCNY = fallbackRatesToCNY[src.uppercased()] ?? 1.0
        let dstToCNY = fallbackRatesToCNY[dst.uppercased()] ?? 1.0
        guard dstToCNY > 0 else { return 1.0 }
        return srcToCNY / dstToCNY
    }

    public static func dateString(from date: Date) -> String {
        let components = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)
        let y = components.year ?? 2026
        let m = components.month ?? 1
        let d = components.day ?? 1
        return String(format: "%04d-%02d-%02d", y, m, d)
    }
}
