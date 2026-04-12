// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "ical",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    ],
    targets: [
        .executableTarget(
            name: "ical",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/ical",
            resources: [
                .process("Resources/Info.plist")
            ],
            linkerSettings: [
                .linkedFramework("EventKit"),
            ]
        ),
        .testTarget(
            name: "icalTests",
            dependencies: ["ical"],
            path: "Tests/icalTests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
