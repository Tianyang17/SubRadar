import SubRadarCore
import SwiftUI

struct VPSTrafficComposerField: View {
    @Environment(\.radarPalette) private var palette
    @Binding var value: String

    @State private var bandwidthAmount = ""
    @State private var bandwidthUnit = "Mbps"
    @State private var isLimited = true
    @State private var quotaAmount = ""
    @State private var quotaUnit = "TB/mo"
    @State private var isReady = false

    private let bandwidthUnits = ["Mbps", "Gbps"]
    private let quotaUnits = ["GB/mo", "TB/mo"]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                HStack(spacing: 4) {
                    Text("BW")
                        .font(SubRadarTheme.font(size: 10.5, weight: .semibold))
                        .foregroundStyle(palette.textMuted)
                    RadarTextField("1000", text: $bandwidthAmount, monospaced: true)
                        .frame(width: 58)
                    RadarSelectMenu(
                        options: bandwidthUnits,
                        selection: $bandwidthUnit,
                        label: { $0 }
                    )
                }

                RadarSelectMenu(
                    options: [false, true],
                    selection: $isLimited,
                    label: { $0 ? "限额流量" : "Unlimited" }
                )

                if isLimited {
                    HStack(spacing: 4) {
                        RadarTextField("1", text: $quotaAmount, monospaced: true)
                            .frame(width: 52)
                        RadarSelectMenu(
                            options: quotaUnits,
                            selection: $quotaUnit,
                            label: { $0 }
                        )
                    }
                } else {
                    Spacer(minLength: 0)
                }
            }

            if !formattedTraffic.isEmpty {
                Text("已格式化：\(formattedTraffic)")
                    .font(SubRadarTheme.font(size: 10.5))
                    .fontDesign(.monospaced)
                    .foregroundStyle(palette.textMuted)
                    .lineLimit(1)
            }
        }
        .onAppear {
            parseInitialValue()
            isReady = true
        }
        .onChange(of: bandwidthAmount) { _, _ in syncIfReady() }
        .onChange(of: bandwidthUnit) { _, _ in syncIfReady() }
        .onChange(of: isLimited) { _, _ in syncIfReady() }
        .onChange(of: quotaAmount) { _, _ in syncIfReady() }
        .onChange(of: quotaUnit) { _, _ in syncIfReady() }
    }

    private var formattedTraffic: String {
        FieldOptionCatalog.formatVPSTraffic(
            bandwidthAmount: bandwidthAmount,
            bandwidthUnit: bandwidthUnit,
            isLimited: isLimited,
            quotaAmount: quotaAmount,
            quotaUnit: quotaUnit
        )
    }

    private func syncIfReady() {
        guard isReady else { return }
        value = formattedTraffic
    }

    private func parseInitialValue() {
        let parts = value.split(separator: "/").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard !parts.isEmpty else { return }
        for part in parts {
            let lower = part.lowercased()
            if lower.contains("mbps") || lower.contains("gbps") {
                let digits = part.prefix { $0.isNumber || $0 == "." }
                if !digits.isEmpty { bandwidthAmount = String(digits) }
                bandwidthUnit = lower.contains("gbps") ? "Gbps" : "Mbps"
            } else if lower.contains("unlimited") || lower.contains("不限") {
                isLimited = false
            } else if lower.contains("gb") || lower.contains("tb") {
                isLimited = true
                let digits = part.prefix { $0.isNumber || $0 == "." }
                if !digits.isEmpty { quotaAmount = String(digits) }
                quotaUnit = lower.contains("tb") ? "TB/mo" : "GB/mo"
            }
        }
    }
}

struct VPSOperatingSystemComposerField: View {
    private static let customVersionSentinel = "__subradar_os_custom_ver__"

    @Environment(\.radarPalette) private var palette
    @Binding var value: String

    @State private var family: OperatingSystemFamily = .unset
    @State private var distroName: String = ""
    @State private var versionChoice: String = ""
    @State private var customText: String = ""
    @State private var isReady = false

    private var availableDistros: [OperatingSystemDistroOption] {
        FieldOptionCatalog.osDistros(for: family)
    }

