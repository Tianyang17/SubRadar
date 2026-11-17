// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SubRadar",
    defaultLocalization: "zh-Hans",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SubRadarCore",
            targets: ["SubRadarCore"]
        ),
        .executable(
            name: "SubRadarApp",
            targets: ["SubRadarApp"]
        )
    ],
    targets: [
        .target(
            name: "SubRadarCore",
            path: "Sources/SubRadarCore",
            resources: [
                .copy("Resources/PresetIcons")
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .executableTarget(
            name: "SubRadarApp",
            dependencies: ["SubRadarCore"],
            path: "Sources/SubRadarApp"
        ),
        .testTarget(
            name: "SubRadarCoreTests",
            dependencies: ["SubRadarCore"],
            path: "Tests/SubRadarCoreTests"
        )
    ]
)
