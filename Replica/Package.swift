// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GenErikDJ",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "TDJCore", targets: ["TDJCore"]),
        .library(name: "TDJInterface", targets: ["TDJInterface"]),
        .library(name: "TDJRuntimeChecks", targets: ["TDJRuntimeChecks"]),
        .executable(name: "tdj-preview", targets: ["TDJPreview"]),
        .executable(name: "tdj-tool", targets: ["TDJTool"]),
        .executable(name: "tdj-runtime-validation", targets: ["TDJRuntimeValidation"]),
        .executable(name: "tdj-audio-check-preview", targets: ["TDJAudioCheckPreview"])
    ],
    targets: [
        .target(name: "CTDJTransport", exclude: ["Vendor/signalsmith-stretch/README.md", "Vendor/signalsmith-stretch/LICENSE.txt",
            "Vendor/signalsmith-linear/README.md", "Vendor/signalsmith-linear/LICENSE.txt"],
            cSettings: [.unsafeFlags(["-O3"])],
            cxxSettings: [.headerSearchPath("Vendor"), .unsafeFlags(["-O3"])], linkerSettings: [.linkedFramework("Accelerate")]),
        .target(name: "CTDJAudioSource", dependencies: ["CTDJTransport"],
                cxxSettings: [.unsafeFlags(["-O3", "-fobjc-arc"])],
                linkerSettings: [.linkedFramework("AVFoundation"), .linkedFramework("Foundation")]),
        .target(name: "TDJCore", dependencies: ["CTDJTransport"]),
        .target(name: "TDJInterface", dependencies: ["TDJCore", "CTDJAudioSource"],
                resources: [.process("Resources"), .copy("StemModelAssets")]),
        .executableTarget(name: "TDJPreview", dependencies: ["TDJInterface", "TDJCore"]),
        .executableTarget(name: "TDJTool", dependencies: ["TDJCore"]),
        .target(name: "TDJRuntimeChecks", dependencies: ["TDJCore", "TDJInterface"]),
        .executableTarget(name: "TDJRuntimeValidation", dependencies: ["TDJRuntimeChecks"]),
        .executableTarget(name: "TDJAudioCheckPreview", dependencies: ["TDJRuntimeChecks"],
            path: "iPadValidation",
            exclude: ["AudioCheckApp.swift", "Info.plist", "GenErikDJAudioCheck.xcodeproj", "README.md"],
            sources: ["AudioCheckModel.swift", "AudioCheckView.swift", "Preview/RenderPreview.swift"]),
        .testTarget(name: "TDJCoreTests", dependencies: ["TDJCore"], resources: [.copy("Fixtures")]),
        .testTarget(name: "TDJInterfaceTests", dependencies: ["TDJCore", "TDJInterface"]),
        .testTarget(name: "TDJRuntimeChecksTests", dependencies: ["TDJRuntimeChecks", "TDJInterface", "TDJCore"])
    ],
    cxxLanguageStandard: .cxx17
)
