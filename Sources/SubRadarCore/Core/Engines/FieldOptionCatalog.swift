import Foundation

/// 编辑器与字段预设选项目录（统一单源维护）
public enum FieldOptionCatalog {
    public static let serverTypes: [String] = [
        "VPS",
        "独立服务器",
        "NAT",
        "虚拟主机",
        "GPU 服务器",
        "容器实例"
    ]

    public static let aliveStatuses: [String] = [
        "正常存活",
        "降智",
        "已封号"
    ]

    public static let accountSources: [String] = [
        "官网直充",
        "渠道代充",
        "第三方合租"
    ]

    public static let requiresDetailAccountSources: Set<String> = [
        "渠道代充",
        "第三方合租"
    ]

    public static let purchaseSources: [String] = [
        "官网直购",
        "App Store",
        "Steam",
        "渠道代充",
        "第三方合租"
    ]

    public static let gpuCounts: [String] = ["1x", "2x", "4x", "8x"]

    public static let gpuModels: [String] = [
        "RTX 4090",
        "RTX 5090",
        "RTX 4080",
        "RTX 3090",
        "H100",
        "H200",
        "A100",
        "L40S",
        "L4",
        "T4",
        "V100",
        "A10G",
        "MI300X"
    ]

    public static let gpuVRAMOptions: [String] = [
        "8G", "12G", "16G", "24G", "32G", "40G", "48G", "80G", "96G", "141G", "192G"
    ]

    public static func defaultVRAM(forGPUModel model: String) -> String {
        switch model {
        case "RTX 5090": return "32G"
        case "RTX 4090", "RTX 3090", "L4", "A10G": return "24G"
        case "RTX 4080", "T4", "V100": return "16G"
        case "L40S": return "48G"
        case "H100", "A100": return "80G"
        case "H200": return "141G"
        case "MI300X": return "192G"
        default: return "24G"
        }
    }

    public static func formatGPUSpec(count: String, model: String, vram: String) -> String {
        let cleanCount = count.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCount: String =
            if cleanCount.isEmpty {
                "1x"
            } else if cleanCount.lowercased().hasSuffix("x") {
                cleanCount.lowercased()
            } else {
                "\(cleanCount)x"
            }
        let cleanModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanVRAM = vram.trimmingCharacters(in: .whitespacesAndNewlines)
        var tokens = [normalizedCount]
        if !cleanModel.isEmpty { tokens.append(cleanModel) }
        if !cleanVRAM.isEmpty { tokens.append(cleanVRAM) }
        if tokens.count == 1 { tokens.append("GPU") }
        return tokens.joined(separator: " ")
    }

    public static let globalRegions: [String] = [
        "中国香港 (HKG / BGP)",
        "中国香港 (HKG / CN2 GIA)",
        "中国台湾 (台北 TPE)",
        "中国澳门 (MFM)",
        "中国内地 (北京 / 上海 / 广州 / 深圳)",
        "日本东京 (NRT)",
        "日本大阪 (KIX)",
        "韩国首尔 (ICN)",
        "新加坡 (SIN)",
        "马来西亚吉隆坡 (KUL)",
        "泰国曼谷 (BKK)",
        "越南胡志明 (SGN)",
        "印尼雅加达 (CGK)",
        "印度孟买 (BOM)",
        "印度新德里 (DEL)",
        "澳大利亚悉尼 (SYD)",
        "澳大利亚墨尔本 (MEL)",
        "新西兰奥克兰 (AKL)",
        "美国圣何塞 (SJC)",
        "美国洛杉矶 (LAX)",
        "美国西雅图 (SEA)",
        "美国旧金山 (SFO)",
        "美国达拉斯 (DFW)",
        "美国芝加哥 (ORD)",
        "美国纽约 / 新泽西 (NYC)",
        "美国阿什本 / 弗吉尼亚 (IAD)",
        "美国迈阿密 (MIA)",
        "加拿大多伦多 (YYZ)",
        "加拿大温哥华 (YVR)",
        "墨西哥城 (MEX)",
        "德国法兰克福 (FRA)",
        "德国纽伦堡 / 赫尔辛基 (DE/FI)",
        "英国伦敦 (LON)",
        "荷兰阿姆斯特丹 (AMS)",
        "法国巴黎 (CDG)",
        "瑞士苏黎世 (ZRH)",
        "意大利米兰 (MXP)",
        "西班牙马德里 (MAD)",
        "波兰华沙 (WAW)",
        "奥地利维也纳 (VIE)",
        "瑞典斯德哥尔摩 (ARN)",
        "芬兰赫尔辛基 (HEL)",
        "爱尔兰都柏林 (DUB)",
        "俄罗斯莫斯科 (MOW)",
        "土耳其伊斯坦布尔 (IST)",
        "阿联酋迪拜 (DXB)",
        "沙特利雅得 (RUH)",
        "以色列特拉维夫 (TLV)",
        "巴西圣保罗 (GRU)",
        "智利圣地亚哥 (SCL)",
        "阿根廷布宜诺斯艾利斯 (EZE)",
        "南非约翰内斯堡 (JNB)",
        "埃及开罗 (CAI)",
        "尼日利亚拉各斯 (LOS)"
    ]
}

