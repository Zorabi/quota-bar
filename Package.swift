// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CodexUsageWidget",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CodexUsageCore", targets: ["CodexUsageCore"]),
        .executable(name: "CodexUsageWidgetApp", targets: ["CodexUsageWidgetApp"]),
        .executable(name: "CodexUsageNativeWidgetExtension", targets: ["CodexUsageNativeWidgetExtension"]),
    ],
    targets: [
        .target(name: "CodexUsageCore"),
        .executableTarget(
            name: "CodexUsageWidgetApp",
            dependencies: ["CodexUsageCore"]
        ),
        .executableTarget(
            name: "CodexUsageNativeWidgetExtension",
            dependencies: ["CodexUsageCore"]
        ),
        .testTarget(
            name: "CodexUsageCoreTests",
            dependencies: ["CodexUsageCore"]
        ),
    ]
)
