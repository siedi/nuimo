// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NuimoBar",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/LebJe/TOMLKit", from: "0.6.0")
    ],
    targets: [
        .executableTarget(
            name: "NuimoBar",
            dependencies: ["TOMLKit"]
        ),
        .testTarget(
            name: "NuimoBarTests",
            dependencies: ["NuimoBar"]
        ),
    ]
)