public enum OperatingSystemFamily: String, CaseIterable, Identifiable, Sendable {
    case unset = "未设置"
    case linux = "Linux"
    case windows = "Windows"
    case macOS = "macOS"
    case custom = "自定义"

    public var id: String { rawValue }
}

public struct OperatingSystemDistroOption: Hashable, Identifiable, Sendable {
    public let name: String
    public let versions: [String]
    public var id: String { name }

    public init(name: String, versions: [String]) {
        self.name = name
        self.versions = versions
    }
}

extension FieldOptionCatalog {
    public static func osDistros(for family: OperatingSystemFamily) -> [OperatingSystemDistroOption] {
        switch family {
        case .linux:
            return [
                OperatingSystemDistroOption(name: "Rocky Linux", versions: ["9.5", "9.4", "9", "8.10", "8"]),
                OperatingSystemDistroOption(name: "Ubuntu", versions: ["24.04 LTS", "22.04 LTS", "20.04 LTS", "24.10"]),
                OperatingSystemDistroOption(
                    name: "Debian", versions: ["12 (Bookworm)", "11 (Bullseye)", "10 (Buster)", "13 (Trixie)"]),
                OperatingSystemDistroOption(name: "AlmaLinux", versions: ["9.5", "9.4", "9", "8.10", "8"]),
                OperatingSystemDistroOption(name: "CentOS", versions: ["Stream 9", "Stream 10", "7.9", "7"]),
                OperatingSystemDistroOption(name: "RHEL", versions: ["9.5", "9", "8.10", "8"]),
                OperatingSystemDistroOption(name: "Alpine Linux", versions: ["3.21", "3.20", "3.19", "3.18"]),
                OperatingSystemDistroOption(name: "Fedora Server", versions: ["41", "40", "39"]),
                OperatingSystemDistroOption(name: "Arch Linux", versions: ["Rolling"]),
                OperatingSystemDistroOption(name: "openSUSE", versions: ["Leap 15.6", "Tumbleweed"])
            ]
        case .windows:
            return [
                OperatingSystemDistroOption(
                    name: "Windows Server", versions: ["2025", "2022", "2019", "2016", "2012 R2"]),
                OperatingSystemDistroOption(name: "Windows", versions: ["11 Pro", "11 Enterprise", "10 LTSC", "10 Pro"])
            ]
        case .macOS:
            return [
                OperatingSystemDistroOption(
                    name: "macOS", versions: ["15 Sequoia", "14 Sonoma", "13 Ventura", "12 Monterey"])
            ]
        case .unset, .custom:
            return []
        }
    }

    public static func formatOperatingSystem(family: OperatingSystemFamily, distro: String, version: String) -> String {
        switch family {
        case .unset:
            return ""
        case .custom:
            return version.trimmingCharacters(in: .whitespacesAndNewlines)
        case .linux, .windows, .macOS:
            let cleanDistro = distro.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanVersion = version.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanDistro.isEmpty { return cleanVersion }
            if cleanVersion.isEmpty { return cleanDistro }
            return "\(cleanDistro) \(cleanVersion)"
        }
    }

    public static func formatVPSSpec(
        cpuCores: String,
        memoryGB: String,
        storageAmount: String,
        storageUnit: String,
        hasGPU: Bool,
        gpuSpec: String
    ) -> String {
        let cpu = cpuCores.trimmingCharacters(in: .whitespacesAndNewlines)
        let ram = memoryGB.trimmingCharacters(in: .whitespacesAndNewlines)
        let disk = storageAmount.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedGPU = gpuSpec.trimmingCharacters(in: .whitespacesAndNewlines)

        var parts: [String] = []
        if !cpu.isEmpty { parts.append("\(cpu)C") }
        if !ram.isEmpty { parts.append("\(ram)G RAM") }
        if !disk.isEmpty { parts.append("\(disk)\(storageUnit)") }

        if hasGPU {
            if !cleanedGPU.isEmpty { parts.append(cleanedGPU) }
        } else if !parts.isEmpty {
            parts.append("No GPU")
        }

        return parts.joined(separator: " / ")
    }

    public static func formatVPSTraffic(
        bandwidthAmount: String,
        bandwidthUnit: String,
        isLimited: Bool,
        quotaAmount: String,
        quotaUnit: String
    ) -> String {
        let bw = bandwidthAmount.trimmingCharacters(in: .whitespacesAndNewlines)
        let quota = quotaAmount.trimmingCharacters(in: .whitespacesAndNewlines)

        var parts: [String] = []
        if !bw.isEmpty { parts.append("\(bw) \(bandwidthUnit)") }
        if !isLimited {
            parts.append("Unlimited")
        } else if !quota.isEmpty {
            parts.append("\(quota) \(quotaUnit)")
        }

        return parts.joined(separator: " / ")
    }
}
