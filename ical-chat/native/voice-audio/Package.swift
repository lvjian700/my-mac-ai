// swift-tools-version: 6.3
import PackageDescription

let package = Package(
  name: "VoiceAudio",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .library(
      name: "VoiceAudioProtocol",
      targets: ["VoiceAudioProtocol"]
    ),
    .executable(
      name: "cali-voice-audio",
      targets: ["CaliVoiceAudio"]
    ),
  ],
  targets: [
    .target(
      name: "VoiceAudioProtocol",
      path: "Sources/VoiceAudioProtocol"
    ),
    .executableTarget(
      name: "CaliVoiceAudio",
      dependencies: ["VoiceAudioProtocol"],
      path: "Sources/cali-voice-audio",
      exclude: ["Resources/Info.plist"],
      linkerSettings: [
        .linkedFramework("AVFoundation"),
        .unsafeFlags([
          "-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist",
          "-Xlinker", "Sources/cali-voice-audio/Resources/Info.plist",
        ]),
      ]
    ),
    .testTarget(
      name: "VoiceAudioProtocolTests",
      dependencies: ["VoiceAudioProtocol"],
      path: "Tests/VoiceAudioProtocolTests"
    ),
  ],
  swiftLanguageModes: [.v6]
)