    private var currentDistroVersions: [String] {
        availableDistros.first(where: { $0.name == distroName })?.versions ?? []
    }

    private var versionOptions: [String] {
        currentDistroVersions + [Self.customVersionSentinel]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                RadarSelectMenu(
                    options: OperatingSystemFamily.allCases,
                    selection: Binding(
                        get: { family },
                        set: { selectFamily($0) }
                    ),
                    label: { $0.rawValue }
                )

                if family == .linux || family == .windows {
                    RadarSelectMenu(
                        options: availableDistros.map(\.name),
                        selection: Binding(
                            get: { distroName },
                            set: { selectDistro($0) }
                        ),
                        label: { $0 }
                    )
                }

                if family == .linux || family == .windows || family == .macOS {
                    RadarSelectMenu(
                        options: versionOptions,
                        selection: $versionChoice,
                        label: { item in
                            item == Self.customVersionSentinel ? "其他版本..." : item
                        }
                    )
                }

                Spacer(minLength: 0)
            }

            if family == .custom {
                RadarTextField("如 FreeBSD 14.2 / Synology DSM 7.2 / 自定义系统", text: $customText)
            } else if versionChoice == Self.customVersionSentinel {
                RadarTextField("输入系统版本号（如 9.6 / 24.04.2 / 2025）", text: $customText)
            } else if family != .unset {
                Text("已选择：\(formattedValue)")
                    .font(SubRadarTheme.font(size: 10.5))
                    .fontDesign(.monospaced)
                    .foregroundStyle(palette.textMuted)
                    .lineLimit(1)
            }
        }
        .onAppear {
            parseInitialValue()
            isReady = true
        }
        .onChange(of: versionChoice) { _, _ in syncIfReady() }
        .onChange(of: customText) { _, _ in syncIfReady() }
    }

    private var formattedValue: String {
        let resolvedVersion = versionChoice == Self.customVersionSentinel ? customText : versionChoice
        return FieldOptionCatalog.formatOperatingSystem(
            family: family,
            distro: distroName,
            version: resolvedVersion
        )
    }

    private func selectFamily(_ newFamily: OperatingSystemFamily) {
        family = newFamily
        switch newFamily {
        case .unset:
            distroName = ""
            versionChoice = ""
            customText = ""
        case .custom:
            distroName = ""
            versionChoice = ""
        case .linux, .windows, .macOS:
            let distros = FieldOptionCatalog.osDistros(for: newFamily)
            let firstDistro = distros.first
            distroName = firstDistro?.name ?? ""
            versionChoice = firstDistro?.versions.first ?? Self.customVersionSentinel
            customText = ""
        }
        syncIfReady()
    }

    private func selectDistro(_ newDistro: String) {
        distroName = newDistro
        let versions = availableDistros.first(where: { $0.name == newDistro })?.versions ?? []
        versionChoice = versions.first ?? Self.customVersionSentinel
        customText = ""
        syncIfReady()
    }

    private func syncIfReady() {
        guard isReady else { return }
        value = formattedValue
    }

    private func parseInitialValue() {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            family = .unset
            return
        }
        let lower = trimmed.lowercased()
        let familiesToSearch: [OperatingSystemFamily] = [.linux, .windows, .macOS]
        for candidateFamily in familiesToSearch {
            let distros = FieldOptionCatalog.osDistros(for: candidateFamily)
                .sorted { $0.name.count > $1.name.count }
            for option in distros where lower.hasPrefix(option.name.lowercased()) {
                family = candidateFamily
                distroName = option.name
                let remainder = String(trimmed.dropFirst(option.name.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if remainder.isEmpty {
                    versionChoice = option.versions.first ?? Self.customVersionSentinel
                } else if let matchedVersion = option.versions.first(where: {
                    $0.caseInsensitiveCompare(remainder) == .orderedSame
                }) {
                    versionChoice = matchedVersion
                } else {
                    versionChoice = Self.customVersionSentinel
                    customText = remainder
                }
                return
            }
        }
        family = .custom
        customText = trimmed
    }
}
