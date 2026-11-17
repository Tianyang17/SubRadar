import Foundation

/// 内置国内外常用软件/服务预置库（不依赖外网，开箱即用；分组内遵循英文 A–Z 在前、中文拼音 A–Z 在后）
public enum PopularSoftwarePresetManager {
    private static var rawPresets: [PopularSoftwarePreset] {
        aiAndApiPresets + productivityPresets + mediaPresets + cloudAndInfraPresets
    }

    /// 按六大分组顺序 + 分组内「英文 A–Z 在前、中文拼音 A–Z 在后」稳定排序后的全量预置
    public static let allPresets: [PopularSoftwarePreset] = sortedByGroupAndName(rawPresets)

    public static func sortKey(for name: String) -> (bucket: Int, normalized: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let firstScalar = trimmed.unicodeScalars.first else {
            return (0, "")
        }
        let isEnglishLeading = firstScalar.isASCII
        if isEnglishLeading {
            return (0, trimmed.lowercased())
        }
        let mutable = NSMutableString(string: trimmed)
        CFStringTransform(mutable, nil, kCFStringTransformToLatin, false)
        CFStringTransform(mutable, nil, kCFStringTransformStripDiacritics, false)
        let latin = (mutable as String)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
        return (1, latin)
    }

    public static func sortedByGroupAndName(_ presets: [PopularSoftwarePreset]) -> [PopularSoftwarePreset] {
        let groupRank = Dictionary(uniqueKeysWithValues: PopularSoftwareGroup.allCases.enumerated().map { ($1, $0) })
        return presets.sorted { lhs, rhs in
            let lGroup = groupRank[lhs.group] ?? 0
            let rGroup = groupRank[rhs.group] ?? 0
            if lGroup != rGroup {
                return lGroup < rGroup
            }
            let lKey = sortKey(for: lhs.name)
            let rKey = sortKey(for: rhs.name)
            if lKey.bucket != rKey.bucket {
                return lKey.bucket < rKey.bucket
            }
            if lKey.normalized != rKey.normalized {
                return lKey.normalized.localizedStandardCompare(rKey.normalized) == .orderedAscending
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    public static func bundledIconData(for preset: PopularSoftwarePreset) -> Data? {
        bundledIconData(forPresetId: preset.id)
    }

    public static func bundledIconData(forPresetId id: String) -> Data? {
        guard let bundle = ResourceBundleLocator.core,
            let url = bundle.url(forResource: id, withExtension: "png", subdirectory: "PresetIcons")
        else {
            return nil
        }
        return try? Data(contentsOf: url)
    }

    public static func search(query: String) -> [PopularSoftwarePreset] {
        groupedPresets(query: query, groupFilter: nil)
    }

    public static func groupedPresets(
        query: String,
        groupFilter: PopularSoftwareGroup?
    ) -> [PopularSoftwarePreset] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = allPresets.filter { preset in
            if let groupFilter, preset.group != groupFilter {
                return false
            }
            guard !trimmed.isEmpty else { return true }
            return preset.name.lowercased().contains(trimmed)
                || preset.websiteDomain.lowercased().contains(trimmed)
                || preset.group.rawValue.lowercased().contains(trimmed)
                || preset.aliases.contains(where: { $0.lowercased().contains(trimmed) })
        }
        return sortedByGroupAndName(filtered)
    }
}
