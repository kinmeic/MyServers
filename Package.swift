// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MyServers",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.0.0"),
        .package(url: "https://github.com/orlandos-nl/Citadel.git", from: "0.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "MyServers",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm"),
                .product(name: "Citadel", package: "Citadel"),
            ],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        .testTarget(
            name: "MyServersTests",
            dependencies: ["MyServers"]
        ),
    ]
)
