// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "ical-mac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "ICalMacCore", targets: ["ICalMacCore"]),
        .library(name: "ICalMacUI", targets: ["ICalMacUI"]),
        .executable(name: "ical-mac", targets: ["ICalMacApp"]),
    ],
    targets: [
        .target(
            name: "ICalMacCore",
            path: "Sources/ICalMacCore",
            linkerSettings: [
                .linkedFramework("EventKit"),
                .linkedFramework("Security"),
            ]
        ),
        .target(
            name: "ICalMacUI",
            dependencies: ["ICalMacCore"],
            path: "Sources/ICalMacUI"
        ),
        .executableTarget(
            name: "ICalMacApp",
            dependencies: ["ICalMacUI"],
            path: "Sources/ICalMacApp",
            resources: [
                .process("../../Resources")
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .unsafeFlags([
                    "-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist", "-Xlinker",
                    "Resources/Info.plist",
                ]),
            ]
        ),
        .testTarget(
            name: "ICalMacCoreTests",
            dependencies: ["ICalMacCore"],
            path: "Tests/ICalMacCoreTests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
