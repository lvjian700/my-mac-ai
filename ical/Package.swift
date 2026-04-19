// swift-tools-version: 6.3
import PackageDescription

let package = Package(
  name: "ical",
  platforms: [
    .macOS(.v14)
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0")
  ],
  targets: [
    .executableTarget(
      name: "ical",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser")
      ],
      path: "Sources/ical",
      linkerSettings: [
        .linkedFramework("EventKit"),
        .unsafeFlags([
          "-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist", "-Xlinker",
          "Sources/ical/Resources/Info.plist",
        ]),
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
