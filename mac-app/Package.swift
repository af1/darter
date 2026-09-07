// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Darter",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Darter",
            path: "Sources/Darter"
        ),
        .testTarget(
            name: "DarterTests",
            dependencies: ["Darter"],
            path: "Tests/DarterTests"
        )
    ]
)
