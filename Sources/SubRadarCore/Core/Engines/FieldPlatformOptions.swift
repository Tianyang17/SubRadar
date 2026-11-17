import Foundation

extension FieldOptionCatalog {
    public static let softwarePlatforms: [String] = [
        "Mac",
        "iPhone",
        "iPad",
        "Android",
        "Windows",
        "Linux"
    ]

    public static func parsedPlatforms(from raw: String) -> [String] {
        let tokens =
            raw
            .replacingOccurrences(of: "、", with: "/")
            .replacingOccurrences(of: ",", with: "/")
            .split(separator: "/")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var seen = Set<String>()
        return tokens.filter { seen.insert($0).inserted }
    }

    public static func formatPlatforms(_ selected: Set<String>) -> String {
        let knownOrder = softwarePlatforms.filter { selected.contains($0) }
        let extra = selected.filter { !softwarePlatforms.contains($0) }.sorted()
        return (knownOrder + extra).joined(separator: " / ")
    }

    public static func togglingPlatform(_ platform: String, in currentValue: String) -> String {
        var current = Set(parsedPlatforms(from: currentValue))
        if current.contains(platform) {
            current.remove(platform)
        } else {
            current.insert(platform)
        }
        return formatPlatforms(current)
    }
}
