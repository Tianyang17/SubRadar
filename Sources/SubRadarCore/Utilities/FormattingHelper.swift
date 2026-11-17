import Foundation

/// 统一金额、货币、日期与倒计时格式化工具（DRY 单一数据源）
public enum SubRadarFormatter {
    public static func formatMoney(_ amount: Decimal, currency: String) -> String {
        let symbol = CommonCurrency.symbol(for: currency)
        let number = NSDecimalNumber(decimal: amount)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let formatted = formatter.string(from: number) ?? number.stringValue
        return "\(symbol)\(formatted)"
    }

    public static func formatCompactMoney(_ amount: Decimal, currency: String) -> String {
        let symbol = CommonCurrency.symbol(for: currency)
        let number = NSDecimalNumber(decimal: amount)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        let formatted = formatter.string(from: number) ?? number.stringValue
        return "\(symbol)\(formatted)"
    }

    public static func formatDate(_ date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 2026,
            components.month ?? 1,
            components.day ?? 1
        )
    }

    /// 解析用户手动输入的日期字符串（支持 YYYY-MM-DD、YYYY/M/D、YYYY.M.D、YYYYMMDD），严格校验真实日历有效性与年份范围
    public static func parseDateInput(_ raw: String, calendar: Calendar = .current) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let parts: [String]
        if trimmed.count == 8, trimmed.allSatisfy(\.isNumber) {
            let y = String(trimmed.prefix(4))
            let mStart = trimmed.index(trimmed.startIndex, offsetBy: 4)
            let mEnd = trimmed.index(mStart, offsetBy: 2)
            parts = [y, String(trimmed[mStart..<mEnd]), String(trimmed[mEnd...])]
        } else {
            let separators = CharacterSet(charactersIn: "-/.")
            parts = trimmed.components(separatedBy: separators).filter { !$0.isEmpty }
        }

        guard parts.count == 3,
            parts[0].count == 4,
            let year = Int(parts[0]),
            let month = Int(parts[1]),
            let day = Int(parts[2])
        else {
            return nil
        }
        return validatedDate(year: year, month: month, day: day, calendar: calendar)
    }

    /// 解析日历左上角手输年月并返回当月首日
    public static func resolveYearMonth(
        yearText: String,
        monthText: String,
        calendar: Calendar = .current
    ) -> Date? {
        let trimmedYear = yearText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMonth = monthText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedYear.count == 4,
            let year = Int(trimmedYear),
            let month = Int(trimmedMonth)
        else {
            return nil
        }
        return validatedDate(year: year, month: month, day: 1, calendar: calendar)
    }

    private static func validatedDate(year: Int, month: Int, day: Int, calendar: Calendar) -> Date? {
        guard (1900...2100).contains(year), (1...12).contains(month), (1...31).contains(day) else {
            return nil
        }
        var components = DateComponents()
        components.calendar = calendar
        components.year = year
        components.month = month
        components.day = day
        guard let date = calendar.date(from: components) else { return nil }
        let verified = calendar.dateComponents([.year, .month, .day], from: date)
        guard verified.year == year, verified.month == month, verified.day == day else {
            return nil
        }
        return calendar.startOfDay(for: date)
    }

    public static func renewalCountdownText(for item: SubscriptionItem, referenceDate: Date = Date()) -> String {
        if item.billingCycleType == .oneTime {
            return "永久买断"
        }
        let days = item.daysUntilRenewal(referenceDate: referenceDate)
        if days < 0 {
            return "已逾期 \(-days) 天"
        } else if days == 0 {
            return "今日到期"
        } else {
            return "\(days) 天后到期"
        }
    }

    public static func normalizedWebURL(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(where: \.isWhitespace) else { return nil }

        let candidate: String
        if let schemeRange = trimmed.range(of: "://") {
            let scheme = trimmed[..<schemeRange.lowerBound].lowercased()
            guard scheme == "http" || scheme == "https" else { return nil }
            candidate = trimmed
        } else {
            guard !trimmed.contains(":") else { return nil }
            candidate = "https://\(trimmed)"
        }

        guard let components = URLComponents(string: candidate),
            let scheme = components.scheme?.lowercased(),
            scheme == "http" || scheme == "https",
            let host = components.host,
            host.contains(".") || host.caseInsensitiveCompare("localhost") == .orderedSame
        else {
            return nil
        }
        return components.url
    }

    public static func formatGroupedCurrencySummary(_ totals: [(currency: String, amount: Decimal)]) -> String {
        totals.map { item in
            if item.amount < 0 {
                return "-\(formatMoney(-item.amount, currency: item.currency))"
            }
            return formatMoney(item.amount, currency: item.currency)
        }
        .joined(separator: " + ")
    }
}
