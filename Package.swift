// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "MacSweeper",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(name: "MacSweeperKit", targets: ["MacSweeperKit"]),
        .executable(name: "MacSweeperCLI", targets: ["MacSweeperCLI"]),
        .executable(name: "MacSweeperApp", targets: ["MacSweeperApp"])
    ],
    dependencies: [
        // 使用系统自带的 CryptoKit，无需外部依赖
    ],
    targets: [
        .target(
            name: "MacSweeperKit",
            dependencies: [],
            path: "Sources/MacSweeperKit"
        ),
        .executableTarget(
            name: "MacSweeperCLI",
            dependencies: ["MacSweeperKit"],
            path: "Sources/MacSweeperCLI"
        ),
        .executableTarget(
            name: "MacSweeperApp",
            dependencies: ["MacSweeperKit"],
            path: "Sources/MacSweeperApp"
        )
    ]
)
