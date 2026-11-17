import SubRadarCore
import SwiftUI

struct VPSSpecComposerField: View {
    private static let customSentinel = "__subradar_gpu_custom__"

    @Environment(\.radarPalette) private var palette
    @Binding var value: String

    @State private var cpuCores = ""
    @State private var memoryGB = ""
    @State private var storageAmount = ""
    @State private var storageUnit = "G SSD"
    @State private var hasGPU = false
    @State private var gpuCountChoice = "1x"
    @State private var gpuCustomCount = "1x"
    @State private var gpuModelChoice = "RTX 4090"
    @State private var gpuCustomModel = ""
    @State private var gpuVRAMChoice = "24G"
    @State private var gpuCustomVRAM = ""
    @State private var isReady = false

    private let storageUnits = ["G SSD", "T SSD", "G NVMe", "T NVMe", "G HDD", "T HDD"]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Text("CPU")
                        .font(SubRadarTheme.font(size: 10.5, weight: .semibold))
                        .foregroundStyle(palette.textMuted)
                    RadarTextField("2", text: $cpuCores, monospaced: true)
                        .frame(width: 44)
                    Text("C")
                        .font(SubRadarTheme.font(size: 11, weight: .semibold))
                        .fontDesign(.monospaced)
                        .foregroundStyle(palette.textSecondary)
                }

                HStack(spacing: 4) {
                    Text("RAM")
                        .font(SubRadarTheme.font(size: 10.5, weight: .semibold))
                        .foregroundStyle(palette.textMuted)
                    RadarTextField("4", text: $memoryGB, monospaced: true)
                        .frame(width: 46)
                    Text("G")
                        .font(SubRadarTheme.font(size: 11, weight: .semibold))
                        .fontDesign(.monospaced)
                        .foregroundStyle(palette.textSecondary)
                }

                HStack(spacing: 4) {
                    Text("SSD")
                        .font(SubRadarTheme.font(size: 10.5, weight: .semibold))
                        .foregroundStyle(palette.textMuted)
                    RadarTextField("40", text: $storageAmount, monospaced: true)
                        .frame(width: 50)
                    RadarSelectMenu(
                        options: storageUnits,
                        selection: $storageUnit,
                        label: { $0 }
                    )
                }
            }

            HStack(spacing: 6) {
                Text("GPU")
                    .font(SubRadarTheme.font(size: 10.5, weight: .semibold))
                    .foregroundStyle(palette.textMuted)

                RadarSelectMenu(
                    options: [false, true],
                    selection: $hasGPU,
                    label: { $0 ? "有 GPU" : "No GPU" }
                )

                if hasGPU {
                    RadarSelectMenu(
                        options: FieldOptionCatalog.gpuCounts + [Self.customSentinel],
                        selection: $gpuCountChoice,
                        label: { $0 == Self.customSentinel ? "数量..." : $0 }
                    )

                    RadarSelectMenu(
                        options: FieldOptionCatalog.gpuModels + [Self.customSentinel],
                        selection: Binding(
                            get: { gpuModelChoice },
                            set: { picked in
                                gpuModelChoice = picked
                                if picked != Self.customSentinel {
                                    gpuVRAMChoice = FieldOptionCatalog.defaultVRAM(forGPUModel: picked)
                                }
                            }
                        ),
                        searchable: true,
                        label: { $0 == Self.customSentinel ? "自定义型号..." : $0 }
                    )

                    RadarSelectMenu(
                        options: FieldOptionCatalog.gpuVRAMOptions + [Self.customSentinel],
                        selection: $gpuVRAMChoice,
                        label: { $0 == Self.customSentinel ? "自定义显存..." : $0 }
                    )
                }

                Spacer(minLength: 0)
            }

            if hasGPU
                && (gpuCountChoice == Self.customSentinel
                    || gpuModelChoice == Self.customSentinel
                    || gpuVRAMChoice == Self.customSentinel)
            {
                HStack(spacing: 6) {
                    if gpuCountChoice == Self.customSentinel {
                        RadarTextField("数量（如 16x）", text: $gpuCustomCount, monospaced: true)
                            .frame(width: 96)
                    }
                    if gpuModelChoice == Self.customSentinel {
                        RadarTextField("显卡型号（如 RTX 4090 / B200）", text: $gpuCustomModel, monospaced: true)
                    }
                    if gpuVRAMChoice == Self.customSentinel {
                        RadarTextField("显存（如 48G）", text: $gpuCustomVRAM, monospaced: true)
                            .frame(width: 104)
                    }
                }
            }

            if !formattedSpec.isEmpty {
                Text("已格式化：\(formattedSpec)")
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
        .onChange(of: formattedSpec) { _, newValue in
            if isReady { value = newValue }
        }
    }

    private var formattedSpec: String {
        let gpuText: String =
            if hasGPU {
                FieldOptionCatalog.formatGPUSpec(
                    count: gpuCountChoice == Self.customSentinel ? gpuCustomCount : gpuCountChoice,
                    model: gpuModelChoice == Self.customSentinel ? gpuCustomModel : gpuModelChoice,
                    vram: gpuVRAMChoice == Self.customSentinel ? gpuCustomVRAM : gpuVRAMChoice
                )
            } else {
                ""
            }
        return FieldOptionCatalog.formatVPSSpec(
            cpuCores: cpuCores,
            memoryGB: memoryGB,
            storageAmount: storageAmount,
            storageUnit: storageUnit,
            hasGPU: hasGPU,
            gpuSpec: gpuText
        )
    }

    private func parseInitialValue() {
        let parts = value.split(separator: "/").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard !parts.isEmpty else { return }
        for part in parts {
            let lower = part.lowercased()
            if lower.hasSuffix("c"), let num = Int(part.dropLast().trimmingCharacters(in: .whitespaces)) {
                cpuCores = String(num)
            } else if lower.contains("ram") {
                let digits = part.prefix { $0.isNumber || $0 == "." }
                if !digits.isEmpty { memoryGB = String(digits) }
            } else if lower.contains("nvme") || lower.contains("ssd") || lower.contains("hdd") {
                let digits = part.prefix { $0.isNumber || $0 == "." }
                if !digits.isEmpty { storageAmount = String(digits) }
                let rest = String(part.dropFirst(digits.count)).trimmingCharacters(in: .whitespaces)
                if let matchedUnit = storageUnits.first(where: { $0.caseInsensitiveCompare(rest) == .orderedSame }) {
                    storageUnit = matchedUnit
                }
            } else if lower.contains("no gpu") {
                hasGPU = false
            } else if lower.contains("rtx") || lower.contains("gpu") || lower.contains("a100") || lower.contains("h100")
                || lower.contains("h200") || lower.contains("t4") || lower.contains("l4") || lower.contains("v100")
                || lower.contains("mi300") || lower.contains("a10g")
            {
                hasGPU = true
                parseGPUPart(part)
            }
        }
    }

    private func parseGPUPart(_ part: String) {
        let tokens = part.split(separator: " ").map(String.init)
        guard !tokens.isEmpty else { return }
        var remaining = tokens
        if let first = remaining.first, first.lowercased().hasSuffix("x") {
            if FieldOptionCatalog.gpuCounts.contains(first.lowercased()) {
                gpuCountChoice = first.lowercased()
            } else {
                gpuCountChoice = Self.customSentinel
                gpuCustomCount = first
            }
            remaining.removeFirst()
        }
        if let last = remaining.last, last.lowercased().hasSuffix("g") || last.lowercased().hasSuffix("gb") {
            let cleanVRAM = last.uppercased().replacingOccurrences(of: "GB", with: "G")
            if FieldOptionCatalog.gpuVRAMOptions.contains(cleanVRAM) {
                gpuVRAMChoice = cleanVRAM
            } else {
                gpuVRAMChoice = Self.customSentinel
                gpuCustomVRAM = last
            }
            remaining.removeLast()
        }
        let modelStr = remaining.joined(separator: " ")
        if !modelStr.isEmpty {
            if let matchedModel = FieldOptionCatalog.gpuModels.first(where: {
                $0.caseInsensitiveCompare(modelStr) == .orderedSame
            }) {
                gpuModelChoice = matchedModel
            } else {
                gpuModelChoice = Self.customSentinel
                gpuCustomModel = modelStr
            }
        }
    }
}
